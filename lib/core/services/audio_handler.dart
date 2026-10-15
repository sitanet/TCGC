import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'seamless_audio_source.dart';

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer(
    audioLoadConfiguration: const AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: Duration(seconds: 15),
        maxBufferDuration: Duration(seconds: 60),
        bufferForPlaybackDuration: Duration(milliseconds: 100),
        bufferForPlaybackAfterRebufferDuration: Duration(seconds: 2),
        prioritizeTimeOverSizeThresholds: true,
      ),
      darwinLoadControl: DarwinLoadControl(
        automaticallyWaitsToMinimizeStalling: false,
      ),
    ),
  );
  
  // Store current audio info for reloading after system kills the source
  String? _currentUrl;
  MediaItem? _currentMediaItem;
  Duration _lastPosition = Duration.zero;

  AudioPlayer get player => _player;

  MyAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    
    _player.processingStateStream.listen((state) {
      debugPrint('Audio processing state: $state');
      if (state == ProcessingState.completed) {
        // Don't call stop() - just update state, keep notification visible
        _player.pause();
        _player.seek(Duration.zero);
      }
    });
    
    // Track position for recovery
    _player.positionStream.listen((position) {
      _lastPosition = position;
    });
    
    // Listen for errors
    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        debugPrint('Audio playback error: $e');
        debugPrint('Stack: $st');
      },
    );
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  /// Build an audio source without custom headers.
  /// Passing headers forces just_audio to route through a local proxy server,
  /// which breaks streaming on newer Flutter/Android builds. ExoPlayer/AVPlayer
  /// stream directly from the CDN much more reliably.
  static AudioSource buildSource(String url) {
    if (url.startsWith('file://')) {
      return AudioSource.file(Uri.parse(url).toFilePath());
    }
    if (url.startsWith('/')) {
      return AudioSource.file(url);
    }
    final safeUrl = url.trim().contains(' ') ? Uri.encodeFull(url.trim()) : url.trim();
    return ProgressiveAudioSource(
      Uri.parse(safeUrl),
      options: const ProgressiveAudioSourceOptions(
        androidExtractorOptions: AndroidExtractorOptions(
          constantBitrateSeekingEnabled: true,
          constantBitrateSeekingAlwaysEnabled: true,
        ),
      ),
    );
  }

  Future<void> setAudioSource(String url, MediaItem item) async {
    debugPrint('Setting audio source: $url');
    _currentUrl = url;
    _currentMediaItem = item;
    _lastPosition = Duration.zero;
    mediaItem.add(item);
    try {
      await _player.setAudioSource(buildSource(url));
      debugPrint('Audio source set successfully, duration: ${_player.duration}');
    } catch (e, st) {
      debugPrint('Error setting audio source: $e');
      debugPrint('Stack: $st');
      rethrow;
    }
  }

  Future<void> setAudioSourceWithPosition(String url, MediaItem item, Duration position) async {
    debugPrint('Setting audio source with position: $url at $position');
    _currentUrl = url;
    _currentMediaItem = item;
    _lastPosition = position;
    mediaItem.add(item);
    try {
      await _player.setAudioSource(
        buildSource(url),
        initialPosition: position,
      );
      debugPrint('Audio source set successfully with position');
    } catch (e, st) {
      debugPrint('Error setting audio source with position: $e');
      debugPrint('Stack: $st');
      rethrow;
    }
  }

  Future<void> setSeamlessAudioSource(SeamlessAudioSource source, MediaItem item) async {
    mediaItem.add(item);
    await _player.setAudioSource(source);
  }

  Future<void> setSeamlessAudioSourceWithPosition(SeamlessAudioSource source, MediaItem item, Duration position) async {
    mediaItem.add(item);
    await _player.setAudioSource(source, initialPosition: position);
  }

  @override
  Future<void> play() async {
    // If player is in idle state, the source was released by system - reload it
    if (_player.processingState == ProcessingState.idle) {
      debugPrint('Player in idle state, reloading source...');
      if (_currentUrl != null && _currentMediaItem != null) {
        try {
          await setAudioSourceWithPosition(_currentUrl!, _currentMediaItem!, _lastPosition);
          await _player.play();
          debugPrint('Successfully reloaded and resumed playback');
        } catch (e) {
          debugPrint('Error reloading audio source: $e');
        }
      } else {
        debugPrint('No previous audio to reload');
      }
      return;
    }
    await _player.play();
  }

  @override
  Future<void> pause() async {
    _lastPosition = _player.position; // Save position before pause
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    _lastPosition = _player.position; // Save position before stop
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('Error stopping player: $e');
    }
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> fastForward() => _player.seek(_player.position + const Duration(seconds: 10));

  @override
  Future<void> rewind() => _player.seek(_player.position - const Duration(seconds: 10));

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<double> get speedStream => _player.speedStream;
  
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  bool get playing => _player.playing;
  ProcessingState get processingState => _player.processingState;
  double get speed => _player.speed;

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);
}
