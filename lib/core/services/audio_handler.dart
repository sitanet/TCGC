import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'seamless_audio_source.dart';

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;

  MyAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    
    _player.processingStateStream.listen((state) {
      debugPrint('Audio processing state: $state');
      if (state == ProcessingState.completed) {
        stop();
      }
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

  Future<void> setAudioSource(String url, MediaItem item) async {
    debugPrint('Setting audio source: $url');
    mediaItem.add(item);
    try {
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          headers: {
            'Accept': 'audio/mpeg, audio/*;q=0.9, */*;q=0.5',
            'User-Agent': 'TCGC-App/1.0',
          },
        ),
      );
      debugPrint('Audio source set successfully, duration: ${_player.duration}');
    } catch (e, st) {
      debugPrint('Error setting audio source: $e');
      debugPrint('Stack: $st');
      rethrow;
    }
  }

  Future<void> setAudioSourceWithPosition(String url, MediaItem item, Duration position) async {
    debugPrint('Setting audio source with position: $url at $position');
    mediaItem.add(item);
    try {
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          headers: {
            'Accept': 'audio/mpeg, audio/*;q=0.9, */*;q=0.5',
            'User-Agent': 'TCGC-App/1.0',
          },
        ),
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
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
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
  
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  bool get playing => _player.playing;
  ProcessingState get processingState => _player.processingState;
}
