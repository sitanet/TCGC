import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
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
  
  // Audio caching
  Directory? _cacheDir;

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
  
  String _getFileExtension(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.path.isNotEmpty) {
      final path = uri.path.toLowerCase();
      if (path.endsWith('.ogg')) return '.ogg';
      if (path.endsWith('.mp3')) return '.mp3';
      if (path.endsWith('.wav')) return '.wav';
      if (path.endsWith('.m4a')) return '.m4a';
      if (path.endsWith('.aac')) return '.aac';
    }
    return '.audio';
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
    
    debugPrint('=== AUDIO DEBUG ===');
    debugPrint('Audio URL: $audioUrl');
    debugPrint('Sermon ID: ${sermon.id}');
    debugPrint('Using fallback: $_usingFallback');

    try {
      if (_usingFallback && _fallbackPlayer != null) {
        // Use caching for faster subsequent plays
        if (_cacheDir != null) {
          final fileName = _sanitizeFileName(sermon.id);
          final ext = _getFileExtension(audioUrl);
          final cacheFile = File('${_cacheDir!.path}/$fileName$ext');
          
          if (await cacheFile.exists()) {
            debugPrint('Playing from cache: ${cacheFile.path}');
            await _fallbackPlayer!.setFilePath(cacheFile.path);
          } else {
            debugPrint('Streaming and caching: $audioUrl');
            final source = LockCachingAudioSource(
              Uri.parse(audioUrl),
              cacheFile: cacheFile,
            );
            await _fallbackPlayer!.setAudioSource(source);
          }
        } else {
          await _fallbackPlayer!.setUrl(audioUrl);
        }
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
  Directory? _cacheDir;

  AudioPlayerHandler() {
    _initCacheDir();
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    
    _player.durationStream.listen((duration) {
      final item = mediaItem.value;
      if (item != null && duration != null) {
        mediaItem.add(item.copyWith(duration: duration));
      }
    });
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

  String _getFileExtension(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.path.isNotEmpty) {
      final path = uri.path.toLowerCase();
      if (path.endsWith('.ogg')) return '.ogg';
      if (path.endsWith('.mp3')) return '.mp3';
      if (path.endsWith('.wav')) return '.wav';
      if (path.endsWith('.m4a')) return '.m4a';
      if (path.endsWith('.aac')) return '.aac';
    }
    return '.audio';
  }
  
  String _sanitizeFileName(String id) {
    return id.replaceAll(RegExp(r'[^\w\-]'), '_');
  }

  @override
  Future<void> playMediaItem(MediaItem item) async {
    mediaItem.add(item);
    final url = item.extras?['url'] as String?;
    if (url != null) {
      try {
        if (_cacheDir != null) {
          final fileName = _sanitizeFileName(item.id);
          final ext = _getFileExtension(url);
          final cacheFile = File('${_cacheDir!.path}/$fileName$ext');
          
          if (await cacheFile.exists()) {
            debugPrint('Playing from cache: ${cacheFile.path}');
            await _player.setFilePath(cacheFile.path);
          } else {
            debugPrint('Streaming and caching: $url');
            final source = LockCachingAudioSource(
              Uri.parse(url),
              cacheFile: cacheFile,
            );
            await _player.setAudioSource(source);
          }
        } else {
          await _player.setUrl(url);
        }
        await _player.play();
      } catch (e) {
        debugPrint('Error setting audio source: $e');
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
