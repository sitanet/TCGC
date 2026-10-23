import 'dart:async' show Future, StreamSubscription, TimeoutException, Timer;
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/sermon.dart';
import '../../data/services/audio_cache_service.dart';
import '../../data/services/playback_position_service.dart';
import '../../data/services/download_service.dart';
import '../../data/services/played_audio_service.dart';
import '../../data/services/app_rating_service.dart';
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
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.tcgc.tcgc.audio',
        androidNotificationChannelName: 'TCGC Audio',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: false,
        androidNotificationIcon: 'mipmap/ic_launcher',
        fastForwardInterval: const Duration(seconds: 10),
        rewindInterval: const Duration(seconds: 10),
        androidShowNotificationBadge: false, // Disabled to reduce memory on low-end devices
        notificationColor: const Color(0xFFD4A867),
      ),
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('AudioService init timed out - using fallback');
        throw TimeoutException('AudioService init timeout');
      },
    );
    _useAudioService = true;
    debugPrint('AudioService initialized successfully');
  } catch (e) {
    debugPrint('AudioService init failed: $e');
    debugPrint('Using fallback audio player');
    try {
      _fallbackPlayer = AudioPlayer(
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
      _useAudioService = false;
    } catch (e2) {
      debugPrint('Fallback player init also failed: $e2');
    }
  }
}

class AudioPlayerProvider extends ChangeNotifier with WidgetsBindingObserver {
  Sermon? _currentSermon;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _errorMessage;
  double _playbackSpeed = 1.0;
  
  Directory? _cacheDir;
  List<Sermon> _queue = [];
  int _currentIndex = -1;
  
  final AudioCacheService _audioCacheService = AudioCacheService();
  final PlaybackPositionService _positionService = PlaybackPositionService();
  final DownloadService _downloadService = DownloadService();
  final PlayedAudioService _playedAudioService = PlayedAudioService();
  final AppRatingService _appRatingService = AppRatingService();
  
  bool _hasMarkedFirstSuccessfulPlay = false;
  
  // Stream subscriptions to properly cancel on dispose
  final List<StreamSubscription> _subscriptions = [];
  
  // Throttle position updates to reduce UI rebuilds (every 500ms instead of every frame)
  DateTime _lastPositionNotify = DateTime.now();
  static const _positionThrottleMs = 500;
  DateTime _lastPositionSave = DateTime.now();

  Sermon? get currentSermon => _currentSermon;
  Duration get duration => _duration;
  Duration get position => _position;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasAudio => _currentSermon != null;
  double get playbackSpeed => _playbackSpeed;
  
  static const List<double> availableSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  
  List<Sermon> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get hasNext => _currentIndex < _queue.length - 1;
  bool get hasPrevious => _currentIndex > 0;

  Timer? _sleepTimer;
  DateTime? _sleepTimerEndTime;

