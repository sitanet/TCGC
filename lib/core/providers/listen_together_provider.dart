import 'dart:async';
import 'package:audio_session/audio_session.dart';
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
  String? _errorMessage;

  Timer? _syncTimer;
  DateTime? _lastLocalAction;
  DateTime? _lastSeekTime;
  bool _isSyncing = false;
  bool _isPushing = false;
  static const _localActionCooldown = Duration(seconds: 2);
  static const _seekCooldown = Duration(seconds: 6);

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
  String? get errorMessage => _errorMessage;
  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;
  AudioPlayer get player => _player;

  ListenTogetherNotifier() {
    _posSub = _player.positionStream.listen((_) => notifyListeners());
    _durSub = _player.durationStream.listen((_) => notifyListeners());
    _playSub = _player.playingStream.listen((playing) {
      if (_isHost && _isJoined && !_isPushing) {
        _pushState(isPlayingOverride: playing);
      }
      notifyListeners();
    });
    _stateSub = _player.playerStateStream.listen((state) {
      _isLoading = state.processingState == ProcessingState.buffering ||
          state.processingState == ProcessingState.loading;
      notifyListeners();
    });
  }

  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);
    } catch (e) {
      debugPrint('_configureAudioSession error: $e');
    }
  }

  Future<bool> startAsHost({
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
    _errorMessage = null;
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

      if (!res.isSuccess) {
        _hasError = true;
        _errorMessage = res.errorMessage ?? 'Another host is currently active in this room.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final session = ListenSession.fromJson(res.data);

      _session = session;
      _currentRoomId = roomId;
      _isHost = true;
      _isJoined = true;

      await _configureAudioSession();
      await _player.setUrl(audioUrl);
      await _player.play();

      _syncTimer?.cancel();
      _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pushState());

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('startAsHost error: $e');
      _hasError = true;
      _errorMessage = 'Could not start hosting session.';
      _isLoading = false;
      notifyListeners();
      return false;
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
      await _configureAudioSession();
      await _player.setUrl(session.audioUrl);
      var targetMs = (session.positionSeconds * 1000).round();
      if (session.isPlaying) {
        final ageMs = DateTime.now().toUtc().difference(session.updatedAt.toUtc()).inMilliseconds;
        if (ageMs > 0 && ageMs < 15000) {
          targetMs += ageMs;
        }
      }
      if (targetMs > 0) {
        await _player.seek(Duration(milliseconds: targetMs));
        _lastSeekTime = DateTime.now();
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
        // Poll sub-second so host pause/play propagates to listeners right away
        _syncTimer = Timer.periodic(const Duration(milliseconds: 800), (_) => _pollAndSync());
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

  Future<void> _pushState({bool? isPlayingOverride, bool force = false}) async {
    if (!_isJoined || _session == null || _currentRoomId == null || !_isHost) return;
    if (_isPushing && !force) return;
    _isPushing = true;
    final playing = isPlayingOverride ?? _player.playing;
    final pos = _player.position.inMilliseconds / 1000.0;
    try {
      await _api.post(ApiConstants.communityListenSession(_currentRoomId!), {
        'resource_type': _session!.resourceType,
        'resource_id': _session!.resourceId,
        'resource_title': _session!.resourceTitle,
        'audio_url': _session!.audioUrl,
        'is_playing': playing,
        'position_seconds': pos,
      });
      _session = ListenSession(
        id: _session!.id,
        roomId: _session!.roomId,
        hostId: _session!.hostId,
        hostName: _session!.hostName,
        resourceType: _session!.resourceType,
        resourceId: _session!.resourceId,
        resourceTitle: _session!.resourceTitle,
        audioUrl: _session!.audioUrl,
        isPlaying: playing,
        positionSeconds: pos,
        updatedAt: DateTime.now().toUtc(),
        isActive: _session!.isActive,
      );
    } catch (e) {
      debugPrint('_pushState error: $e');
    } finally {
      _isPushing = false;
    }
  }

  Future<void> _pollAndSync() async {
    if (!_isJoined || _currentRoomId == null || _isSyncing) return;
    if (_lastLocalAction != null &&
        DateTime.now().difference(_lastLocalAction!) < _localActionCooldown) {
      return;
    }

    _isSyncing = true;
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

      final previousAudioUrl = _session?.audioUrl;
      _session = updated;

      // Estimate live host position by adding elapsed time since last server update
      var estimatedRemoteMs = (updated.positionSeconds * 1000).round();
      if (updated.isPlaying) {
        final ageMs = DateTime.now().toUtc().difference(updated.updatedAt.toUtc()).inMilliseconds;
        if (ageMs > 0 && ageMs < 15000) {
          estimatedRemoteMs += ageMs;
        }
      }

      // Reload if host switched audio OR if listener player dropped back to idle
      final urlChanged = previousAudioUrl != updated.audioUrl && updated.audioUrl.isNotEmpty;
      final playerIdle = _player.processingState == ProcessingState.idle && updated.audioUrl.isNotEmpty;
      if (urlChanged || (updated.isPlaying && playerIdle)) {
        await _configureAudioSession();
        await _player.setUrl(updated.audioUrl);
        if (estimatedRemoteMs > 0) {
          await _player.seek(Duration(milliseconds: estimatedRemoteMs));
          _lastSeekTime = DateTime.now();
        }
        if (updated.isPlaying) {
          await _player.play();
        }
        notifyListeners();
        return;
      }

      // Skip drift-seeking while buffering/loading or within seek cooldown to prevent re-buffer silence loops
      final isBuffering = _player.processingState == ProcessingState.buffering ||
          _player.processingState == ProcessingState.loading;
      final inSeekCooldown = _lastSeekTime != null &&
          DateTime.now().difference(_lastSeekTime!) < _seekCooldown;

      if (!isBuffering && !inSeekCooldown) {
        final localMs = _player.position.inMilliseconds;
        if ((estimatedRemoteMs - localMs).abs() > 6000) {
          await _player.seek(Duration(milliseconds: estimatedRemoteMs));
          _lastSeekTime = DateTime.now();
        }
      }

      // Sync play/pause
      if (updated.isPlaying && !_player.playing) {
        await _configureAudioSession();
        await _player.play();
      } else if (!updated.isPlaying && _player.playing) {
        await _player.pause();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('_pollAndSync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> togglePlayPause() async {
    // Only the host controls play/pause for the room
    if (!_isHost) return;
    _lastLocalAction = DateTime.now();
    final willPlay = !_player.playing;
    if (willPlay) {
      await _player.play();
    } else {
      await _player.pause();
    }
    // Restart periodic timer so an in-flight/imminent tick doesn't overwrite this state
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pushState());
    await _pushState(isPlayingOverride: willPlay, force: true);
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
