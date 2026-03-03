import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../domain/entities/sermon.dart';
import '../../domain/entities/event.dart';
import 'local_database_service.dart';
import 'api_service.dart';
import '../../core/constants/api_constants.dart';

class ContentCacheService {
  static final ContentCacheService _instance = ContentCacheService._internal();
  factory ContentCacheService() => _instance;
  ContentCacheService._internal();

  final LocalDatabaseService _db = LocalDatabaseService();
  final ApiService _api = ApiService();
  
  Directory? _audioCacheDir;
  bool _initialized = false;
  
  // 3 minutes in bytes (assuming ~128kbps audio = 16KB/sec * 180 sec = ~2.88MB)
  static const int _threeMinutesBytes = 3 * 1024 * 1024; // ~3MB for 3 min
  
  final Map<String, Completer<void>> _downloadCompleters = {};
  final Map<String, double> _downloadProgress = {};

  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _audioCacheDir = Directory('${appDir.path}/audio_3min_cache');
      if (!await _audioCacheDir!.exists()) {
        await _audioCacheDir!.create(recursive: true);
      }
      
      _initialized = true;
      debugPrint('ContentCacheService initialized');
      
      // Disabled to prevent ANR
      // _resumeIncompleteDownloads();
    } catch (e) {
      debugPrint('ContentCacheService init error: $e');
    }
  }

  // Get categories with cache-first strategy
  Future<List<MessageCategory>> getCategories({bool forceRefresh = false}) async {
    await initialize();
    
    final cachedCategories = await _db.getCachedCategories();
    final needsSync = await _db.needsSync('categories');
    
    if (cachedCategories.isNotEmpty && !forceRefresh && !needsSync) {
      debugPrint('Returning ${cachedCategories.length} cached categories');
      _syncCategoriesInBackground();
      return cachedCategories;
    }
    
    try {
      final hasConnection = await _checkConnectivity();
      if (!hasConnection) {
        debugPrint('No connection, returning cached categories');
        return cachedCategories;
      }
      
      final response = await _api.get(ApiConstants.messageCategories);
      if (response.isSuccess) {
        final decoded = response.data;
        final List<dynamic> data = decoded is List ? decoded : (decoded['results'] ?? decoded);
        final categories = data.map((json) => MessageCategory.fromJson(json)).toList();
        
        // Cache in background to not block UI
        Future.microtask(() async {
          await _db.cacheCategories(categories);
          await _db.updateSyncMetadata('categories');
        });
        
        debugPrint('Fetched and cached ${categories.length} categories');
        return categories;
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
    
    return cachedCategories;
  }

  // Get sermons with cache-first strategy
  Future<List<Sermon>> getSermons({bool forceRefresh = false}) async {
    await initialize();
    
    // Check if we have cached data
    final cachedSermons = await _db.getCachedSermons();
    final needsSync = await _db.needsSync('sermons');
    
    if (cachedSermons.isNotEmpty && !forceRefresh && !needsSync) {
      debugPrint('Returning ${cachedSermons.length} cached sermons');
      // Sync in background if needed
      _syncSermonsInBackground();
      return cachedSermons;
    }
    
    // Try to fetch from server
    try {
      final hasConnection = await _checkConnectivity();
      if (!hasConnection) {
        debugPrint('No connection, returning cached sermons');
        return cachedSermons;
      }
      
      final response = await _api.get(ApiConstants.messages);
      if (response.isSuccess) {
        final data = response.data;
        final List<dynamic> results = data['results'] ?? data;
        final sermons = results.map((json) => Sermon.fromJson(json)).toList();
        
        // Cache in background to not block UI
        Future.microtask(() async {
          await _db.cacheSermons(sermons);
          await _db.updateSyncMetadata('sermons');
        });
        
        debugPrint('Fetched and cached ${sermons.length} sermons');
        return sermons;
      }
    } catch (e) {
      debugPrint('Error fetching sermons: $e');
    }
    
    return cachedSermons;
  }

  // Get recommended sermons with cache-first strategy
  Future<List<Sermon>> getRecommendedSermons({bool forceRefresh = false}) async {
    await initialize();
    
    final cachedRecommended = await _db.getCachedRecommendedSermons();
    final needsSync = await _db.needsSync('recommended_sermons');
    
    if (cachedRecommended.isNotEmpty && !forceRefresh && !needsSync) {
      return cachedRecommended;
    }
    
    try {
      final hasConnection = await _checkConnectivity();
      if (!hasConnection) return cachedRecommended;
      
      final response = await _api.get('${ApiConstants.messages}recommended/');
      if (response.isSuccess) {
        final List<dynamic> data = response.dataList;
        final sermons = data.map((json) => Sermon.fromJson(json)).toList();
        
        // Mark as recommended and cache in background
        Future.microtask(() async {
          for (final sermon in sermons) {
            final recommended = Sermon(
              id: sermon.id,
              title: sermon.title,
              description: sermon.description,
              speaker: sermon.speaker,
              imageUrl: sermon.imageUrl,
              audioUrl: sermon.audioUrl,
              videoUrl: sermon.videoUrl,
              transcript: sermon.transcript,
              category: sermon.category,
              categoryName: sermon.categoryName,
              date: sermon.date,
              duration: sermon.duration,
              isRecommended: true,
            );
            await _db.cacheSermons([recommended]);
          }
          await _db.updateSyncMetadata('recommended_sermons');
        });
        return sermons;
      }
    } catch (e) {
      debugPrint('Error fetching recommended: $e');
    }
    
    return cachedRecommended;
  }

  // Get events with cache-first strategy
  Future<List<Event>> getEvents({bool forceRefresh = false}) async {
    await initialize();
    
    final cachedEvents = await _db.getCachedEvents();
    final needsSync = await _db.needsSync('events');
    
    if (cachedEvents.isNotEmpty && !forceRefresh && !needsSync) {
      debugPrint('Returning ${cachedEvents.length} cached events');
      _syncEventsInBackground();
      return cachedEvents;
    }
    
    try {
      final hasConnection = await _checkConnectivity();
      if (!hasConnection) return cachedEvents;
      
      final response = await _api.get(ApiConstants.events);
      if (response.isSuccess) {
        final data = response.data;
        final List<dynamic> results = data['results'] ?? data;
        final events = results.map((json) => Event.fromJson(json)).toList();
        
        // Cache in background to not block UI
        Future.microtask(() async {
          await _db.cacheEvents(events);
          await _db.updateSyncMetadata('events');
        });
        
        debugPrint('Fetched and cached ${events.length} events');
        return events;
      }
    } catch (e) {
      debugPrint('Error fetching events: $e');
    }
    
    return cachedEvents;
  }

  // Pre-cache 3 minutes of audio for a sermon
  // DISABLED: Causing ANR issues - audio will stream on demand
  Future<void> preCacheAudio(Sermon sermon) async {
    // Disabled to prevent ANR
    return;
  }

  Future<void> _downloadAudioPartial(String sermonId, String audioUrl, {int startByte = 0}) async {
    final filePath = '${_audioCacheDir!.path}/${_sanitizeFileName(sermonId)}.cache';
    final file = File(filePath);
    
    try {
      // Get total file size with HEAD request
      int? totalBytes;
      try {
        final headResponse = await http.head(Uri.parse(audioUrl))
            .timeout(const Duration(seconds: 10));
        totalBytes = int.tryParse(headResponse.headers['content-length'] ?? '');
      } catch (_) {}
      
      // Calculate how much we need to download
      final targetBytes = _threeMinutesBytes;
      final endByte = startByte + targetBytes - 1;
      
      // Create range request
      final request = http.Request('GET', Uri.parse(audioUrl));
      request.headers['Range'] = 'bytes=$startByte-$endByte';
      
      final streamedResponse = await request.send()
          .timeout(const Duration(minutes: 2));
      
      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 206) {
        final sink = file.openWrite(mode: startByte > 0 ? FileMode.append : FileMode.write);
        int downloadedBytes = startByte;
        
        await for (final chunk in streamedResponse.stream) {
          sink.add(chunk);
          downloadedBytes += chunk.length;
          _downloadProgress[sermonId] = downloadedBytes / targetBytes;
          
          // Update progress in database periodically
          if (downloadedBytes % (512 * 1024) == 0 || downloadedBytes >= targetBytes) {
            await _db.updateAudioCacheProgress(
              sermonId: sermonId,
              cachedBytes: downloadedBytes,
              cachedDurationSeconds: (downloadedBytes / totalBytes! * 180).round(),
              isComplete: downloadedBytes >= targetBytes,
            );
          }
        }
        
        await sink.close();
        
        // Save final metadata
        await _db.saveAudioCacheMetadata(
          sermonId: sermonId,
          audioUrl: audioUrl,
          filePath: filePath,
          totalBytes: totalBytes,
          cachedBytes: downloadedBytes,
          cachedDurationSeconds: 180,
          isComplete: true,
        );
        
        debugPrint('Cached ${downloadedBytes ~/ 1024}KB audio for sermon: $sermonId');
      }
    } catch (e) {
      debugPrint('Download error for $sermonId: $e');
      
      // Save progress for resume
      if (await file.exists()) {
        final currentSize = await file.length();
        await _db.saveAudioCacheMetadata(
          sermonId: sermonId,
          audioUrl: audioUrl,
          filePath: filePath,
          cachedBytes: currentSize.toInt(),
          isComplete: false,
        );
      }
      rethrow;
    }
  }

  // Get cached audio file path
  Future<String?> getCachedAudioPath(String sermonId) async {
    final metadata = await _db.getAudioCacheMetadata(sermonId);
    if (metadata == null) return null;
    
    final filePath = metadata['file_path'] as String?;
    if (filePath == null) return null;
    
    final file = File(filePath);
    if (await file.exists()) return filePath;
    
    return null;
  }

  // Check if sermon has cached audio
  Future<bool> hasAudioCache(String sermonId) async {
    final path = await getCachedAudioPath(sermonId);
    return path != null;
  }

  // Get download progress for a sermon
  double getDownloadProgress(String sermonId) {
    return _downloadProgress[sermonId] ?? 0.0;
  }

  // Check if currently downloading
  bool isDownloading(String sermonId) {
    return _downloadCompleters.containsKey(sermonId);
  }

  // Throttle background syncs to prevent multiple simultaneous operations
  bool _isSyncingSermons = false;
  bool _isSyncingEvents = false;
  bool _isSyncingCategories = false;

  // Background sync methods - with throttling and delayed execution
  void _syncSermonsInBackground() {
    if (_isSyncingSermons) return;
    _isSyncingSermons = true;
    
    // Delay background sync to let UI settle first
    Future.delayed(const Duration(seconds: 3), () async {
      try {
        final hasConnection = await _checkConnectivity();
        if (!hasConnection) {
          _isSyncingSermons = false;
          return;
        }
        
        final response = await _api.get(ApiConstants.messages);
        if (response.isSuccess) {
          final data = response.data;
          final List<dynamic> results = data['results'] ?? data;
          final sermons = results.map((json) => Sermon.fromJson(json)).toList();
          
          await _db.cacheSermons(sermons);
          await _db.updateSyncMetadata('sermons');
        }
      } catch (e) {
        debugPrint('Background sync error: $e');
      } finally {
        _isSyncingSermons = false;
      }
    });
  }

  void _syncEventsInBackground() {
    if (_isSyncingEvents) return;
    _isSyncingEvents = true;
    
    Future.delayed(const Duration(seconds: 4), () async {
      try {
        final hasConnection = await _checkConnectivity();
        if (!hasConnection) {
          _isSyncingEvents = false;
          return;
        }
        
        final response = await _api.get(ApiConstants.events);
        if (response.isSuccess) {
          final data = response.data;
          final List<dynamic> results = data['results'] ?? data;
          final events = results.map((json) => Event.fromJson(json)).toList();
          
          await _db.cacheEvents(events);
          await _db.updateSyncMetadata('events');
        }
      } catch (e) {
        debugPrint('Background events sync error: $e');
      } finally {
        _isSyncingEvents = false;
      }
    });
  }

  void _syncCategoriesInBackground() {
    if (_isSyncingCategories) return;
    _isSyncingCategories = true;
    
    Future.delayed(const Duration(seconds: 5), () async {
      try {
        final hasConnection = await _checkConnectivity();
        if (!hasConnection) {
          _isSyncingCategories = false;
          return;
        }
        
        final response = await _api.get(ApiConstants.messageCategories);
        if (response.isSuccess) {
          final decoded = response.data;
          final List<dynamic> data = decoded is List ? decoded : (decoded['results'] ?? decoded);
          final categories = data.map((json) => MessageCategory.fromJson(json)).toList();
          
          await _db.cacheCategories(categories);
          await _db.updateSyncMetadata('categories');
        }
      } catch (e) {
        debugPrint('Background categories sync error: $e');
      } finally {
        _isSyncingCategories = false;
      }
    });
  }

  void _preCacheAudioInBackground(List<Sermon> sermons) {
    Future.microtask(() async {
      for (final sermon in sermons) {
        try {
          await preCacheAudio(sermon);
          // Small delay between downloads to not overwhelm
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          debugPrint('Background audio cache error: $e');
        }
      }
    });
  }

  Future<void> _resumeIncompleteDownloads() async {
    try {
      final incomplete = await _db.getIncompleteAudioCaches();
      
      for (final cache in incomplete) {
        final sermonId = cache['sermon_id'] as String;
        final audioUrl = cache['audio_url'] as String;
        final cachedBytes = cache['cached_bytes'] as int? ?? 0;
        
        if (cachedBytes > 0 && cachedBytes < _threeMinutesBytes) {
          debugPrint('Resuming download for $sermonId from byte $cachedBytes');
          
          _downloadCompleters[sermonId] = Completer<void>();
          
          try {
            await _downloadAudioPartial(sermonId, audioUrl, startByte: cachedBytes);
          } catch (e) {
            debugPrint('Resume download failed for $sermonId: $e');
          } finally {
            _downloadCompleters[sermonId]?.complete();
            _downloadCompleters.remove(sermonId);
          }
        }
      }
    } catch (e) {
      debugPrint('Error resuming downloads: $e');
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult.isNotEmpty && 
             !connectivityResult.contains(ConnectivityResult.none);
    } catch (_) {
      return true; // Assume connected if check fails
    }
  }

  String _sanitizeFileName(String id) {
    return id.replaceAll(RegExp(r'[^\w\-]'), '_');
  }

  // Cleanup methods
  Future<void> clearAudioCache() async {
    if (_audioCacheDir != null && await _audioCacheDir!.exists()) {
      await for (var entity in _audioCacheDir!.list()) {
        if (entity is File) {
          await entity.delete();
        }
      }
    }
    debugPrint('Audio cache cleared');
  }

  Future<int> getAudioCacheSize() async {
    int totalSize = 0;
    if (_audioCacheDir != null && await _audioCacheDir!.exists()) {
      await for (var entity in _audioCacheDir!.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    }
    return totalSize;
  }
}