  bool get isSleepTimerActive => _sleepTimer != null && _sleepTimer!.isActive;
  Duration? get sleepTimerRemaining {
    if (_sleepTimerEndTime == null) return null;
    final diff = _sleepTimerEndTime!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndTime = null;

    if (duration != null && duration > Duration.zero) {
      _sleepTimerEndTime = DateTime.now().add(duration);
      _sleepTimer = Timer(duration, () {
        pause();
        _sleepTimer = null;
        _sleepTimerEndTime = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void cancelSleepTimer() {
    setSleepTimer(null);
  }

  AudioPlayerProvider() {
    WidgetsBinding.instance.addObserver(this);
    // Initialize in background with error handling
    Future.microtask(() async {
      try {
        await _initCacheDir();
      } catch (e) {
        debugPrint('Cache dir init error: $e');
      }
      try {
        await _initPositionService();
      } catch (e) {
        debugPrint('Position service init error: $e');
      }
      try {
        await _playedAudioService.initialize();
      } catch (e) {
        debugPrint('Played audio service init error: $e');
      }
      try {
        await _appRatingService.initialize();
      } catch (e) {
        debugPrint('App rating service init error: $e');
      }
      try {
        _setupListeners();
      } catch (e) {
        debugPrint('Listeners setup error: $e');
      }
    });
  }
  
  bool isAudioPlayed(String audioId) => _playedAudioService.isPlayed(audioId);
  
  bool get shouldShowRatingPopup => !_appRatingService.hasShownRatingPopup && _hasMarkedFirstSuccessfulPlay;
  
  Future<void> showRatingDialogIfNeeded(BuildContext context) async {
    if (await _appRatingService.shouldShowRating()) {
      await _appRatingService.showRatingDialog(context);
    }
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
    
    if (_useAudioService && _audioHandler != null) {
      _listenersSetup = true;
      _setupAudioServiceListeners();
      debugPrint('[AUDIO] AudioService listeners attached successfully');
    } else if (_fallbackPlayer != null) {
      _listenersSetup = true;
      _setupFallbackListeners();
      debugPrint('[AUDIO] Fallback player listeners attached successfully');
    }
  }
  
  void _setupAudioServiceListeners() {
    _subscriptions.add(
      _audioHandler!.playerStateStream.listen((state) {
        final wasPlaying = _isPlaying;
        final wasLoading = _isLoading;
        
        _isPlaying = state.playing;
        _isLoading = (state.processingState == ProcessingState.loading ||
                     state.processingState == ProcessingState.buffering) && !_isPlaying;
        
        if (state.processingState == ProcessingState.ready ||
            state.processingState == ProcessingState.idle ||
            _isPlaying) {
          _isLoading = false;
        }
        
        // Mark first successful play for rating prompt
        if (state.playing && state.processingState == ProcessingState.ready) {
          if (_errorMessage != null) {
            _errorMessage = null;
            notifyListeners();
          }
        }
        if (state.playing && state.processingState == ProcessingState.ready && !_hasMarkedFirstSuccessfulPlay) {
          _hasMarkedFirstSuccessfulPlay = true;
          _appRatingService.incrementPlayCount();
        }
        
        if (state.processingState == ProcessingState.completed) {
          _isLoading = false;
          if (hasNext) skipToNext();
        }
        // Only notify if state actually changed
        if (wasPlaying != _isPlaying || wasLoading != _isLoading) {
          notifyListeners();
        }
      }, onError: (error) {
        debugPrint('Player state stream error: $error');
        _isLoading = false;
        _errorMessage = 'Playback error: $error';
        notifyListeners();
      }),
    );
    
    _subscriptions.add(
      _audioHandler!.positionStream.listen((pos) {
        _position = pos;
        // Throttle position updates to reduce UI rebuilds
        final now = DateTime.now();
        if (now.difference(_lastPositionNotify).inMilliseconds >= _positionThrottleMs) {
          _lastPositionNotify = now;
          notifyListeners();
        }
        if (_isPlaying && _currentSermon != null && _duration.inMilliseconds > 0 && _position.inMilliseconds > 5000) {
          if (now.difference(_lastPositionSave).inSeconds >= 5) {
            _lastPositionSave = now;
            _positionService.savePosition(_currentSermon!.id, _position, _duration);
          }
        }
      }, onError: (error) {
        debugPrint('Position stream error: $error');
      }),
    );
    
    _subscriptions.add(
      _audioHandler!.durationStream.listen((dur) {
        final newDuration = dur ?? Duration.zero;
        if (_duration != newDuration) {
          _duration = newDuration;
          notifyListeners();
        }
      }, onError: (error) {
        debugPrint('Duration stream error: $error');
      }),
    );
  }
  
  void _setupFallbackListeners() {
    _subscriptions.add(
      _fallbackPlayer!.playerStateStream.listen((state) {
        final wasPlaying = _isPlaying;
        final wasLoading = _isLoading;
        
        _isPlaying = state.playing;
        _isLoading = (state.processingState == ProcessingState.loading ||
                     state.processingState == ProcessingState.buffering) && !_isPlaying;
        
        if (state.processingState == ProcessingState.ready ||
            state.processingState == ProcessingState.idle ||
            _isPlaying) {
          _isLoading = false;
        }
        
        // Mark first successful play for rating prompt
        if (state.playing && state.processingState == ProcessingState.ready && !_hasMarkedFirstSuccessfulPlay) {
          _hasMarkedFirstSuccessfulPlay = true;
          _appRatingService.incrementPlayCount();
        }
        
        if (state.processingState == ProcessingState.completed) {
          _isLoading = false;
          if (hasNext) skipToNext();
        }
        // Only notify if state actually changed
        if (wasPlaying != _isPlaying || wasLoading != _isLoading) {
          notifyListeners();
        }
      }, onError: (error) {
        debugPrint('Fallback player state stream error: $error');
        _isLoading = false;
        _errorMessage = 'Playback error: $error';
        notifyListeners();
      }),
    );
    
    _subscriptions.add(
      _fallbackPlayer!.positionStream.listen((pos) {
        _position = pos;
        // Throttle position updates to reduce UI rebuilds
        final now = DateTime.now();
        if (now.difference(_lastPositionNotify).inMilliseconds >= _positionThrottleMs) {
          _lastPositionNotify = now;
          notifyListeners();
        }
        if (_isPlaying && _currentSermon != null && _duration.inMilliseconds > 0 && _position.inMilliseconds > 5000) {
          if (now.difference(_lastPositionSave).inSeconds >= 5) {
            _lastPositionSave = now;
            _positionService.savePosition(_currentSermon!.id, _position, _duration);
          }
        }
      }, onError: (error) {
        debugPrint('Fallback position stream error: $error');
      }),
    );
    
    _subscriptions.add(
      _fallbackPlayer!.durationStream.listen((dur) {
        final newDuration = dur ?? Duration.zero;
        if (_duration != newDuration) {
          _duration = newDuration;
          notifyListeners();
        }
      }, onError: (error) {
        debugPrint('Fallback duration stream error: $error');
      }),
    );
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
      final tempDir = await getTemporaryDirectory();
      _cacheDir = Directory('${tempDir.path}/audio_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }

      // Clean up legacy cache directory from Documents if it exists
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final legacyCache = Directory('${appDir.path}/audio_cache');
        if (await legacyCache.exists()) {
          await legacyCache.delete(recursive: true);
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Failed to create cache directory: $e');
    }
  }
  
  String _sanitizeFileName(String id) => id.replaceAll(RegExp(r'[^\w\-]'), '_');

  Future<void> playSermon(Sermon sermon) async {
    // Toggle play/pause if same sermon AND it is actually loaded
    if (_currentSermon?.id == sermon.id) {
      if (_isLoading) return; // already loading - don't interrupt
      final state = _useAudioService && _audioHandler != null
          ? _audioHandler!.processingState
          : _fallbackPlayer?.processingState;
      if (_errorMessage == null &&
          state != null &&
          state != ProcessingState.idle) {
        if (_isPlaying) {
          await pause();
        } else {
          await play();
        }
        return;
      }
      // Source not loaded or previous attempt failed: fall through and reload
      _currentSermon = null;
    }

    // Mark audio as played (removes "NEW" badge)
    _playedAudioService.markAsPlayed(sermon.id);

    // Update UI immediately - no loading state for pre-buffered content
    _errorMessage = null;
    _currentSermon = sermon;
    _position = Duration.zero;
    
    final audioUrl = sermon.audioUrl;
    debugPrint('Playing sermon: ${sermon.title}');
    debugPrint('Audio URL from sermon: $audioUrl');
    
    if (audioUrl == null || audioUrl.isEmpty) {
      _errorMessage = 'No audio URL available for this sermon. Please pull to refresh the list.';
      debugPrint('ERROR: Audio URL is null or empty for sermon ${sermon.id}');
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    // Initialize audio service if needed (should already be done)
    if (!_audioServiceInitialized) {
      await initAudioService();
    }
    _setupListeners();

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
        // Stop previous audio cleanly
        try {
          await _audioHandler!.pause();
        } catch (e) {
          debugPrint('Error stopping previous audio: $e');
        }
        
        if (downloadedPath != null) {
          debugPrint('Playing from local file: $downloadedPath');
          await _audioHandler!.setAudioSource('file://$downloadedPath', mediaItem);
          await _audioHandler!.play();
        } else {
          // Stream from URL - await setAudioSource so ExoPlayer initializes the media pipeline cleanly
          debugPrint('Streaming from URL: $fixedAudioUrl');
          try {
            await _audioHandler!.setAudioSource(fixedAudioUrl, mediaItem);
            await _audioHandler!.play();
          } catch (e) {
            debugPrint('Error setting audio source (attempt 1): $e');
            try {
              await Future.delayed(const Duration(milliseconds: 600));
              if (_currentSermon?.id != sermon.id) return;
              await _audioHandler!.stop();
              await _audioHandler!.setAudioSource(fixedAudioUrl, mediaItem);
              await _audioHandler!.play();
            } catch (e2) {
              debugPrint('Error setting audio source (attempt 2): $e2');
              _isLoading = false;
              _errorMessage = 'Unable to load audio. Please check your internet connection.';
              notifyListeners();
              return;
            }
          }
        }
      } else if (_fallbackPlayer != null) {
        try {
          await _fallbackPlayer!.stop();
        } catch (e) {
          debugPrint('Error stopping fallback player: $e');
        }
        
        if (downloadedPath != null) {
          debugPrint('Playing from local file (fallback)');
          await _fallbackPlayer!.setAudioSource(AudioSource.uri(Uri.parse('file://$downloadedPath')));
          await _fallbackPlayer!.play();
        } else {
          debugPrint('Streaming from URL (fallback): $fixedAudioUrl');
          try {
            await _fallbackPlayer!.setAudioSource(AudioSource.uri(Uri.parse(fixedAudioUrl)));
            await _fallbackPlayer!.play();
          } catch (e) {
            debugPrint('Error setting audio source (fallback): $e');
            _isLoading = false;
            _errorMessage = 'Unable to load audio. Please check your internet connection.';
            notifyListeners();
            return;
          }
        }
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
    _setupListeners();
    try {
      if (_useAudioService && _audioHandler != null) {
        // Check if the audio source is still loaded
        final processingState = _audioHandler!.processingState;
        if (processingState == ProcessingState.idle && _currentSermon != null) {
          // Audio source was released, need to reload
          debugPrint('Audio source released, reloading...');
          await playSermonFromPosition(_currentSermon!, _position);
          return;
        }
        await _audioHandler!.play();
      } else if (_fallbackPlayer != null) {
        // Check if the audio source is still loaded
        final processingState = _fallbackPlayer!.processingState;
        if (processingState == ProcessingState.idle && _currentSermon != null) {
          // Audio source was released, need to reload
          debugPrint('Audio source released (fallback), reloading...');
          await playSermonFromPosition(_currentSermon!, _position);
          return;
        }
        await _fallbackPlayer!.play();
      }
    } catch (e) {
      debugPrint('Error in play(): $e');
      // Try to reload the sermon if play fails
      if (_currentSermon != null) {
        debugPrint('Attempting to reload sermon after play error');
        await playSermonFromPosition(_currentSermon!, _position);
      }
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

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    if (_useAudioService && _audioHandler != null) {
      await _audioHandler!.setSpeed(speed);
    } else if (_fallbackPlayer != null) {
      await _fallbackPlayer!.setSpeed(speed);
    }
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
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
    }
    _setupListeners();

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
        try {
          await _audioHandler!.pause();
        } catch (e) {
          debugPrint('Error stopping previous audio: $e');
        }
        
        if (downloadedPath != null) {
          await _audioHandler!.setAudioSourceWithPosition('file://$downloadedPath', mediaItem, startPosition);
          await _audioHandler!.play();
        } else {
          // Stream from URL with position
          try {
            await _audioHandler!.setAudioSourceWithPosition(fixedAudioUrl, mediaItem, startPosition);
            await _audioHandler!.play();
          } catch (e) {
            debugPrint('Error setting audio source: $e');
            _isLoading = false;
            _errorMessage = 'Unable to load audio. Check your connection.';
            notifyListeners();
            return;
          }
        }
      } else if (_fallbackPlayer != null) {
        try {
          await _fallbackPlayer!.stop();
        } catch (e) {
          debugPrint('Error stopping fallback player: $e');
        }
        
        if (downloadedPath != null) {
          await _fallbackPlayer!.setAudioSource(AudioSource.uri(Uri.parse('file://$downloadedPath')), initialPosition: startPosition);
          await _fallbackPlayer!.play();
        } else {
          // Stream from URL with position
          try {
            await _fallbackPlayer!.setAudioSource(AudioSource.uri(Uri.parse(fixedAudioUrl)), initialPosition: startPosition);
            await _fallbackPlayer!.play();
          } catch (e) {
            debugPrint('Error setting audio source: $e');
            _isLoading = false;
            _errorMessage = 'Unable to load audio. Check your connection.';
            notifyListeners();
            return;
          }
        }
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
    // Cancel all stream subscriptions to prevent memory leaks
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _sleepTimer?.cancel();
    _fallbackPlayer?.dispose();
    super.dispose();
  }
}
