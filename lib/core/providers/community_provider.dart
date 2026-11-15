import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/services/api_service.dart';
import '../constants/api_constants.dart';
class OnlineMember {
  final int id;
  final String name;
  final String? photoUrl;
  final String? department;
  final bool isOnline;
  final String? lastSeen;

  OnlineMember({required this.id, required this.name,
      this.photoUrl, this.department, this.isOnline = false, this.lastSeen});

  factory OnlineMember.fromJson(Map<String, dynamic> j) => OnlineMember(
        id: j['id'], name: j['name'] ?? '',
        photoUrl: j['photo_url'], department: j['department'],
        isOnline: j['is_online'] ?? false,
        lastSeen: j['last_seen']);

  String get statusText => isOnline ? 'Online' : formatLastSeen(lastSeen);
}

class CommunityRoom {
  final int id;
  final String name;
  final String? description;
  final String icon;
  final String roomType;
  final int? categoryId;
  final String? categoryName;
  final int categoryOrder;
  final int? memberCount;
  final ChatMessage? lastMessage;
  final bool isHosting;

  CommunityRoom({required this.id, required this.name, this.description,
      required this.icon, this.roomType = 'public',
      this.categoryId, this.categoryName, this.categoryOrder = 9999,
      this.memberCount, this.lastMessage, this.isHosting = false});

  factory CommunityRoom.fromJson(Map<String, dynamic> j) {
    final cat = j['category'] as Map<String, dynamic>?;
    final rawSession = j['active_listen_session'] ?? j['listen_session'];
    final hasActiveSession = j['is_hosting'] == true ||
        j['has_active_session'] == true ||
        (rawSession is Map && rawSession['is_active'] != false);
    return CommunityRoom(
        id: j['id'], name: j['name'] ?? '', description: j['description'],
        icon: j['icon'] ?? 'chat_bubble_outline',
        roomType: j['room_type'] ?? 'public',
        categoryId: cat?['id'],
        categoryName: cat?['name'],
        categoryOrder: cat?['order'] ?? 9999,
        memberCount: j['member_count'],
        lastMessage: j['last_message'] != null
            ? ChatMessage.fromJson(j['last_message']) : null,
        isHosting: hasActiveSession);
  }

  bool get isPublic => roomType == 'public';
}

class MessageReaction {
  final String emoji;
  final int count;
  final bool reacted;

  MessageReaction({required this.emoji, required this.count, this.reacted = false});

  factory MessageReaction.fromJson(Map<String, dynamic> j) => MessageReaction(
        emoji: j['emoji'] ?? '',
        count: j['count'] ?? 1,
        reacted: j['reacted'] ?? false,
      );
}

class ChatMessage {
  final int id;
  final String text;
  final bool isDeleted;
  final int senderId;
  final String senderName;
  final String? senderPhoto;
  final String? resourceType;
  final int? resourceId;
  final String? resourceTitle;
  final String? fileUrl;
  final String? fileType;
  final String? fileName;
  final bool isDelivered;
  final bool isRead;
  final String? resourceAudioUrl; // resolved streamable URL for listen-together
  final int? replyToId;
  final String? replyToSender;
  final String? replyToText;
  final List<MessageReaction> reactions;
  final DateTime createdAt;

