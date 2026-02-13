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
    // Skip audio_service on desktop platforms - use fallback player instead
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('Skipping audio_service on desktop platform');
      _audioServiceInitialized = true;
      return;
    }
    
    _audioHandler = await AudioService.init(
      builder: () => AudioPlayerHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.tcgc.app.audio',
        androidNotificationChannelName: 'TCGC Audio',
        androidNotificationChannelDescription: 'Sermon playback',
        androidNotificationIcon: 'drawable/ic_notification',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: false,
        androidResumeOnClick: true,
        preloadArtwork: true,
      ),
    );
    _audioServiceInitialized = true;
  } catch (e) {
    debugPrint('Audio service initialization failed: $e');
    _audioServiceInitialized = true; // Mark as initialized to use fallback
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
  
  // Playlist/Queue management for Next/Previous
  List<Sermon> _queue = [];
  int _currentIndex = -1;
  
  // Pre-buffering service for instant playback
  final AudioCacheService _audioCacheService = AudioCacheService();

  Sermon? get currentSermon => _currentSermon;
  Duration get duration => _duration;
  Duration get position => _position;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasAudio => _currentSermon != null;
  
  // Queue getters
  List<Sermon> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get hasNext => _currentIndex < _queue.length - 1;
  bool get hasPrevious => _currentIndex > 0;

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
      
      final handler = _audioHandler as AudioPlayerHandler;
      
      // Handle track completion for auto-advance
      handler.onTrackCompleted = () {
        if (hasNext) {
          skipToNext();
        }
      };
      
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
      debugPrint('Audio service not available, using fallback player (no notification support)');
      debugPrint('  _audioServiceInitialized: $_audioServiceInitialized');
      debugPrint('  _audioHandler: $_audioHandler');
      _setupFallbackPlayer();
    } else {
      debugPrint('Audio service available, will use notification player');
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
    debugPrint('Sermon Title: ${sermon.title}');
    debugPrint('Sermon Image: ${sermon.imageUrl}');
    debugPrint('Using audio_service: ${_audioServiceInitialized && _audioHandler != null && !_usingFallback}');

    try {
      if (_usingFallback && _fallbackPlayer != null) {
        // Fallback player - no notification support
        debugPrint('Streaming with fallback player: $audioUrl');
        await _fallbackPlayer!.setUrl(audioUrl);
        _fallbackPlayer!.play();
      } else if (_audioHandler != null) {
        // Use audio_service for notification support
        debugPrint('Creating MediaItem for notification...');
        final mediaItem = MediaItem(
          id: sermon.id,
          title: sermon.title,
          artist: sermon.speaker ?? 'TCGC',
          album: sermon.categoryName.isNotEmpty ? sermon.categoryName : 'Sermons',
          duration: sermon.duration,
          artUri: sermon.imageUrl != null ? Uri.parse(sermon.imageUrl!) : null,
          extras: {'url': audioUrl},
        );
        debugPrint('MediaItem created: ${mediaItem.title} by ${mediaItem.artist}');
        debugPrint('Calling playMediaItem...');
        // This sets media item and starts playback with notification
        await _audioHandler!.playMediaItem(mediaItem);
        debugPrint('playMediaItem completed');
      } else {
        debugPrint('ERROR: No audio handler available!');
        _errorMessage = 'Audio player not initialized';
        notifyListeners();
        return;
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

  /// Set the playback queue and start playing from the given index
  Future<void> playFromQueue(List<Sermon> sermons, int startIndex) async {
    if (sermons.isEmpty || startIndex < 0 || startIndex >= sermons.length) return;
    
    _queue = List.from(sermons);
    _currentIndex = startIndex;
    await playSermon(sermons[startIndex]);
  }
  
  /// Play next track in queue
  Future<void> skipToNext() async {
    if (!hasNext) return;
    _currentIndex++;
    await playSermon(_queue[_currentIndex]);
  }
  
  /// Play previous track in queue
  Future<void> skipToPrevious() async {
    // If more than 3 seconds into the track, restart it instead
    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    if (!hasPrevious) return;
    _currentIndex--;
    await playSermon(_queue[_currentIndex]);
  }
  
  /// Add sermon to end of queue
  void addToQueue(Sermon sermon) {
    _queue.add(sermon);
    notifyListeners();
  }
  
  /// Clear the queue
  void clearQueue() {
    _queue.clear();
    _currentIndex = -1;
    notifyListeners();
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
  
  // Callback for track completion (for auto-advance)
  void Function()? onTrackCompleted;

  AudioPlayerHandler() {
    _player.playbackEventStream.map(_transform).pipe(playbackState);
    _player.durationStream.listen((duration) {
      final item = mediaItem.value;
      if (item != null && duration != null) {
        mediaItem.add(item.copyWith(duration: duration));
      }
    });
    
    // Listen for track completion
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        onTrackCompleted?.call();
      }
    });
  }

  PlaybackState _transform(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
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
    );
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    this.mediaItem.add(mediaItem);
    final url = mediaItem.extras?['url'] as String;
    await _player.setUrl(url);
    await _player.play();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }
  
  @override
  Future<void> skipToNext() async {
    // This will be handled by the provider
  }
  
  @override
  Future<void> skipToPrevious() async {
    // This will be handled by the provider
  }
  
  @override
  Future<void> fastForward() => seek(_player.position + const Duration(seconds: 10));
  
  @override
  Future<void> rewind() => seek(_player.position - const Duration(seconds: 10));
}
