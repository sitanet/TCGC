import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/sermon.dart';
import '../../data/services/audio_cache_service.dart';
import '../../data/services/playback_position_service.dart';
import '../../data/services/download_service.dart';
import '../services/audio_handler.dart';

MyAudioHandler? _audioHandler;
AudioPlayer? _fallbackPlayer;
bool _audioServiceInitialized = false;
bool _useAudioService = false;

/// Fix malformed URLs (missing protocol prefix, etc.)
String _fixAudioUrl(String url) {
  if (url.startsWith('ttps://')) {
    return 'https://${url.substring(7)}';
  } else if (url.startsWith('ttp://')) {
    return 'http://${url.substring(6)}';
  } else if (!url.startsWith('http://') && !url.startsWith('https://') && !url.startsWith('file://')) {
    // Relative path - prepend base URL
    return 'https://tcgc.thecitygatechurch.org$url';
  }
  return url;
}

Future<void> initAudioService() async {
  if (_audioServiceInitialized) return;
  _audioServiceInitialized = true;
  
  try {
    _audioHandler = await AudioService.init(
      builder: () => MyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.tcgc.tcgc.audio',
        androidNotificationChannelName: 'TCGC Audio',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
      ),
    );
    _useAudioService = true;
    debugPrint('AudioService initialized successfully');
  } catch (e) {
    debugPrint('AudioService init failed: $e');
    debugPrint('Using fallback audio player');
    _fallbackPlayer = AudioPlayer();
    _useAudioService = false;
  }
}

class AudioPlayerProvider extends ChangeNotifier with WidgetsBindingObserver {
  Sermon? _currentSermon;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _errorMessage;
  
  Directory? _cacheDir;
  List<Sermon> _queue = [];
  int _currentIndex = -1;
  
  final AudioCacheService _audioCacheService = AudioCacheService();
  final PlaybackPositionService _positionService = PlaybackPositionService();
  final DownloadService _downloadService = DownloadService();

  Sermon? get currentSermon => _currentSermon;
  Duration get duration => _duration;
  Duration get position => _position;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasAudio => _currentSermon != null;
  
  List<Sermon> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get hasNext => _currentIndex < _queue.length - 1;
  bool get hasPrevious => _currentIndex > 0;

  AudioPlayerProvider() {
    WidgetsBinding.instance.addObserver(this);
    // Initialize in background
    Future.microtask(() async {
      await _initCacheDir();
      await _initPositionService();
      _setupListeners();
    });
  }
  
  bool _positionServiceInitialized = false;
  bool _listenersSetup = false;
  
