import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/sermon.dart';
import '../../data/services/audio_cache_service.dart';
import '../../data/services/playback_position_service.dart';
import '../services/audio_handler.dart';

MyAudioHandler? _audioHandler;
AudioPlayer? _fallbackPlayer;
bool _audioServiceInitialized = false;
bool _useAudioService = false;

Future<void> initAudioService() async {
  if (_audioServiceInitialized) return;
  _audioServiceInitialized = true;
  
  try {
    _audioHandler = await AudioService.init(
      builder: () => MyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.tcgc.tcgc.audio',
        androidNotificationChannelName: 'TCGC Audio',
        androidNotificationOngoing: true,
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
    _initCacheDir();
    _audioCacheService.initialize();
    _initPositionService();
    WidgetsBinding.instance.addObserver(this);
    _initProvider();
  }
  
  bool _positionServiceInitialized = false;
  bool _listenersSetup = false;
  
  Future<void> _initProvider() async {
    if (!_audioServiceInitialized) {
      await initAudioService();
    }
    _setupListeners();
  }
  
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
  
  Future<void> preBufferSermons(List<Sermon> sermons, {int count = 20}) async {
    await _audioCacheService.preBufferCategory(sermons, count: count);
  }
  
  Future<void> preBufferMore(List<Sermon> sermons, int startIndex, {int count = 10}) async {
    await _audioCacheService.preBufferMore(sermons, startIndex, count: count);
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
    if (!_audioServiceInitialized) {
      await initAudioService();
      _setupListeners();
    }

    if (_currentSermon?.id == sermon.id) {
      if (_isPlaying) {
        await pause();
      } else {
        await play();
      }
      return;
    }

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
      if (_useAudioService && _audioHandler != null) {
        await _audioHandler!.stop();
        final mediaItem = MediaItem(
          id: sermon.id,
          title: sermon.title,
          artist: sermon.speaker ?? 'TCGC',
          album: sermon.categoryName.isNotEmpty ? sermon.categoryName : 'Sermons',
          artUri: sermon.imageUrl != null ? Uri.parse(sermon.imageUrl!) : null,
        );
        await _audioHandler!.setAudioSource(audioUrl, mediaItem);
        await _audioHandler!.play();
      } else if (_fallbackPlayer != null) {
        await _fallbackPlayer!.stop();
        await _fallbackPlayer!.setAudioSource(AudioSource.uri(Uri.parse(audioUrl)));
        await _fallbackPlayer!.play();
      }
    } catch (e, stackTrace) {
      _isLoading = false;
      _errorMessage = 'Failed to load audio: $e';
      debugPrint('Audio error: $e');
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
    if (!_audioServiceInitialized) {
      await initAudioService();
      _setupListeners();
    }

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
      if (_useAudioService && _audioHandler != null) {
        await _audioHandler!.stop();
        final mediaItem = MediaItem(
          id: sermon.id,
          title: sermon.title,
          artist: sermon.speaker ?? 'TCGC',
          album: sermon.categoryName.isNotEmpty ? sermon.categoryName : 'Sermons',
          artUri: sermon.imageUrl != null ? Uri.parse(sermon.imageUrl!) : null,
        );
        await _audioHandler!.setAudioSourceWithPosition(audioUrl, mediaItem, startPosition);
        await _audioHandler!.play();
      } else if (_fallbackPlayer != null) {
        await _fallbackPlayer!.stop();
        await _fallbackPlayer!.setAudioSource(AudioSource.uri(Uri.parse(audioUrl)), initialPosition: startPosition);
        await _fallbackPlayer!.play();
      }
    } catch (e, stackTrace) {
      _isLoading = false;
      _errorMessage = 'Failed to load audio: $e';
      debugPrint('Audio error: $e');
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveCurrentPosition();
    _fallbackPlayer?.dispose();
    super.dispose();
  }
}