  ChatMessage({required this.id, required this.text, required this.isDeleted,
      required this.senderId, required this.senderName, this.senderPhoto,
      this.resourceType, this.resourceId, this.resourceTitle,
      this.fileUrl, this.fileType, this.fileName,
      this.isDelivered = false, this.isRead = false,
      this.resourceAudioUrl,
      this.replyToId, this.replyToSender, this.replyToText,
      this.reactions = const [],
      required this.createdAt});

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final sender = j['sender'] ?? {};
    final reply = j['reply_to'] as Map<String, dynamic>?;
    final rawReactions = j['reactions'] as List? ?? [];
    return ChatMessage(
      id: j['id'], text: j['text'] ?? '', isDeleted: j['is_deleted'] ?? false,
      senderId: sender['id'] ?? 0, senderName: sender['name'] ?? '',
      senderPhoto: sender['photo_url'],
      resourceType: j['resource_type'], resourceId: j['resource_id'],
      resourceTitle: j['resource_title'],
      fileUrl: j['file_url'], fileType: j['file_type'], fileName: j['file_name'],
      isDelivered: j['is_delivered'] ?? false,
      isRead: j['is_read'] ?? false,
      resourceAudioUrl: j['resource_audio_url'],
      replyToId: reply?['id'],
      replyToSender: reply?['sender_name'],
      replyToText: reply?['text'],
      reactions: rawReactions
          .map((e) => MessageReaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(j['created_at']));
  }

  bool get hasResource => resourceType != null && resourceId != null;
  bool get hasFile => fileUrl != null && fileUrl!.isNotEmpty;
}

class CommunityProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<OnlineMember> _onlineMembers = [];
  int _onlineCount = 0;
  List<OnlineMember> _allMembers = [];
  List<CommunityRoom> _rooms = [];
  Map<int, ListenSession> _activeSessionsByRoom = {};
  List<ChatMessage> _messages = [];
  List<String> _typingUsers = [];
  int? _currentRoomId = 0;
  int _messagesFetchVersion = 0;
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  bool _hasAccess = true; // assume true until backend says otherwise
  Timer? _heartbeatTimer;
  Timer? _pollTimer;
  Timer? _typingPollTimer;
  DateTime? _lastHostingRefreshAt;
  DateTime? _rateLimitedUntil;

  List<OnlineMember> get onlineMembers => _onlineMembers;
  int get onlineCount => _onlineCount;
  List<OnlineMember> get allMembers => _allMembers;
  List<CommunityRoom> get rooms => _rooms;
  List<ChatMessage> get messages => _messages;
  List<String> get typingUsers => _typingUsers;
  int? get currentRoomId => _currentRoomId;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  bool get hasAccess => _hasAccess;

  bool isRoomHosting(int roomId) {
    if (_activeSessionsByRoom[roomId]?.isActive == true) return true;
    return _rooms.any((r) => r.id == roomId && r.isHosting);
  }

  ListenSession? activeSessionForRoom(int roomId) => _activeSessionsByRoom[roomId];

  Future<void> fetchOnlineMembers() async {
    try {
      final res = await _api.get(ApiConstants.communityOnline);
      if (res.statusCode == 403) {
        _hasAccess = false;
        notifyListeners();
        return;
      }
      if (res.isSuccess) {
        _hasAccess = true;
        _onlineCount = res.data['online_count'] ?? 0;
        final list = res.data['members'] as List? ?? [];
        _onlineMembers = list.map((e) => OnlineMember.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchOnlineMembers: $e');
    }
  }

  Future<CommunityRoom?> openDm(int userId) async {    try {
      final res = await _api.post(ApiConstants.communityDm(userId), {});
      if (res.isSuccess) {
        return CommunityRoom.fromJson(res.data);
      }
    } catch (e) {
      debugPrint('openDm: $e');
    }
    return null;
  }

  Future<void> fetchAllMembers() async {
    _error = null;
    try {
      debugPrint('fetchAllMembers: calling API...');
      final res = await _api.get(ApiConstants.communityMembers)
          .timeout(const Duration(seconds: 30));
      debugPrint('fetchAllMembers: status=${res.statusCode}, success=${res.isSuccess}');
      if (res.statusCode == 403) {
        _hasAccess = false;
      } else if (res.isSuccess) {
        final list = res.data['members'] as List? ?? [];
        _allMembers = list.map((e) => OnlineMember.fromJson(e)).toList();
        debugPrint('fetchAllMembers: loaded ${_allMembers.length} members');
      } else {
        _error = res.statusCode == 0
            ? res.userFriendlyError
            : 'Could not load members (${res.statusCode})';
        debugPrint('fetchAllMembers error: ${res.body}');
      }
    } on TimeoutException catch (_) {
      _error = 'Request timed out. Check your connection.';
      debugPrint('fetchAllMembers: timed out');
    } catch (e) {
      _error = 'Failed to load members: $e';
      debugPrint('fetchAllMembers: $e');
    }
    notifyListeners();
  }

  void startHeartbeat() {
    _heartbeatTimer?.cancel();
    _sendHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) => _sendHeartbeat());
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _api.post(ApiConstants.communityOnline, {'is_online': false})
        .catchError((_) => ApiResponse(statusCode: 0, body: '{}', isSuccess: false));
  }

  Future<void> _sendHeartbeat() async {
    try {
      await _api.post(ApiConstants.communityOnline, {'is_online': true});
      await fetchOnlineMembers();
    } catch (_) {}
  }

  Future<void> fetchRooms() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      debugPrint('fetchRooms: calling API...');
      var res = await _api.get(ApiConstants.communityRooms)
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 429) {
        // Brief backoff and single retry on rate limit
        await Future.delayed(const Duration(seconds: 2));
        res = await _api.get(ApiConstants.communityRooms)
            .timeout(const Duration(seconds: 30));
      }
      debugPrint('fetchRooms: status=${res.statusCode}, success=${res.isSuccess}');
      if (res.statusCode == 403) {
        _hasAccess = false;
      } else if (res.isSuccess) {
        final list = res.dataList;
        _rooms = list.map((e) => CommunityRoom.fromJson(e as Map<String, dynamic>)).toList();
        debugPrint('fetchRooms: loaded ${_rooms.length} rooms');
        // Only poll individual rooms if backend didn't already include hosting flags
        final backendIncludedHosting = _rooms.any((r) => r.isHosting);
        if (_rooms.isNotEmpty && !backendIncludedHosting) {
          unawaited(refreshHostingRooms());
        }
      } else if (res.statusCode == 429) {
        _rateLimitedUntil = DateTime.now().add(const Duration(seconds: 15));
        _error = 'Server is busy (429). Please wait a moment and try again.';
        debugPrint('fetchRooms: rate limited (429)');
      } else {
        _error = res.statusCode == 0
            ? res.userFriendlyError
            : 'Server error (${res.statusCode}). Try again.';
        debugPrint('fetchRooms: error=$_error, body=${res.body}');
      }
    } on TimeoutException catch (_) {
      _error = 'Request timed out. Check your connection.';
      debugPrint('fetchRooms: timed out');
    } catch (e) {
      _error = 'Failed to load rooms: $e';
      debugPrint('fetchRooms exception: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  bool get _isRateLimited =>
      _rateLimitedUntil != null && DateTime.now().isBefore(_rateLimitedUntil!);

  /// Checks loaded rooms in small batches (with cooldown & 429 backoff)
  /// so hosting groups can be pinned to the top without triggering rate limits.
  Future<void> refreshHostingRooms({bool force = false}) async {
    if (_rooms.isEmpty || _isRateLimited) return;
    if (!force &&
        _lastHostingRefreshAt != null &&
        DateTime.now().difference(_lastHostingRefreshAt!) < const Duration(seconds: 30)) {
      return;
    }
    _lastHostingRefreshAt = DateTime.now();

    try {
      final updated = Map<int, ListenSession>.from(_activeSessionsByRoom);
      const batchSize = 3;
      for (var i = 0; i < _rooms.length; i += batchSize) {
        if (_isRateLimited) break;
        final batch = _rooms.skip(i).take(batchSize).toList();
        var hitRateLimit = false;
        final results = await Future.wait(
          batch.map((room) async {
            final res = await _api.get(ApiConstants.communityListenSession(room.id));
            if (res.statusCode == 429) {
              hitRateLimit = true;
              return MapEntry<int, ListenSession?>(room.id, null);
            }
            if (res.isSuccess) {
              final data = res.data['session'];
              if (data != null) {
                return MapEntry<int, ListenSession?>(room.id, ListenSession.fromJson(data));
              }
            }
            return MapEntry<int, ListenSession?>(room.id, null);
          }),
        );
        if (hitRateLimit) {
          _rateLimitedUntil = DateTime.now().add(const Duration(seconds: 15));
          break;
        }
        for (final entry in results) {
          final s = entry.value;
          if (s != null && s.isActive) {
            updated[entry.key] = s;
          } else {
            updated.remove(entry.key);
          }
        }
        if (i + batchSize < _rooms.length) {
          await Future.delayed(const Duration(milliseconds: 150));
        }
      }
      _activeSessionsByRoom = updated;
      notifyListeners();
    } catch (e) {
      debugPrint('refreshHostingRooms: $e');
    }
  }

  Future<void> fetchMessages(int roomId) async {
    if (_currentRoomId != roomId) {
      _messages = [];
      _typingUsers = [];
      _currentRoomId = roomId;
    }
    final fetchVersion = ++_messagesFetchVersion;
    try {
      final res = await _api.get(ApiConstants.communityMessages(roomId));
      if (res.isSuccess &&
          _currentRoomId == roomId &&
          fetchVersion == _messagesFetchVersion) {
        final list = res.data['messages'] as List? ?? [];
        _messages = list.map((e) => ChatMessage.fromJson(e)).toList();
        if (res.data.containsKey('typing_users')) {
          _updateTypingUsersFromRaw(res.data['typing_users']);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchMessages: $e');
    }
  }

  void _updateTypingUsersFromRaw(dynamic raw) {
    if (raw is! List) return;
    final parsed = <String>[];
    for (final item in raw) {
      if (item is String && item.trim().isNotEmpty) {
        parsed.add(item.trim());
      } else if (item is Map) {
        final name = (item['name'] ?? item['full_name'] ?? item['username'] ?? '')
            .toString()
            .trim();
        if (name.isNotEmpty) parsed.add(name);
      }
    }
    if (!listEquals(_typingUsers, parsed)) {
      _typingUsers = parsed;
      notifyListeners();
    }
  }

  Future<void> setTyping(int roomId, bool isTyping) async {
    try {
      await _api.post(ApiConstants.communityTyping(roomId), {
        'is_typing': isTyping,
      });
    } catch (_) {}
  }

  Future<void> fetchTypingUsers(int roomId) async {
    if (_isRateLimited) return;
    try {
      final res = await _api.get(ApiConstants.communityTyping(roomId));
      if (res.statusCode == 429) {
        _rateLimitedUntil = DateTime.now().add(const Duration(seconds: 15));
        return;
      }
      if (res.isSuccess && _currentRoomId == roomId) {
        _updateTypingUsersFromRaw(res.data['typing_users'] ?? res.data['users']);
      }
    } catch (_) {}
  }

  void startPolling(int roomId) {
    _pollTimer?.cancel();
    _typingPollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isRateLimited) fetchMessages(roomId);
    });
    _typingPollTimer = Timer.periodic(const Duration(seconds: 3), (_) => fetchTypingUsers(roomId));
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _typingPollTimer?.cancel();
    _typingUsers = [];
  }

  Future<bool> sendFileMessage(int roomId, File file, String fileType, {String? text, int? replyToId}) async {
    _isSending = true;
    _error = null;
    notifyListeners();
    try {
      final fields = <String, String>{
        'text': text ?? '',
        'file_type': fileType,
        if (replyToId != null) 'reply_to_id': replyToId.toString(),
      };
      final res = await _api.postMultipart(
        ApiConstants.communityMessageUpload(roomId),
        fields: fields,
        files: {'file': file},
      );
      if (res.isSuccess) {
        _messagesFetchVersion++;
        _messages.add(ChatMessage.fromJson(res.data));
        _isSending = false;
        notifyListeners();
        return true;
      }
      _error = res.errorMessage ?? 'Failed to send file';
    } catch (e) {
      _error = 'Failed to send file';
    }
    _isSending = false;
    notifyListeners();
    return false;
  }

  Future<bool> sendMessage(int roomId, String text,
      {String? resourceType, int? resourceId, String? resourceTitle, int? replyToId}) async {
    _isSending = true;
    _error = null;
    notifyListeners();
    try {
      final body = <String, dynamic>{'text': text};
      if (resourceType != null) body['resource_type'] = resourceType;
      if (resourceId != null) body['resource_id'] = resourceId;
      if (resourceTitle != null) body['resource_title'] = resourceTitle;
      if (replyToId != null) body['reply_to_id'] = replyToId;

      final res = await _api.post(ApiConstants.communityMessages(roomId), body);
      if (res.isSuccess) {
        _messagesFetchVersion++;
        _messages.add(ChatMessage.fromJson(res.data));
        _isSending = false;
        notifyListeners();
        return true;
      }
      _error = res.errorMessage ?? 'Failed to send';
    } catch (e) {
      _error = 'Failed to send message';
    }
    _isSending = false;
    notifyListeners();
    return false;
  }

  Future<bool> toggleReaction(int messageId, String emoji) async {
    try {
      var res = await _api.post(
        ApiConstants.communityReactMessage(messageId),
        {'emoji': emoji},
      );

      // If backend enforces 1 reaction per user per message and rejects a new emoji,
      // remove the user's previous reaction first and retry with the new emoji.
      if (!res.isSuccess) {
        final idx = _messages.indexWhere((m) => m.id == messageId);
        if (idx != -1) {
          final previous = _messages[idx].reactions.where((r) => r.reacted && r.emoji != emoji).toList();
          if (previous.isNotEmpty) {
            for (final prev in previous) {
              await _api.post(
                ApiConstants.communityReactMessage(messageId),
                {'emoji': prev.emoji},
              );
            }
            res = await _api.post(
              ApiConstants.communityReactMessage(messageId),
              {'emoji': emoji},
            );
          }
        }
      }

      if (res.isSuccess) {
        final raw = res.data['reactions'] as List? ?? [];
        final updated = raw
            .map((e) => MessageReaction.fromJson(e as Map<String, dynamic>))
            .toList();
        final idx = _messages.indexWhere((m) => m.id == messageId);
        if (idx != -1) {
          final old = _messages[idx];
          _messages[idx] = ChatMessage(
            id: old.id,
            text: old.text,
            isDeleted: old.isDeleted,
            senderId: old.senderId,
            senderName: old.senderName,
            senderPhoto: old.senderPhoto,
            resourceType: old.resourceType,
            resourceId: old.resourceId,
            resourceTitle: old.resourceTitle,
            fileUrl: old.fileUrl,
            fileType: old.fileType,
            fileName: old.fileName,
            isDelivered: old.isDelivered,
            isRead: old.isRead,
            resourceAudioUrl: old.resourceAudioUrl,
            replyToId: old.replyToId,
            replyToSender: old.replyToSender,
            replyToText: old.replyToText,
            reactions: updated,
            createdAt: old.createdAt,
          );
          notifyListeners();
        }
        return true;
      } else {
        debugPrint('toggleReaction failed: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('toggleReaction: $e');
    }
    return false;
  }

  Future<void> deleteMessage(int messageId) async {
    try {
      final res = await _api.delete(ApiConstants.communityDeleteMessage(messageId));
      if (res.isSuccess) {
        final idx = _messages.indexWhere((m) => m.id == messageId);
        if (idx != -1) {
          final old = _messages[idx];
          _messages[idx] = ChatMessage(
            id: old.id, text: '🚫 Message deleted', isDeleted: true,
            senderId: old.senderId, senderName: old.senderName,
            createdAt: old.createdAt);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('deleteMessage: $e');
    }
  }

  void reset() {
    stopHeartbeat();
    stopPolling();
    _onlineMembers = [];
    _onlineCount = 0;
    _allMembers = [];
    _rooms = [];
    _messages = [];
    _currentRoomId = null;
    _hasAccess = true;
    notifyListeners();
  }

  // ── Listen Together ──────────────────────────────────────────────────────

  Future<ListenSession?> startListenSession(int roomId, {
    required String resourceType,
    required int resourceId,
    required String resourceTitle,
    required String audioUrl,
  }) async {
    try {
      final res = await _api.post(ApiConstants.communityListenSession(roomId), {
        'resource_type': resourceType,
        'resource_id': resourceId,
        'resource_title': resourceTitle,
        'audio_url': audioUrl,
        'is_playing': false,
        'position_seconds': 0,
      });
      if (res.isSuccess) return ListenSession.fromJson(res.data);
    } catch (e) {
      debugPrint('startListenSession: $e');
    }
    return null;
  }

  Future<void> pushPlaybackState(int roomId, {
    required bool isPlaying,
    required double positionSeconds,
    required String resourceType,
    required int resourceId,
    required String resourceTitle,
    required String audioUrl,
  }) async {
    try {
      await _api.post(ApiConstants.communityListenSession(roomId), {
        'resource_type': resourceType,
        'resource_id': resourceId,
        'resource_title': resourceTitle,
        'audio_url': audioUrl,
        'is_playing': isPlaying,
        'position_seconds': positionSeconds,
      });
    } catch (e) {
      debugPrint('pushPlaybackState: $e');
    }
  }

  Future<ListenSession?> pollListenSession(int roomId) async {
    try {
      final res = await _api.get(ApiConstants.communityListenSession(roomId));
      if (res.isSuccess) {
        final data = res.data['session'];
        if (data != null) return ListenSession.fromJson(data);
      }
    } catch (e) {
      debugPrint('pollListenSession: $e');
    }
    return null;
  }

  Future<void> endListenSession(int roomId) async {
    try {
      await _api.post(ApiConstants.communityListenSession(roomId), {'end_session': true});
    } catch (e) {
      debugPrint('endListenSession: $e');
    }
  }
}

// Helper to format last seen time
String formatLastSeen(String? lastSeenIso) {
  if (lastSeenIso == null) return 'Offline';
  final dt = DateTime.tryParse(lastSeenIso);
  if (dt == null) return 'Offline';
  final diff = DateTime.now().difference(dt.toLocal());
  if (diff.inMinutes < 5) return 'Online';
  if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';
  if (diff.inHours < 24) return 'Last seen ${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Last seen yesterday';
  return 'Last seen ${diff.inDays}d ago';
}

class ListenSession {
  final int id;
  final int? roomId;
  final int hostId;
  final String hostName;
  final String resourceType;
  final int resourceId;
  final String resourceTitle;
  final String audioUrl;
  final bool isPlaying;
  final double positionSeconds;
  final DateTime updatedAt;
  final bool isActive;

  ListenSession({
    required this.id,
    this.roomId,
    required this.hostId,
    required this.hostName,
    required this.resourceType,
    required this.resourceId,
    required this.resourceTitle,
    required this.audioUrl,
    required this.isPlaying,
    required this.positionSeconds,
    required this.updatedAt,
    required this.isActive,
  });

  factory ListenSession.fromJson(Map<String, dynamic> j) => ListenSession(
        id: j['id'],
        roomId: j['room_id'],
        hostId: j['host_id'],
        hostName: j['host_name'] ?? '',
        resourceType: j['resource_type'] ?? '',
        resourceId: j['resource_id'] ?? 0,
        resourceTitle: j['resource_title'] ?? '',
        audioUrl: j['audio_url'] ?? '',
        isPlaying: j['is_playing'] ?? false,
        positionSeconds: (j['position_seconds'] as num?)?.toDouble() ?? 0.0,
        updatedAt: DateTime.parse(j['updated_at']),
        isActive: j['is_active'] ?? true,
      );
}
