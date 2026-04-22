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
  final int? memberCount;
  final ChatMessage? lastMessage;

  CommunityRoom({required this.id, required this.name, this.description,
      required this.icon, this.roomType = 'public', this.memberCount, this.lastMessage});

  factory CommunityRoom.fromJson(Map<String, dynamic> j) => CommunityRoom(
        id: j['id'], name: j['name'] ?? '', description: j['description'],
        icon: j['icon'] ?? 'chat_bubble_outline',
        roomType: j['room_type'] ?? 'public',
        memberCount: j['member_count'],
        lastMessage: j['last_message'] != null
            ? ChatMessage.fromJson(j['last_message']) : null);

  bool get isPublic => roomType == 'public';
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
  final DateTime createdAt;

  ChatMessage({required this.id, required this.text, required this.isDeleted,
      required this.senderId, required this.senderName, this.senderPhoto,
      this.resourceType, this.resourceId, this.resourceTitle,
      this.fileUrl, this.fileType, this.fileName,
      this.isDelivered = false, this.isRead = false,
      this.resourceAudioUrl,
      required this.createdAt});

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final sender = j['sender'] ?? {};
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
      createdAt: DateTime.parse(j['created_at']));
  }

  bool get hasResource => resourceType != null && resourceId != null;
  bool get hasFile => fileUrl != null && fileType != null;
}

class CommunityProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<OnlineMember> _onlineMembers = [];
  int _onlineCount = 0;
  List<OnlineMember> _allMembers = [];
  List<CommunityRoom> _rooms = [];
  List<ChatMessage> _messages = [];
  int? _currentRoomId = 0;
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  bool _hasAccess = true; // assume true until backend says otherwise
  Timer? _heartbeatTimer;
  Timer? _pollTimer;

  List<OnlineMember> get onlineMembers => _onlineMembers;
  int get onlineCount => _onlineCount;
  List<OnlineMember> get allMembers => _allMembers;
  List<CommunityRoom> get rooms => _rooms;
  List<ChatMessage> get messages => _messages;
  int? get currentRoomId => _currentRoomId;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  bool get hasAccess => _hasAccess;

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

  Future<String?> callUser(int userId, {bool isVideo = false}) async {
    try {
      final channelName = 'tcgc_${userId}_${DateTime.now().millisecondsSinceEpoch}';
      final res = await _api.post('/community/call/$userId/', {
        'call_type': isVideo ? 'video' : 'voice',
        'channel_name': channelName,
      });
      if (res.isSuccess) return channelName;
    } catch (e) {
      debugPrint('callUser: $e');
    }
    return null;
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
    try {
      final res = await _api.get(ApiConstants.communityMembers);
      if (res.statusCode == 403) {
        _hasAccess = false;
        notifyListeners();
        return;
      }
      if (res.isSuccess) {
        _hasAccess = true;
        final list = res.data['members'] as List? ?? [];
        _allMembers = list.map((e) => OnlineMember.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchAllMembers: $e');
    }
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
    notifyListeners();
    try {
      final res = await _api.get(ApiConstants.communityRooms);
      if (res.isSuccess) {
        final list = res.data as List? ?? [];
        _rooms = list.map((e) => CommunityRoom.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('fetchRooms: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchMessages(int roomId) async {
    if (_currentRoomId != roomId) {
      _messages = [];
      _currentRoomId = roomId;
    }
    try {
      final res = await _api.get(ApiConstants.communityMessages(roomId));
      if (res.isSuccess) {
        final list = res.data['messages'] as List? ?? [];
        _messages = list.map((e) => ChatMessage.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchMessages: $e');
    }
  }

  void startPolling(int roomId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => fetchMessages(roomId));
  }

  void stopPolling() => _pollTimer?.cancel();

  Future<bool> sendFileMessage(int roomId, File file, String fileType, {String? text}) async {
    _isSending = true;
    _error = null;
    notifyListeners();
    try {
      final fields = <String, String>{
        'text': text ?? '',
        'file_type': fileType,
      };
      final res = await _api.postMultipart(
        ApiConstants.communityMessageUpload(roomId),
        fields: fields,
        files: {'file': file},
      );
      if (res.isSuccess) {
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
      {String? resourceType, int? resourceId, String? resourceTitle}) async {
    _isSending = true;
    _error = null;
    notifyListeners();
    try {
      final body = <String, dynamic>{'text': text};
      if (resourceType != null) body['resource_type'] = resourceType;
      if (resourceId != null) body['resource_id'] = resourceId;
      if (resourceTitle != null) body['resource_title'] = resourceTitle;

      final res = await _api.post(ApiConstants.communityMessages(roomId), body);
      if (res.isSuccess) {
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
