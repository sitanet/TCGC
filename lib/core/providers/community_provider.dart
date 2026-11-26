import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/api_service.dart';
import '../constants/api_constants.dart';
class OnlineMember {
  final int id;
  final String name;
  final String? photoUrl;
  final String? department;
  final bool isOnline;
  final String? lastSeen;
  final bool isFollowing;
  final bool isFollower;
  final int followersCount;
  final int unreadCount;
  final bool isRoomAdmin;
  final int? listeningMessageId;
  final String? listeningMessageTitle;
  final double listeningPositionSeconds;
  final int? listeningRoomId;

  OnlineMember({
    required this.id,
    required this.name,
    this.photoUrl,
    this.department,
    this.isOnline = false,
    this.lastSeen,
    this.isFollowing = false,
    this.isFollower = false,
    this.followersCount = 0,
    this.unreadCount = 0,
    this.isRoomAdmin = false,
    this.listeningMessageId,
    this.listeningMessageTitle,
    this.listeningPositionSeconds = 0.0,
    this.listeningRoomId,
  });

  OnlineMember copyWith({
    bool? isFollowing,
    int? followersCount,
    int? unreadCount,
  }) =>
      OnlineMember(
        id: id,
        name: name,
        photoUrl: photoUrl,
        department: department,
        isOnline: isOnline,
        lastSeen: lastSeen,
        isFollowing: isFollowing ?? this.isFollowing,
        isFollower: isFollower,
        followersCount: followersCount ?? this.followersCount,
        unreadCount: unreadCount ?? this.unreadCount,
        isRoomAdmin: isRoomAdmin,
        listeningMessageId: listeningMessageId,
        listeningMessageTitle: listeningMessageTitle,
        listeningPositionSeconds: listeningPositionSeconds,
        listeningRoomId: listeningRoomId,
      );

  factory OnlineMember.fromJson(Map<String, dynamic> j) => OnlineMember(
        id: j['id'],
        name: j['name'] ?? '',
        photoUrl: j['photo_url'],
        department: j['department'],
        isOnline: j['is_online'] ?? false,
        lastSeen: j['last_seen'],
        isFollowing: j['is_following'] ?? false,
        isFollower: j['is_follower'] ?? false,
        followersCount: j['followers_count'] ?? 0,
        unreadCount: j['unread_count'] ?? 0,
        isRoomAdmin: j['is_admin'] ?? false,
        listeningMessageId: j['listening_message_id'],
        listeningMessageTitle: j['listening_message_title'],
        listeningPositionSeconds:
            (j['listening_position_seconds'] ?? 0).toDouble(),
        listeningRoomId: j['listening_room_id'],
      );

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
  final bool isAdmin;

  CommunityRoom({required this.id, required this.name, this.description,
      required this.icon, this.roomType = 'public',
      this.categoryId, this.categoryName, this.categoryOrder = 9999,
      this.memberCount, this.lastMessage, this.isHosting = false,
      this.isAdmin = false});

  factory CommunityRoom.fromJson(Map<String, dynamic> j) {
    final cat = j['category'] is Map<String, dynamic>
        ? j['category'] as Map<String, dynamic>
        : null;
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
        lastMessage: j['last_message'] is Map<String, dynamic>
            ? ChatMessage.fromJson(j['last_message'] as Map<String, dynamic>)
            : null,
        isHosting: hasActiveSession,
        isAdmin: j['is_admin'] == true);
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
  int _myFollowersCount = 0;

  int get myFollowersCount =>
      _myFollowersCount > 0 ? _myFollowersCount : myFollowers.length;
  List<OnlineMember> get myFollowers =>
      _allMembers.where((m) => m.isFollower).toList();
  List<CommunityRoom> _rooms = [];
  Map<int, ListenSession> _activeSessionsByRoom = {};
  List<ChatMessage> _messages = [];
  List<String> _typingUsers = [];
  List<String> _recordingUsers = [];
  int? _currentRoomId = 0;
  int _messagesFetchVersion = 0;
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  bool _hasAccess = true; // assume true until backend says otherwise
  bool _authExpired = false;
  Timer? _heartbeatTimer;
  Timer? _pollTimer;
  Timer? _typingPollTimer;
  DateTime? _lastHostingRefreshAt;
  DateTime? _rateLimitedUntil;
  bool _cacheLoaded = false;

