import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/sermon.dart';
import '../../data/services/audio_cache_service.dart';
import '../../data/services/playback_position_service.dart';

bool _audioServiceInitialized = false;

Future<void> initAudioService() async {
  if (_audioServiceInitialized) return;

  try {
    // Request notification permission on Android 13+
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    }
    
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.tcgc.app.audio',
      androidNotificationChannelName: 'TCGC Audio',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'drawable/ic_notification',
      preloadArtwork: true,
    );
    _audioServiceInitialized = true;
    debugPrint('JustAudioBackground initialized successfully');
  } catch (e) {
    debugPrint('JustAudioBackground initialization failed: $e');
    _audioServiceInitialized = true; // Mark as done to avoid retrying
  }
}

class AudioPlayerProvider extends ChangeNotifier with WidgetsBindingObserver {
  AudioPlayer? _player;
  
  Sermon? _currentSermon;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Audio caching
  Directory? _cacheDir;
  
  // Playlist/Queue management
  List<Sermon> _queue = [];
  int _currentIndex = -1;
  
  // Pre-buffering service
  final AudioCacheService _audioCacheService = AudioCacheService();
  
  // Playback position service
  final PlaybackPositionService _positionService = PlaybackPositionService();

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
    _initCacheDir();
    _audioCacheService.initialize();
    _initPositionService();
    WidgetsBinding.instance.addObserver(this);
  }
  
  bool _positionServiceInitialized = false;
  
  Future<void> _initPositionService() async {
    await _positionService.initialize();
    _positionServiceInitialized = true;
  }
  
  Future<AudioPlayer> _getPlayer() async {
    if (_player == null) {
      // Ensure audio service is initialized first
      if (!_audioServiceInitialized) {
        await initAudioService();
      }
      _player = AudioPlayer();
      _setupListeners();
    }
    return _player!;
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
    if (_player == null) return;
    
    _player!.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isLoading = state.processingState == ProcessingState.loading ||
                   state.processingState == ProcessingState.buffering;
      
      // Auto-advance on completion
      if (state.processingState == ProcessingState.completed) {
        if (hasNext) {
          skipToNext();
        }
      }
      notifyListeners();
    });
    
    _player!.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });
    
    _player!.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });
  }
  
  /// Pre-buffer sermons for instant playback
  Future<void> preBufferSermons(List<Sermon> sermons, {int count = 20}) async {
    await _audioCacheService.preBufferCategory(sermons, count: count);
  }
  
  /// Pre-buffer more sermons when user scrolls
  Future<void> preBufferMore(List<Sermon> sermons, int startIndex, {int count = 10}) async {
    await _audioCacheService.preBufferMore(sermons, startIndex, count: count);
  }
  
  bool isPreBuffered(String sermonId) {
    return _audioCacheService.isPreBuffered(sermonId);
  }
  
  double getBufferProgress(String sermonId) {
    return _audioCacheService.getBufferProgress(sermonId);
  }
  
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
    } catch (e) {
      debugPrint('Failed to create cache directory: $e');
    }
  }
  
  String _sanitizeFileName(String id) {
    return id.replaceAll(RegExp(r'[^\w\-]'), '_');
  }

  Future<void> playSermon(Sermon sermon) async {
    // Ensure player is initialized (this also initializes audio service)
    final player = await _getPlayer();

    // If same sermon, toggle play/pause
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
    
    debugPrint('Playing sermon: ${sermon.title}');
    debugPrint('Audio URL: $audioUrl');

    try {
      // Create AudioSource with metadata for notification
      final audioSource = AudioSource.uri(
        Uri.parse(audioUrl),
        tag: MediaItem(
          id: sermon.id,
          title: sermon.title,
          artist: sermon.speaker ?? 'TCGC',
          album: sermon.categoryName.isNotEmpty ? sermon.categoryName : 'Sermons',
          artUri: sermon.imageUrl != null ? Uri.parse(sermon.imageUrl!) : null,
        ),
      );
      
      await player.setAudioSource(audioSource);
      await player.play();
      
      _isLoading = false;
      notifyListeners();
    } catch (e, stackTrace) {
      _isLoading = false;
      _errorMessage = 'Failed to load audio: $e';
      debugPrint('Audio error: $e');
      debugPrint('Stack: $stackTrace');
      notifyListeners();
    }
  }

  Future<void> play() async {
    final player = await _getPlayer();
    await player.play();
  }

  Future<void> pause() async {
    await _player?.pause();
    await _saveCurrentPosition();
  }
  
  Future<void> _saveCurrentPosition() async {
    if (_currentSermon != null && _position.inMilliseconds > 0 && _duration.inMilliseconds > 0) {
      await _positionService.savePosition(_currentSermon!.id, _position, _duration);
    }
  }

  Future<void> stop() async {
    await _saveCurrentPosition();
    await _player?.stop();
    _currentSermon = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _player?.seek(position);
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
    final player = await _getPlayer();

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

    try {
      final audioSource = AudioSource.uri(
        Uri.parse(audioUrl),
        tag: MediaItem(
          id: sermon.id,
          title: sermon.title,
          artist: sermon.speaker ?? 'TCGC',
          album: sermon.categoryName.isNotEmpty ? sermon.categoryName : 'Sermons',
          artUri: sermon.imageUrl != null ? Uri.parse(sermon.imageUrl!) : null,
        ),
      );
      
      await player.setAudioSource(audioSource, initialPosition: startPosition);
      await player.play();
      
      _isLoading = false;
      notifyListeners();
    } catch (e, stackTrace) {
      _isLoading = false;
      _errorMessage = 'Failed to load audio: $e';
      debugPrint('Audio error: $e');
      debugPrint('Stack: $stackTrace');
      notifyListeners();
    }
  }

  /// Set the playback queue and start playing from the given index
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
        }
      }
    } catch (e) {
      debugPrint('Error deleting cached sermon: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveCurrentPosition();
    _player?.dispose();
    super.dispose();
  }
}
