import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/sermon.dart';
import '../../data/services/audio_cache_service.dart';

AudioHandler? _audioHandler;
bool _audioServiceInitialized = false;

Future<void> initAudioService() async {
  if (_audioServiceInitialized) return;
  
  try {
    debugPrint('Initializing audio service...');
    _audioHandler = await AudioService.init(
      builder: () => AudioPlayerHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.tcgc.app.audio',
        androidNotificationChannelName: 'TCGC Audio',
        androidNotificationChannelDescription: 'Audio playback controls',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: false,
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidResumeOnClick: true,
        androidShowNotificationBadge: true,
        notificationColor: const Color(0xFFD4A84B),
        preloadArtwork: true,
        fastForwardInterval: const Duration(seconds: 10),
        rewindInterval: const Duration(seconds: 10),
      ),
    );
    _audioServiceInitialized = true;
    debugPrint('Audio service initialized successfully');
  } catch (e, stack) {
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
  
  // Audio caching
  Directory? _cacheDir;
  
  // Pre-buffering service for instant playback
  final AudioCacheService _audioCacheService = AudioCacheService();

  Sermon? get currentSermon => _currentSermon;
  Duration get duration => _duration;
  Duration get position => _position;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasAudio => _currentSermon != null;

  AudioPlayerProvider() {
    _setupListeners();
    _initCacheDir();
    _audioCacheService.initialize();
  }
  
  /// Pre-buffer sermons for instant playback when user opens a category
  Future<void> preBufferSermons(List<Sermon> sermons, {int count = 20}) async {
    await _audioCacheService.preBufferCategory(sermons, count: count);
  }
  
  /// Pre-buffer more sermons when user scrolls (infinite scroll)
  Future<void> preBufferMore(List<Sermon> sermons, int startIndex, {int count = 10}) async {
    await _audioCacheService.preBufferMore(sermons, startIndex, count: count);
  }
  
  /// Check if a sermon is pre-buffered for instant playback
  bool isPreBuffered(String sermonId) {
    return _audioCacheService.isPreBuffered(sermonId);
  }
  
  /// Get buffering progress for a sermon (0.0 to 1.0)
  double getBufferProgress(String sermonId) {
    return _audioCacheService.getBufferProgress(sermonId);
  }
  
  /// Check if buffering is in progress for a sermon
  bool isBuffering(String sermonId) {
    return _audioCacheService.isBuffering(sermonId);
  }
  
  Future<void> _initCacheDir() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/audio_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      debugPrint('Audio cache directory: ${_cacheDir!.path}');
    } catch (e) {
      debugPrint('Failed to create cache directory: $e');
    }
  }
  
  String _sanitizeFileName(String id) {
    return id.replaceAll(RegExp(r'[^\w\-]'), '_');
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
    
    // Always prefer audio_service for notification support
    // Only use fallback if audio_service truly failed to initialize
    if (!_audioServiceInitialized || _audioHandler == null) {
      debugPrint('Using fallback audio player (no notification support)');
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
    
    debugPrint('=== AUDIO DEBUG ===');
    debugPrint('Audio URL: $audioUrl');
    debugPrint('Sermon ID: ${sermon.id}');
    debugPrint('Using audio_service: ${!_usingFallback}');

    try {
      if (_usingFallback && _fallbackPlayer != null) {
        // Fallback player - no notification support
        debugPrint('Streaming with fallback player: $audioUrl');
        // Use direct URL for fastest startup
        await _fallbackPlayer!.setUrl(audioUrl);
        _fallbackPlayer!.play();
      } else if (_audioHandler != null) {
        // Use audio_service for notification support
        final mediaItem = MediaItem(
          id: sermon.id,
          title: sermon.title,
          artist: sermon.speaker ?? 'TCGC',
          album: sermon.categoryName.isNotEmpty ? sermon.categoryName : 'Sermons',
          duration: sermon.duration,
          artUri: sermon.imageUrl != null ? Uri.parse(sermon.imageUrl!) : null,
          extras: {'url': audioUrl},
        );
        // This sets media item and starts playback with notification
        await _audioHandler!.playMediaItem(mediaItem);
      }
      _isLoading = false;
      notifyListeners();
    } catch (e, stackTrace) {
      _isLoading = false;
      _errorMessage = 'Failed to load audio: $e';
      debugPrint('=== AUDIO ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('URL was: $audioUrl');
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

  Future<bool> isSermonCached(String sermonId) async {
    if (_cacheDir == null) return false;
    final fileName = _sanitizeFileName(sermonId);
    // Check for any audio extension
    final extensions = ['.ogg', '.mp3', '.wav', '.m4a', '.aac', '.audio'];
    for (final ext in extensions) {
      final cacheFile = File('${_cacheDir!.path}/$fileName$ext');
      if (await cacheFile.exists()) return true;
    }
    return false;
  }
  
  Future<int> getCacheSize() async {
    if (_cacheDir == null) return 0;
    int totalSize = 0;
    try {
      if (await _cacheDir!.exists()) {
        await for (var entity in _cacheDir!.list()) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (e) {
      debugPrint('Error calculating cache size: $e');
    }
    return totalSize;
  }
  
  Future<void> clearCache() async {
    if (_cacheDir == null) return;
    try {
      if (await _cacheDir!.exists()) {
        await for (var entity in _cacheDir!.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
      debugPrint('Audio cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }
  
  Future<void> deleteCachedSermon(String sermonId) async {
    if (_cacheDir == null) return;
    try {
      final fileName = _sanitizeFileName(sermonId);
      final extensions = ['.ogg', '.mp3', '.wav', '.m4a', '.aac', '.audio'];
      for (final ext in extensions) {
        final cacheFile = File('${_cacheDir!.path}/$fileName$ext');
        if (await cacheFile.exists()) {
          await cacheFile.delete();
          debugPrint('Deleted cached sermon: $sermonId');
        }
      }
    } catch (e) {
      debugPrint('Error deleting cached sermon: $e');
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
        MediaControl.fastForward,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.stop,
      },
      androidCompactActionIndices: const [0, 1, 2],
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
  // ignore: avoid_renaming_method_parameters
  Future<void> playMediaItem(MediaItem newMediaItem) async {
    // Add media item immediately so notification appears
    mediaItem.add(newMediaItem);
    
    final url = newMediaItem.extras?['url'] as String?;
    if (url != null) {
      try {
        debugPrint('AudioPlayerHandler: Playing $url');
        // Use direct URL streaming for fastest startup
        // This ensures notification works and audio starts immediately
        await _player.setUrl(url);
        await _player.play();
        debugPrint('AudioPlayerHandler: Playback started');
      } catch (e) {
        debugPrint('AudioPlayerHandler error: $e');
        rethrow;
      }
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