  static const String _roomsCacheKey = 'cached_community_rooms_v1';
  static const String _membersCacheKey = 'cached_community_members_v1';

  List<OnlineMember> get onlineMembers => _onlineMembers;
  int get onlineCount => _onlineCount;
  List<OnlineMember> get allMembers => _allMembers;
  List<CommunityRoom> get rooms => _rooms;
  List<ChatMessage> get messages => _messages;
  List<String> get typingUsers => _typingUsers;
  List<String> get recordingUsers => _recordingUsers;
  int? get currentRoomId => _currentRoomId;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  bool get hasAccess => _hasAccess;
  bool get authExpired => _authExpired;

  bool isRoomHosting(int roomId) {
    if (_activeSessionsByRoom[roomId]?.isActive == true) return true;
    return _rooms.any((r) => r.id == roomId && r.isHosting);
  }

  ListenSession? activeSessionForRoom(int roomId) => _activeSessionsByRoom[roomId];

  /// Immediately restore cached rooms/categories and members from disk so
  /// the Community page renders instantaneously without waiting on network.
  Future<void> loadCachedData() async {
    if (_cacheLoaded && _rooms.isNotEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final roomsJson = prefs.getString(_roomsCacheKey);
      if (roomsJson != null && roomsJson.isNotEmpty && _rooms.isEmpty) {
        final List<dynamic> decoded = jsonDecode(roomsJson);
        _rooms = decoded
            .map((e) => CommunityRoom.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      final membersJson = prefs.getString(_membersCacheKey);
      if (membersJson != null && membersJson.isNotEmpty && _allMembers.isEmpty) {
        final List<dynamic> decoded = jsonDecode(membersJson);
        _allMembers = decoded
            .map((e) => OnlineMember.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      _cacheLoaded = true;
      if (_rooms.isNotEmpty || _allMembers.isNotEmpty) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('loadCachedData error: $e');
    }
  }

  Future<void> clearCache() async {
    _rooms = [];
    _allMembers = [];
    _onlineMembers = [];
    _cacheLoaded = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_roomsCacheKey);
      await prefs.remove(_membersCacheKey);
    } catch (_) {}
    notifyListeners();
  }

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

  Future<CommunityRoom?> openDm(int userId) async {
    _error = null;
    try {
      final res = await _api.post(ApiConstants.communityDm(userId), {});
      if (res.isSuccess) {
        final raw = res.data;
        final roomJson = raw['room'] is Map<String, dynamic>
            ? raw['room'] as Map<String, dynamic>
            : (raw['data'] is Map<String, dynamic>
                ? raw['data'] as Map<String, dynamic>
                : raw);
        return CommunityRoom.fromJson(roomJson);
      }
      _error = res.errorMessage ?? 'Could not open chat (${res.statusCode})';
    } catch (e) {
      debugPrint('openDm: $e');
      _error = 'Could not open chat. Please try again.';
    }
    return null;
  }

  Future<bool?> toggleFollowMember(int userId) async {
    final idx = _allMembers.indexWhere((m) => m.id == userId);
    final oldMember = idx != -1 ? _allMembers[idx] : null;
    if (oldMember != null) {
      final nextFollow = !oldMember.isFollowing;
      final nextCount = (oldMember.followersCount + (nextFollow ? 1 : -1))
          .clamp(0, 1 << 30);
      _allMembers[idx] = oldMember.copyWith(
        isFollowing: nextFollow,
        followersCount: nextCount,
      );
      notifyListeners();
    }

    try {
      final res =
          await _api.post(ApiConstants.communityFollowMember(userId), {});
      if (res.isSuccess) {
        final isFollowing = res.data['is_following'] == true;
        final followersCount = res.data['followers_count'] as int? ?? 0;
        final curIdx = _allMembers.indexWhere((m) => m.id == userId);
        if (curIdx != -1) {
          _allMembers[curIdx] = _allMembers[curIdx].copyWith(
            isFollowing: isFollowing,
            followersCount: followersCount,
          );
          notifyListeners();
        }
        return isFollowing;
      }
      _error = res.errorMessage ??
          'Could not update follow status (${res.statusCode})';
    } catch (e) {
      debugPrint('toggleFollowMember: $e');
      _error = 'Could not update follow status: $e';
    }

    // Revert optimistic update on failure
    if (oldMember != null) {
      final curIdx = _allMembers.indexWhere((m) => m.id == userId);
      if (curIdx != -1) {
        _allMembers[curIdx] = oldMember;
        notifyListeners();
      }
    }
    return null;
  }

  Future<void> updateListeningStatus({
    required int messageId,
    required String messageTitle,
    String? audioUrl,
    double positionSeconds = 0.0,
    int? roomId,
    bool isListening = true,
  }) async {
    try {
      await _api.post(ApiConstants.communityListeningStatus, {
        'message_id': messageId,
        'message_title': messageTitle,
        if (audioUrl != null && audioUrl.isNotEmpty) 'audio_url': audioUrl,
        'position_seconds': positionSeconds,
        if (roomId != null) 'room_id': roomId,
        'is_listening': isListening,
      });
    } catch (e) {
      debugPrint('updateListeningStatus: $e');
    }
  }

  Future<({List<OnlineMember> members, bool isAdmin})?> fetchRoomMembers(
      int roomId) async {
    try {
      final res = await _api.get(ApiConstants.communityRoomMembers(roomId));
      if (res.isSuccess) {
        final raw = res.data;
        final list = (raw['members'] as List? ?? [])
            .map((e) => OnlineMember.fromJson(e as Map<String, dynamic>))
            .toList();
        final isAdmin = raw['is_admin'] == true;
        return (members: list, isAdmin: isAdmin);
      }
      _error = res.errorMessage ?? 'Could not load group members';
    } catch (e) {
      debugPrint('fetchRoomMembers: $e');
      _error = 'Could not load group members';
    }
    return null;
  }

  Future<bool> addRoomMembers(int roomId, List<int> userIds) async {
    if (userIds.isEmpty) return false;
    try {
      final res = await _api.post(
        ApiConstants.communityRoomMembers(roomId),
        {'user_ids': userIds},
      );
      if (res.isSuccess) {
        await fetchRooms();
        return true;
      }
      _error = res.errorMessage ?? 'Could not add members';
    } catch (e) {
      debugPrint('addRoomMembers: $e');
      _error = 'Could not add members';
    }
    return false;
  }

  Future<bool> removeRoomMember(int roomId, int userId) async {
    try {
      final res = await _api.delete(
        '${ApiConstants.communityRoomMembers(roomId)}?user_id=$userId',
      );
      if (res.isSuccess) {
        await fetchRooms();
        return true;
      }
      _error = res.errorMessage ?? 'Could not remove member';
    } catch (e) {
      debugPrint('removeRoomMember: $e');
      _error = 'Could not remove member';
    }
    return false;
  }

  Future<void> fetchAllMembers() async {
    _error = null;
    try {
      debugPrint('fetchAllMembers: calling API...');
      final res = await _api.get(ApiConstants.communityMembers)
          .timeout(const Duration(seconds: 30));
      debugPrint('fetchAllMembers: status=${res.statusCode}, success=${res.isSuccess}');
      if (res.statusCode == 401) {
        _authExpired = true;
        _heartbeatTimer?.cancel();
        _error = 'Your session expired. Please sign in again.';
      } else if (res.statusCode == 403) {
        _hasAccess = false;
      } else if (res.isSuccess) {
        _authExpired = false;
        final list = res.data['members'] as List? ?? [];
        _allMembers = list.map((e) => OnlineMember.fromJson(e)).toList();
        _myFollowersCount = (res.data['my_followers_count'] as int?) ??
            _allMembers.where((m) => m.isFollower).length;
        debugPrint('fetchAllMembers: loaded ${_allMembers.length} members');
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_membersCacheKey, jsonEncode(list));
        } catch (_) {}
      } else {
        if (_allMembers.isEmpty && _rooms.isEmpty) {
          _error = res.statusCode == 0
              ? res.userFriendlyError
              : 'Could not load members (${res.statusCode})';
        }
        debugPrint('fetchAllMembers error: ${res.body}');
      }
    } on TimeoutException catch (_) {
      if (_allMembers.isEmpty && _rooms.isEmpty) {
        _error = 'Request timed out. Check your connection.';
      }
      debugPrint('fetchAllMembers: timed out');
    } catch (e) {
      if (_allMembers.isEmpty && _rooms.isEmpty) {
        _error = 'Failed to load members: $e';
      }
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
    // Only show loading spinner if we don't already have cached rooms;
    // otherwise update silently in the background.
    if (_rooms.isEmpty) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    } else {
      _error = null;
    }
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
      if (res.statusCode == 401) {
        _authExpired = true;
        _heartbeatTimer?.cancel();
        _error = 'Your session expired. Please sign in again.';
      } else if (res.statusCode == 403) {
        _hasAccess = false;
      } else if (res.isSuccess) {
        _authExpired = false;
        final list = res.dataList;
        _rooms = list.map((e) => CommunityRoom.fromJson(e as Map<String, dynamic>)).toList();
        debugPrint('fetchRooms: loaded ${_rooms.length} rooms');
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_roomsCacheKey, jsonEncode(list));
        } catch (_) {}
        // Only poll individual rooms if backend didn't already include hosting flags
        final backendIncludedHosting = _rooms.any((r) => r.isHosting);
        if (_rooms.isNotEmpty && !backendIncludedHosting) {
          unawaited(refreshHostingRooms());
        }
      } else if (res.statusCode == 429) {
        _rateLimitedUntil = DateTime.now().add(const Duration(seconds: 15));
        if (_rooms.isEmpty) {
          _error = 'Server is busy (429). Please wait a moment and try again.';
        }
        debugPrint('fetchRooms: rate limited (429)');
      } else {
        if (_rooms.isEmpty) {
          _error = res.statusCode == 0
              ? res.userFriendlyError
              : 'Server error (${res.statusCode}). Try again.';
        }
        debugPrint('fetchRooms: error=$_error, body=${res.body}');
      }
    } on TimeoutException catch (_) {
      if (_rooms.isEmpty) {
        _error = 'Request timed out. Check your connection.';
      }
      debugPrint('fetchRooms: timed out');
    } catch (e) {
      if (_rooms.isEmpty) {
        _error = 'Failed to load rooms: $e';
      }
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
      _recordingUsers = [];
      _currentRoomId = roomId;
    }
    final fetchVersion = ++_messagesFetchVersion;
    try {
      final res = await _api.get(ApiConstants.communityMessages(roomId));
      if (res.isSuccess &&
          _currentRoomId == roomId &&
          fetchVersion == _messagesFetchVersion) {
        final list = res.data['messages'] as List? ?? [];
        final serverMsgs = list.map((e) => ChatMessage.fromJson(e)).toList();
        // Preserve any optimistic (in-flight) messages not yet confirmed by the server
        final pendingOptimistic = _messages.where((m) => m.id < 0).toList();
        _messages = [...serverMsgs, ...pendingOptimistic];
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
    final parsedTyping = <String>[];
    final parsedRecording = <String>[];
    for (final item in raw) {
      if (item is String && item.trim().isNotEmpty) {
        parsedTyping.add(item.trim());
      } else if (item is Map) {
        final name = (item['name'] ?? item['full_name'] ?? item['username'] ?? '')
            .toString()
            .trim();
        final activity = (item['activity'] ?? 'typing').toString().trim().toLowerCase();
        if (name.isNotEmpty) {
          if (activity == 'recording') {
            parsedRecording.add(name);
          } else {
            parsedTyping.add(name);
          }
        }
      }
    }
    if (!listEquals(_typingUsers, parsedTyping) ||
        !listEquals(_recordingUsers, parsedRecording)) {
      _typingUsers = parsedTyping;
      _recordingUsers = parsedRecording;
      notifyListeners();
    }
  }

  Future<void> setTyping(
    int roomId,
    bool isTyping, {
    String activity = 'typing',
  }) async {
    try {
      await _api.post(ApiConstants.communityTyping(roomId), {
        'is_typing': isTyping,
        'activity': activity,
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
    _typingPollTimer = Timer.periodic(const Duration(seconds: 2), (_) => fetchTypingUsers(roomId));
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _typingPollTimer?.cancel();
    _typingUsers = [];
    _recordingUsers = [];
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

  void clearMemberUnread(int userId) {
    var changed = false;
    _allMembers = _allMembers.map((m) {
      if (m.id == userId && m.unreadCount > 0) {
        changed = true;
        return m.copyWith(unreadCount: 0);
      }
      return m;
    }).toList();
    _onlineMembers = _onlineMembers.map((m) {
      if (m.id == userId && m.unreadCount > 0) {
        changed = true;
        return m.copyWith(unreadCount: 0);
      }
      return m;
    }).toList();
    if (changed) notifyListeners();
  }

  Future<bool> sendMessage(
    int roomId,
    String text, {
    String? resourceType,
    int? resourceId,
    String? resourceTitle,
    int? replyToId,
    int? senderId,
    String? senderName,
    String? senderPhoto,
    String? replyToSender,
    String? replyToText,
  }) async {
    _error = null;
    final int? tempId = senderId != null
        ? -DateTime.now().microsecondsSinceEpoch
        : null;

    // Optimistically insert message immediately before server responds
    if (tempId != null) {
      _messagesFetchVersion++;
      _messages.add(
        ChatMessage(
          id: tempId,
          text: text,
          isDeleted: false,
          senderId: senderId!,
          senderName: senderName ?? 'You',
          senderPhoto: senderPhoto,
          resourceType: resourceType,
          resourceId: resourceId,
          resourceTitle: resourceTitle,
          isDelivered: false,
          isRead: false,
          replyToId: replyToId,
          replyToSender: replyToSender,
          replyToText: replyToText,
          createdAt: DateTime.now(),
        ),
      );
      notifyListeners();
    } else {
      _isSending = true;
      notifyListeners();
    }

    try {
      final body = <String, dynamic>{'text': text};
      if (resourceType != null) body['resource_type'] = resourceType;
      if (resourceId != null) body['resource_id'] = resourceId;
      if (resourceTitle != null) body['resource_title'] = resourceTitle;
      if (replyToId != null) body['reply_to_id'] = replyToId;

      final res = await _api.post(ApiConstants.communityMessages(roomId), body);
      if (res.isSuccess) {
        _messagesFetchVersion++;
        final confirmed = ChatMessage.fromJson(res.data);
        if (tempId != null) {
          final idx = _messages.indexWhere((m) => m.id == tempId);
          if (idx != -1) {
            _messages[idx] = confirmed;
          } else {
            _messages.add(confirmed);
          }
        } else {
          _messages.add(confirmed);
        }
        _isSending = false;
        notifyListeners();
        return true;
      }
      _error = res.errorMessage ?? 'Failed to send';
    } catch (e) {
      _error = 'Failed to send message';
    }

    if (tempId != null) {
      _messages.removeWhere((m) => m.id == tempId);
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
