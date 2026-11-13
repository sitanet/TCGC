import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../data/services/api_service.dart';
import '../constants/api_constants.dart';
import 'community_provider.dart';

final listenTogetherProvider = ChangeNotifierProvider<ListenTogetherNotifier>((ref) {
  return ListenTogetherNotifier();
});

class ListenTogetherNotifier extends ChangeNotifier {
  final ApiService _api = ApiService();
  final AudioPlayer _player = AudioPlayer();

  ListenSession? _session;
  int? _currentRoomId;
  bool _isHost = false;
  bool _isJoined = false;
  bool _isLoading = false;
  bool _hasError = false;

  Timer? _syncTimer;
  DateTime? _lastLocalAction;
  static const _localActionCooldown = Duration(seconds: 2);

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _playSub;
  StreamSubscription? _stateSub;

  ListenSession? get session => _session;
  int? get currentRoomId => _currentRoomId;
  bool get isHost => _isHost;
  bool get isJoined => _isJoined;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;
  AudioPlayer get player => _player;

  ListenTogetherNotifier() {
    _posSub = _player.positionStream.listen((_) => notifyListeners());
    _durSub = _player.durationStream.listen((_) => notifyListeners());
    _playSub = _player.playingStream.listen((playing) {
      if (_isHost && _isJoined) {
        _pushState();
      }
      notifyListeners();
    });
    _stateSub = _player.playerStateStream.listen((state) {
      _isLoading = state.processingState == ProcessingState.buffering ||
          state.processingState == ProcessingState.loading;
      notifyListeners();
    });
  }

  Future<void> startAsHost({
    required int roomId,
    required String resourceType,
    required int resourceId,
    required String resourceTitle,
    required String audioUrl,
    required int hostId,
    required String hostName,
  }) async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      final res = await _api.post(ApiConstants.communityListenSession(roomId), {
        'resource_type': resourceType,
        'resource_id': resourceId,
        'resource_title': resourceTitle,
        'audio_url': audioUrl,
        'is_playing': true,
        'position_seconds': 0,
      });

      ListenSession session;
      if (res.isSuccess) {
        session = ListenSession.fromJson(res.data);
      } else {
        session = ListenSession(
          id: 0,
          roomId: roomId,
          hostId: hostId,
          hostName: hostName,
          resourceType: resourceType,
          resourceId: resourceId,
          resourceTitle: resourceTitle,
          audioUrl: audioUrl,
          isPlaying: true,
          positionSeconds: 0,
          updatedAt: DateTime.now(),
          isActive: true,
        );
      }

      _session = session;
      _currentRoomId = roomId;
      _isHost = true;
      _isJoined = true;

      await _player.setUrl(audioUrl);
      await _player.play();

      _syncTimer?.cancel();
      _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pushState());

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('startAsHost error: $e');
      _hasError = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> joinAsListener({
    required int roomId,
    required ListenSession session,
    required int myUserId,
  }) async {
    _isLoading = true;
    _hasError = false;
    _session = session;
    _currentRoomId = roomId;
    _isHost = (session.hostId == myUserId);
    _isJoined = true;
    notifyListeners();

    try {
      await _player.setUrl(session.audioUrl);
      if (session.positionSeconds > 0) {
        await _player.seek(Duration(milliseconds: (session.positionSeconds * 1000).round()));
      }
      if (session.isPlaying) {
        await _player.play();
      } else {
        await _player.pause();
      }

      _syncTimer?.cancel();
      if (_isHost) {
        _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pushState());
      } else {
        _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollAndSync());
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('joinAsListener error: $e');
      _hasError = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _pushState() async {
    if (!_isJoined || _session == null || _currentRoomId == null || !_isHost) return;
    final pos = _player.position.inMilliseconds / 1000.0;
    try {
      await _api.post(ApiConstants.communityListenSession(_currentRoomId!), {
        'resource_type': _session!.resourceType,
        'resource_id': _session!.resourceId,
        'resource_title': _session!.resourceTitle,
        'audio_url': _session!.audioUrl,
        'is_playing': _player.playing,
        'position_seconds': pos,
      });
    } catch (e) {
      debugPrint('_pushState error: $e');
    }
  }

  Future<void> _pollAndSync() async {
    if (!_isJoined || _currentRoomId == null) return;
    if (_lastLocalAction != null &&
        DateTime.now().difference(_lastLocalAction!) < _localActionCooldown) {
      return;
    }

    try {
      final res = await _api.get(ApiConstants.communityListenSession(_currentRoomId!));
      if (!res.isSuccess) return;
      final data = res.data['session'];
      if (data == null) {
        await leaveSession();
        return;
      }

      final updated = ListenSession.fromJson(data);
      if (!updated.isActive) {
        await leaveSession();
        return;
      }

      _session = updated;

      // Sync position if drift > 3s
      final remoteMs = (updated.positionSeconds * 1000).round();
      final localMs = _player.position.inMilliseconds;
      if ((remoteMs - localMs).abs() > 3000) {
        await _player.seek(Duration(milliseconds: remoteMs));
      }

      // Sync play/pause
      if (updated.isPlaying && !_player.playing) {
        await _player.play();
      } else if (!updated.isPlaying && _player.playing) {
        await _player.pause();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('_pollAndSync error: $e');
    }
  }

  Future<void> togglePlayPause() async {
    _lastLocalAction = DateTime.now();
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    if (_isHost) {
      await _pushState();
    }
    notifyListeners();
  }

  Future<void> seek(Duration target) async {
    _lastLocalAction = DateTime.now();
    await _player.seek(target);
    if (_isHost) {
      await _pushState();
    }
    notifyListeners();
  }

  Future<void> leaveSession() async {
    _syncTimer?.cancel();
    _syncTimer = null;
    try {
      await _player.stop();
    } catch (_) {}
    _isJoined = false;
    _session = null;
    _currentRoomId = null;
    _isHost = false;
    notifyListeners();
  }

  Future<void> endSession() async {
    _syncTimer?.cancel();
    _syncTimer = null;
    if (_currentRoomId != null && _isHost) {
      try {
        await _api.post(ApiConstants.communityListenSession(_currentRoomId!), {'end_session': true});
      } catch (_) {}
    }
    try {
      await _player.stop();
    } catch (_) {}
    _isJoined = false;
    _session = null;
    _currentRoomId = null;
    _isHost = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _playSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
