import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../domain/entities/sermon.dart';

AudioHandler? _audioHandler;
bool _audioServiceInitialized = false;
String? _initError;

Future<void> initAudioService() async {
  if (_audioServiceInitialized) return;
  
  try {
    debugPrint('Initializing audio service...');
    _audioHandler = await AudioService.init(
      builder: () => AudioPlayerHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.tcgc.app.audio',
        androidNotificationChannelName: 'TCGC Audio',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidShowNotificationBadge: true,
        notificationColor: Color(0xFFD4A84B),
      ),
    );
    _audioServiceInitialized = true;
    debugPrint('Audio service initialized successfully');
  } catch (e, stack) {
    _initError = e.toString();
    debugPrint('Audio service init error: $e');
    debugPrint('Stack trace: $stack');
    // Continue without audio_service - use fallback player
  }
}

bool get isAudioServiceAvailable => _audioServiceInitialized && _audioHandler != null;

class AudioPlayerProvider extends ChangeNotifier {
  Sermon? _currentSermon;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _listenersSetup = false;
  
  // Fallback player when audio_service fails
  AudioPlayer? _fallbackPlayer;
  bool _usingFallback = false;

  Sermon? get currentSermon => _currentSermon;
  Duration get duration => _duration;
  Duration get position => _position;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasAudio => _currentSermon != null;

  AudioPlayerProvider() {
    _setupListeners();
  }

  void _setupListeners() {
    if (_audioServiceInitialized && _audioHandler != null && !_listenersSetup) {
      _listenersSetup = true;
      
      _audioHandler!.playbackState.listen((state) {
        _isPlaying = state.playing;
        _isLoading = state.processingState == AudioProcessingState.loading ||
                     state.processingState == AudioProcessingState.buffering;
        _position = state.position;
        notifyListeners();
      });

      _audioHandler!.mediaItem.listen((item) {
        if (item != null) {
          _duration = item.duration ?? Duration.zero;
          notifyListeners();
        }
      });
    }
  }
  
  void _setupFallbackPlayer() {
    if (_fallbackPlayer != null) return;
    
    _fallbackPlayer = AudioPlayer();
    _usingFallback = true;
    
    _fallbackPlayer!.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isLoading = state.processingState == ProcessingState.loading ||
                   state.processingState == ProcessingState.buffering;
      notifyListeners();
    });
    
    _fallbackPlayer!.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });
    
    _fallbackPlayer!.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });
  }

  Future<void> playSermon(Sermon sermon) async {
    // Try to setup audio service listeners
    _setupListeners();
    
    // If audio_service failed, use fallback player
    if (!_audioServiceInitialized || _audioHandler == null) {
      debugPrint('Using fallback audio player');
      _setupFallbackPlayer();
    }

    // If same sermon, just toggle play/pause
    if (_currentSermon?.id == sermon.id) {
      if (_isPlaying) {
        await pause();
      } else {
        await play();
      }
      return;
    }

    // New sermon - load and play
    _isLoading = true;
    _errorMessage = null;
    _currentSermon = sermon;
    notifyListeners();

    final audioUrl = sermon.audioUrl;
    if (audioUrl == null || audioUrl.isEmpty) {
      _isLoading = false;
      _errorMessage = 'No audio URL available for this sermon';
      notifyListeners();
      return;
    }
    
    debugPrint('Playing audio from: $audioUrl');

    try {
      if (_usingFallback && _fallbackPlayer != null) {
        // Use fallback player
        await _fallbackPlayer!.setUrl(audioUrl);
        await _fallbackPlayer!.play();
      } else if (_audioHandler != null) {
        // Use audio_service
        final mediaItem = MediaItem(
          id: sermon.id,
          title: sermon.title,
          artist: 'TCGC',
          album: sermon.categoryName.isNotEmpty ? sermon.categoryName : 'Sermons',
          duration: sermon.duration,
          artUri: sermon.imageUrl != null ? Uri.parse(sermon.imageUrl!) : null,
          extras: {'url': audioUrl},
        );
        await _audioHandler!.playMediaItem(mediaItem);
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load audio: $e';
      debugPrint('Audio playback error: $e');
      notifyListeners();
    }
  }

  Future<void> play() async {
    if (_usingFallback && _fallbackPlayer != null) {
      await _fallbackPlayer!.play();
    } else if (_audioServiceInitialized && _audioHandler != null) {
      await _audioHandler!.play();
    }
  }

  Future<void> pause() async {
    if (_usingFallback && _fallbackPlayer != null) {
      await _fallbackPlayer!.pause();
    } else if (_audioServiceInitialized && _audioHandler != null) {
      await _audioHandler!.pause();
    }
  }

  Future<void> stop() async {
    if (_usingFallback && _fallbackPlayer != null) {
      await _fallbackPlayer!.stop();
    } else if (_audioServiceInitialized && _audioHandler != null) {
      await _audioHandler!.stop();
    }
    _currentSermon = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    if (_usingFallback && _fallbackPlayer != null) {
      await _fallbackPlayer!.seek(position);
    } else if (_audioServiceInitialized && _audioHandler != null) {
      await _audioHandler!.seek(position);
    }
  }

  Future<void> seekForward() async {
    final newPosition = _position + const Duration(seconds: 10);
    if (newPosition < _duration) {
      await seek(newPosition);
    } else {
      await seek(_duration);
    }
  }

  Future<void> seekBackward() async {
    final newPosition = _position - const Duration(seconds: 10);
    if (newPosition > Duration.zero) {
      await seek(newPosition);
    } else {
      await seek(Duration.zero);
    }
  }

  @override
  void dispose() {
    if (_usingFallback && _fallbackPlayer != null) {
      _fallbackPlayer!.dispose();
    } else if (_audioServiceInitialized && _audioHandler != null) {
      _audioHandler!.stop();
    }
    super.dispose();
  }
}

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();

  AudioPlayerHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    
    _player.durationStream.listen((duration) {
      final item = mediaItem.value;
      if (item != null && duration != null) {
        mediaItem.add(item.copyWith(duration: duration));
      }
    });
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

  @override
  Future<void> playMediaItem(MediaItem item) async {
    mediaItem.add(item);
    final url = item.extras?['url'] as String?;
    if (url != null) {
      await _player.setUrl(url);
      await _player.play();
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> fastForward() => 
      _player.seek(_player.position + const Duration(seconds: 10));

  @override
  Future<void> rewind() => 
      _player.seek(_player.position - const Duration(seconds: 10));
}