  Future<void> _initPositionService() async {
    await _positionService.initialize();
    _positionServiceInitialized = true;
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _saveCurrentPosition();
    }
  }
  
  void _setupListeners() {
    if (_listenersSetup) return;
    _listenersSetup = true;
    
    if (_useAudioService && _audioHandler != null) {
      _setupAudioServiceListeners();
    } else if (_fallbackPlayer != null) {
      _setupFallbackListeners();
    }
  }
  
  void _setupAudioServiceListeners() {
    _audioHandler!.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isLoading = state.processingState == ProcessingState.loading ||
                   state.processingState == ProcessingState.buffering;
      
      if (state.processingState == ProcessingState.ready ||
          state.processingState == ProcessingState.idle) {
        _isLoading = false;
      }
      
      if (state.processingState == ProcessingState.completed) {
        _isLoading = false;
        if (hasNext) skipToNext();
      }
      notifyListeners();
    }, onError: (error) {
      debugPrint('Player state stream error: $error');
      _isLoading = false;
      _errorMessage = 'Playback error: $error';
      notifyListeners();
    });
    
    _audioHandler!.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });
    
    _audioHandler!.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });
  }
  
  void _setupFallbackListeners() {
    _fallbackPlayer!.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isLoading = state.processingState == ProcessingState.loading ||
                   state.processingState == ProcessingState.buffering;
      
      if (state.processingState == ProcessingState.ready ||
          state.processingState == ProcessingState.idle) {
        _isLoading = false;
      }
      
      if (state.processingState == ProcessingState.completed) {
        _isLoading = false;
        if (hasNext) skipToNext();
      }
      notifyListeners();
    }, onError: (error) {
      debugPrint('Fallback player state stream error: $error');
      _isLoading = false;
      _errorMessage = 'Playback error: $error';
      notifyListeners();
    });
    
    _fallbackPlayer!.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    }, onError: (error) {
      debugPrint('Fallback position stream error: $error');
    });
    
    _fallbackPlayer!.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    }, onError: (error) {
      debugPrint('Fallback duration stream error: $error');
    });
  }
  
  Future<void> preBufferSermons(List<Sermon> sermons, {int count = 20}) async {
    await _audioCacheService.preBufferCategory(sermons, count: count);
  }
  
  Future<void> preBufferMore(List<Sermon> sermons, int startIndex, {int count = 10}) async {
    await _audioCacheService.preBufferMore(sermons, startIndex, count: count);
  }
  
  /// Pre-buffer a single sermon for instant playback (called when user taps)
  Future<void> preBufferSingle(Sermon sermon) async {
    await _audioCacheService.preBufferSingle(sermon);
  }
  
  bool isPreBuffered(String sermonId) => _audioCacheService.isPreBuffered(sermonId);
  double getBufferProgress(String sermonId) => _audioCacheService.getBufferProgress(sermonId);
  bool isBuffering(String sermonId) => _audioCacheService.isBuffering(sermonId);
  
  Future<void> _initCacheDir() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/audio_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
    } catch (e) {
      debugPrint('Failed to create cache directory: $e');
    }
  }
  
  String _sanitizeFileName(String id) => id.replaceAll(RegExp(r'[^\w\-]'), '_');

  Future<void> playSermon(Sermon sermon) async {
    // Toggle play/pause if same sermon
    if (_currentSermon?.id == sermon.id) {
      if (_isPlaying) {
        await pause();
      } else {
        await play();
      }
      return;
    }

    // Update UI immediately - no loading state for pre-buffered content
    _errorMessage = null;
    _currentSermon = sermon;
    _position = Duration.zero;
    
    final audioUrl = sermon.audioUrl;
    if (audioUrl == null || audioUrl.isEmpty) {
      _errorMessage = 'No audio URL available for this sermon';
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    // Initialize audio service if needed (should already be done)
    if (!_audioServiceInitialized) {
      await initAudioService();
      _setupListeners();
    }

    // Fix malformed URLs (e.g., "ttps://" -> "https://")
    final fixedAudioUrl = _fixAudioUrl(audioUrl);
    if (fixedAudioUrl != audioUrl) {
      debugPrint('Fixed malformed URL: $audioUrl -> $fixedAudioUrl');
    }

    try {
      // Check for downloaded audio (local file)
      String? downloadedPath;
      if (_downloadService.isDownloaded(sermon.id)) {
        downloadedPath = _downloadService.getLocalPath(sermon.id);
        if (downloadedPath != null) {
          final file = File(downloadedPath);
          if (!await file.exists()) {
            downloadedPath = null;
          }
        }
      }

      final mediaItem = MediaItem(
        id: sermon.id,
        title: sermon.title,
        artist: sermon.speaker ?? 'TCGC',
        album: sermon.categoryName.isNotEmpty ? sermon.categoryName : 'Messages',
        artUri: sermon.imageUrl != null ? Uri.parse(sermon.imageUrl!) : null,
      );

      // Log the audio URL for debugging
      debugPrint('Attempting to play audio: $fixedAudioUrl');
      debugPrint('Downloaded path: $downloadedPath');

      if (_useAudioService && _audioHandler != null) {
        // Stop previous without waiting
        _audioHandler!.stop();
        
        if (downloadedPath != null) {
          debugPrint('Playing from local file');
          await _audioHandler!.setAudioSource('file://$downloadedPath', mediaItem);
        } else {
          // Stream directly - large files may take time to buffer
          debugPrint('Streaming from URL');
          await _audioHandler!.setAudioSource(fixedAudioUrl, mediaItem).timeout(
            const Duration(seconds: 180), // 3 minutes for large files
            onTimeout: () {
              throw Exception('Connection timeout - please check your internet connection or try downloading the audio.');
            },
          );
        }
        _audioHandler!.play();
      } else if (_fallbackPlayer != null) {
        _fallbackPlayer!.stop();
        
        if (downloadedPath != null) {
          debugPrint('Playing from local file (fallback)');
          await _fallbackPlayer!.setAudioSource(AudioSource.uri(Uri.parse('file://$downloadedPath')));
        } else {
          // Stream directly - large files may take time to buffer
          debugPrint('Streaming from URL (fallback)');
          await _fallbackPlayer!.setAudioSource(AudioSource.uri(Uri.parse(fixedAudioUrl))).timeout(
            const Duration(seconds: 180), // 3 minutes for large files
            onTimeout: () {
              throw Exception('Connection timeout - please check your internet connection or try downloading the audio.');
            },
          );
        }
        _fallbackPlayer!.play();
      }
      _isLoading = false;
      notifyListeners();
    } catch (e, stackTrace) {
      _isLoading = false;
      
      // Provide user-friendly error messages
      String userMessage;
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('socketexception') || errorStr.contains('connection')) {
        userMessage = 'Unable to connect. Please check your internet connection.';
      } else if (errorStr.contains('404') || errorStr.contains('not found')) {
        userMessage = 'Audio file not found on server. Please contact support.';
      } else if (errorStr.contains('403') || errorStr.contains('forbidden')) {
        userMessage = 'Access denied. Please try again or re-login.';
      } else if (errorStr.contains('timeout')) {
        userMessage = 'Connection timeout. Large files may take time to load. Try downloading for offline playback.';
      } else if (errorStr.contains('format') || errorStr.contains('codec')) {
        userMessage = 'Audio format not supported.';
      } else {
        userMessage = 'Unable to stream audio. Large files may take time to load.';
      }
      
      _errorMessage = userMessage;
      debugPrint('Audio error: $e');
      debugPrint('Original URL: $audioUrl');
      debugPrint('Fixed URL: $fixedAudioUrl');
      debugPrint('Stack: $stackTrace');
      notifyListeners();
    }
  }

  Future<void> play() async {
    if (_useAudioService && _audioHandler != null) {
      await _audioHandler!.play();
    } else {
      await _fallbackPlayer?.play();
    }
  }

  Future<void> pause() async {
    if (_useAudioService && _audioHandler != null) {
      await _audioHandler!.pause();
    } else {
      await _fallbackPlayer?.pause();
    }
    await _saveCurrentPosition();
  }
  
  Future<void> _saveCurrentPosition() async {
    if (_currentSermon != null && _position.inMilliseconds > 0 && _duration.inMilliseconds > 0) {
      await _positionService.savePosition(_currentSermon!.id, _position, _duration);
    }
  }

  Future<void> stop() async {
    await _saveCurrentPosition();
    if (_useAudioService && _audioHandler != null) {
      await _audioHandler!.stop();
    } else {
      await _fallbackPlayer?.stop();
    }
    _currentSermon = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    if (_useAudioService && _audioHandler != null) {
      await _audioHandler!.seek(position);
    } else {
      await _fallbackPlayer?.seek(position);
    }
  }

  Future<void> seekForward() async {
    final newPosition = _position + const Duration(seconds: 10);
    await seek(newPosition < _duration ? newPosition : _duration);
  }

  Future<void> seekBackward() async {
    final newPosition = _position - const Duration(seconds: 10);
    await seek(newPosition > Duration.zero ? newPosition : Duration.zero);
  }
  
  PlaybackPosition? getSavedPosition(String sermonId) {
    if (!_positionServiceInitialized) return null;
    return _positionService.getPosition(sermonId);
  }
  
  bool hasSavedPosition(String sermonId) {
    if (!_positionServiceInitialized) return false;
    return _positionService.hasPosition(sermonId);
  }
  
  Future<void> clearSavedPosition(String sermonId) async {
    await _positionService.clearPosition(sermonId);
  }
  
  Future<void> playSermonFromPosition(Sermon sermon, Duration startPosition) async {
    _errorMessage = null;
    _currentSermon = sermon;
    _position = startPosition;

    final audioUrl = sermon.audioUrl;
    if (audioUrl == null || audioUrl.isEmpty) {
      _errorMessage = 'No audio URL available for this sermon';
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    if (!_audioServiceInitialized) {
      await initAudioService();
      _setupListeners();
    }

    // Fix malformed URLs
    final fixedAudioUrl = _fixAudioUrl(audioUrl);

    try {
      // Check for downloaded audio
      String? downloadedPath;
      if (_downloadService.isDownloaded(sermon.id)) {
        downloadedPath = _downloadService.getLocalPath(sermon.id);
        if (downloadedPath != null) {
          final file = File(downloadedPath);
          if (!await file.exists()) downloadedPath = null;
        }
      }

      final mediaItem = MediaItem(
        id: sermon.id,
        title: sermon.title,
        artist: sermon.speaker ?? 'TCGC',
        album: sermon.categoryName.isNotEmpty ? sermon.categoryName : 'Messages',
        artUri: sermon.imageUrl != null ? Uri.parse(sermon.imageUrl!) : null,
      );

      debugPrint('Playing from position: $fixedAudioUrl');

      if (_useAudioService && _audioHandler != null) {
        _audioHandler!.stop();
        
        if (downloadedPath != null) {
          await _audioHandler!.setAudioSourceWithPosition('file://$downloadedPath', mediaItem, startPosition);
        } else {
          // Stream directly
          await _audioHandler!.setAudioSourceWithPosition(fixedAudioUrl, mediaItem, startPosition).timeout(
            const Duration(seconds: 180),
            onTimeout: () {
              throw Exception('Connection timeout - please check your internet connection.');
            },
          );
        }
        _audioHandler!.play();
      } else if (_fallbackPlayer != null) {
        _fallbackPlayer!.stop();
        
        if (downloadedPath != null) {
          await _fallbackPlayer!.setAudioSource(AudioSource.uri(Uri.parse('file://$downloadedPath')), initialPosition: startPosition);
        } else {
          // Stream directly
          await _fallbackPlayer!.setAudioSource(AudioSource.uri(Uri.parse(fixedAudioUrl)), initialPosition: startPosition).timeout(
            const Duration(seconds: 180),
            onTimeout: () {
              throw Exception('Connection timeout - please check your internet connection.');
            },
          );
        }
        _fallbackPlayer!.play();
      }
      _isLoading = false;
      notifyListeners();
    } catch (e, stackTrace) {
      _isLoading = false;
      _errorMessage = 'Unable to stream audio. Please check your connection.';
      debugPrint('Audio error: $e');
      debugPrint('URL: $fixedAudioUrl');
      debugPrint('Stack: $stackTrace');
      notifyListeners();
    }
  }

  void setQueue(List<Sermon> sermons, int startIndex) {
    if (sermons.isEmpty || startIndex < 0 || startIndex >= sermons.length) return;
    _queue = List.from(sermons);
    _currentIndex = startIndex;
  }
  
  Future<void> playFromQueue(List<Sermon> sermons, int startIndex) async {
    if (sermons.isEmpty || startIndex < 0 || startIndex >= sermons.length) return;
    _queue = List.from(sermons);
    _currentIndex = startIndex;
    await playSermon(sermons[startIndex]);
  }
  
  Future<void> skipToNext() async {
    if (!hasNext) return;
    _currentIndex++;
    await playSermon(_queue[_currentIndex]);
  }
  
  Future<void> skipToPrevious() async {
    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    if (!hasPrevious) return;
    _currentIndex--;
    await playSermon(_queue[_currentIndex]);
  }
  
  void addToQueue(Sermon sermon) {
    _queue.add(sermon);
    notifyListeners();
  }
  
  void clearQueue() {
    _queue.clear();
    _currentIndex = -1;
    notifyListeners();
  }

  Future<bool> isSermonCached(String sermonId) async {
    if (_cacheDir == null) return false;
    final fileName = _sanitizeFileName(sermonId);
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
          if (entity is File) totalSize += await entity.length();
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
          if (entity is File) await entity.delete();
        }
      }
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
        if (await cacheFile.exists()) await cacheFile.delete();
      }
    } catch (e) {
      debugPrint('Error deleting cached sermon: $e');
    }
  }

  // Livestream support
  bool _isLiveStream = false;
  bool get isLiveStream => _isLiveStream;

  Future<void> playLiveStream(String streamUrl, {String title = 'Live Stream', String subtitle = 'TCGC Live'}) async {
    _errorMessage = null;
    _isLiveStream = true;
    _isLoading = true;
    _queue.clear();
    _currentIndex = -1;
    notifyListeners();

    // Create a pseudo-sermon for the livestream
    _currentSermon = Sermon(
      id: 'livestream',
      title: title,
      description: subtitle,
      category: 'Live',
      categoryName: 'Live Stream',
      date: DateTime.now(),
      duration: Duration.zero,
      audioUrl: streamUrl,
    );

    try {
      final mediaItem = MediaItem(
        id: 'livestream',
        title: title,
        artist: subtitle,
        album: 'TCGC Live',
        artUri: null,
      );

      if (_useAudioService && _audioHandler != null) {
        _audioHandler!.stop();
        await _audioHandler!.setAudioSource(streamUrl, mediaItem);
        _audioHandler!.play();
      } else if (_fallbackPlayer != null) {
        _fallbackPlayer!.stop();
        await _fallbackPlayer!.setAudioSource(AudioSource.uri(Uri.parse(streamUrl)));
        _fallbackPlayer!.play();
      }

      _isPlaying = true;
      _isLoading = false;
    } catch (e) {
      debugPrint('Livestream playback error: $e');
      _errorMessage = 'Failed to play live stream: $e';
      _isLoading = false;
      _isLiveStream = false;
    }
    notifyListeners();
  }

  Future<void> stopLiveStream() async {
    if (_isLiveStream) {
      await stop();
      _isLiveStream = false;
      _currentSermon = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveCurrentPosition();
    _fallbackPlayer?.dispose();
    super.dispose();
  }
}
