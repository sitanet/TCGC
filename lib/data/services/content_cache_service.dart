import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../domain/entities/sermon.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/teens_category.dart';
import '../../domain/entities/teens_content.dart';
import 'local_database_service.dart';
import 'api_service.dart';
import 'audio_cache_service.dart';
import '../../core/constants/api_constants.dart';

class ContentCacheService {
  static final ContentCacheService _instance = ContentCacheService._internal();
  factory ContentCacheService() => _instance;
  ContentCacheService._internal();

  final LocalDatabaseService _db = LocalDatabaseService();
  final ApiService _api = ApiService();
  
  Directory? _audioCacheDir;
  bool _initialized = false;
  
  final Map<String, double> _downloadProgress = {};
  
  // In-memory cache for instant access (avoids database queries)
  List<MessageCategory>? _memoryCachedCategories;
  List<Sermon>? _memoryCachedSermons;
  List<Sermon>? _memoryCachedRecommended;

  Future<void> initialize() async {
    if (_initialized) return;
    
    // Skip file-based caching on web platform
    if (kIsWeb) {
      _initialized = true;
      debugPrint('ContentCacheService initialized (web mode - no file caching)');
      return;
    }
    
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
  // Only fetches from server on first install (no cache) or manual refresh
  Future<List<MessageCategory>> getCategories({bool forceRefresh = false}) async {
    // Return from memory cache immediately if available (instant)
    if (_memoryCachedCategories != null && _memoryCachedCategories!.isNotEmpty && !forceRefresh) {
      debugPrint('Returning ${_memoryCachedCategories!.length} categories from memory cache (instant)');
      return _memoryCachedCategories!;
    }
    
    await initialize();
    
    final cachedCategories = await _db.getCachedCategories();
    
    // Return cached data if available and not forcing refresh
    if (cachedCategories.isNotEmpty && !forceRefresh) {
      _memoryCachedCategories = cachedCategories; // Store in memory for next time
      debugPrint('Returning ${cachedCategories.length} cached categories (offline-first)');
      return cachedCategories;
    }
    
    // Only fetch from server on first install or manual refresh
    try {
      final hasConnection = await _checkConnectivity();
      if (!hasConnection) {
        debugPrint('No connection, returning cached categories');
        return cachedCategories;
      }
      
      final allResults = await _api.getAllPages(ApiConstants.messageCategories);
      List<MessageCategory> categories = [];
      if (allResults.isNotEmpty) {
        categories = allResults.map((json) => MessageCategory.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        final response = await _api.get(ApiConstants.messageCategories);
        if (response.isSuccess) {
          final decoded = response.data;
          final List<dynamic> data = decoded is List ? decoded : (decoded['results'] ?? decoded);
          categories = data.map((json) => MessageCategory.fromJson(json as Map<String, dynamic>)).toList();
        }
      }

      if (categories.isNotEmpty) {
        // Merge with existing cached categories so existing categories are preserved
        final Set<String> seenIds = categories.map((c) => c.id.toString()).toSet();
        final List<MessageCategory> merged = List.from(categories);
        for (final item in cachedCategories) {
          if (!seenIds.contains(item.id.toString())) {
            seenIds.add(item.id.toString());
            merged.add(item);
          }
        }

        _memoryCachedCategories = merged; // Store in memory
        
        // Cache in background to not block UI
        Future.microtask(() async {
          await _db.cacheCategories(merged);
          await _db.updateSyncMetadata('categories');
        });
        
        debugPrint('Fetched and cached ${merged.length} categories (all pages)');
        return merged;
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
    
    return cachedCategories.isNotEmpty ? cachedCategories : (_memoryCachedCategories ?? []);
  }

  // Get sermons with cache-first strategy (fetches ALL pages)
  // Only fetches from server on first install (no cache) or manual refresh
  Future<List<Sermon>> getSermons({bool forceRefresh = false}) async {
    // Return from memory cache immediately if available (instant)
    if (_memoryCachedSermons != null && _memoryCachedSermons!.isNotEmpty && !forceRefresh) {
      debugPrint('Returning ${_memoryCachedSermons!.length} sermons from memory cache (instant)');
      return _memoryCachedSermons!;
    }
    
    await initialize();
    
    // Check if we have cached data
    final cachedSermons = await _db.getCachedSermons();
    
    // Return cached data if available and not forcing refresh
    if (cachedSermons.isNotEmpty && !forceRefresh) {
      _memoryCachedSermons = cachedSermons; // Store in memory for next time
      debugPrint('Returning ${cachedSermons.length} cached sermons (offline-first)');
      return cachedSermons;
    }
    
    // Only fetch from server on first install or manual refresh
    try {
      final hasConnection = await _checkConnectivity();
      if (!hasConnection) {
        debugPrint('No connection, returning cached sermons');
        return cachedSermons;
      }
      
      // Use getAllPages to fetch all paginated results
      final allResults = await _api.getAllPages(ApiConstants.messages);
      if (allResults.isNotEmpty) {
        final sermons = allResults.map((json) => Sermon.fromJson(json)).toList();
        
        _memoryCachedSermons = sermons; // Store in memory
        
        // Cache in background to not block UI
        Future.microtask(() async {
          await _db.cacheSermons(sermons);
          await _db.updateSyncMetadata('sermons');
        });
        
        debugPrint('Fetched and cached ${sermons.length} sermons (all pages)');
        return sermons;
      }
    } catch (e) {
      debugPrint('Error fetching sermons: $e');
    }
    
    return cachedSermons.isNotEmpty ? cachedSermons : (_memoryCachedSermons ?? []);
  }

  /// Clears all cached sermons and fetches fresh data from server
  Future<List<Sermon>> clearAndRefreshSermons() async {
    await initialize();
    await _db.clearSermons();
    // Also clear the AudioCacheService metadata to ensure audio_page gets fresh data
    final audioCacheService = AudioCacheService();
    await audioCacheService.clearMetadataCache();
    debugPrint('Cleared sermon cache, fetching fresh data...');
    return getSermons(forceRefresh: true);
  }

  // Get recommended sermons with cache-first strategy
  // Only fetches from server on first install (no cache) or manual refresh
  Future<List<Sermon>> getRecommendedSermons({bool forceRefresh = false}) async {
    // Return from memory cache immediately if available (instant)
    if (_memoryCachedRecommended != null && _memoryCachedRecommended!.isNotEmpty && !forceRefresh) {
      debugPrint('Returning ${_memoryCachedRecommended!.length} recommended from memory cache (instant)');
      return _memoryCachedRecommended!;
    }
    
    await initialize();
    
    final cachedRecommended = await _db.getCachedRecommendedSermons();
    
    // Return cached data if available and not forcing refresh
    if (cachedRecommended.isNotEmpty && !forceRefresh) {
      _memoryCachedRecommended = cachedRecommended; // Store in memory
      debugPrint('Returning ${cachedRecommended.length} cached recommended sermons (offline-first)');
      return cachedRecommended;
    }
    
    // Only fetch from server on first install or manual refresh
    try {
      final hasConnection = await _checkConnectivity();
      if (!hasConnection) return cachedRecommended;
      
      final response = await _api.get('${ApiConstants.messages}recommended/');
      if (response.isSuccess) {
        final List<dynamic> data = response.dataList;
        final sermons = data.map((json) => Sermon.fromJson(json)).toList();
        
        _memoryCachedRecommended = sermons; // Store in memory
        
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
  // Only fetches from server on first install (no cache) or manual refresh
  Future<List<Event>> getEvents({bool forceRefresh = false}) async {
    await initialize();
    
    final cachedEvents = await _db.getCachedEvents();
    
    // Return cached data if available and not forcing refresh
    if (cachedEvents.isNotEmpty && !forceRefresh) {
      debugPrint('Returning ${cachedEvents.length} cached events (offline-first)');
      return cachedEvents;
    }
    
    // Only fetch from server on first install or manual refresh
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

  // Check if currently downloading (audio pre-caching is disabled)
  bool isDownloading(String sermonId) {
    return false;
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

  // Teens categories with cache-first strategy
  // Teens categories with cache-first strategy
  // Only fetches from server on first install (no cache) or manual refresh
  Future<List<TeensCategory>> getTeensCategories({bool forceRefresh = false}) async {
    await initialize();
    
    final cachedCategories = await _db.getCachedTeensCategories();
    
    // Return cached data if available and not forcing refresh
    if (cachedCategories.isNotEmpty && !forceRefresh) {
      debugPrint('Returning ${cachedCategories.length} cached teens categories (offline-first)');
      return cachedCategories;
    }
    
    // Only fetch from server on first install or manual refresh
    try {
      final hasConnection = await _checkConnectivity();
      if (!hasConnection) {
        debugPrint('No connection, returning cached teens categories');
        return cachedCategories;
      }
      
      final response = await _api.get(ApiConstants.teensCategories);
      if (response.isSuccess) {
        final data = response.data;
        final List<dynamic> results = data is List ? data : (data['results'] ?? data);
        final categories = results.map((json) => TeensCategory.fromJson(json)).toList();
        
        // Cache in background
        Future.microtask(() async {
          await _db.cacheTeensCategories(categories);
          await _db.updateSyncMetadata('teens_categories');
        });
        
        debugPrint('Fetched and cached ${categories.length} teens categories');
        return categories;
      }
    } catch (e) {
      debugPrint('Error fetching teens categories: $e');
    }
    
    return cachedCategories;
  }

  // Teens content with cache-first strategy (fetches ALL pages)
  // Only fetches from server on first install (no cache) or manual refresh
  Future<List<TeensContent>> getTeensContent({bool forceRefresh = false}) async {
    await initialize();
    
    final cachedContent = await _db.getCachedTeensContent();
    
    // Return cached data if available and not forcing refresh
    if (cachedContent.isNotEmpty && !forceRefresh) {
      debugPrint('Returning ${cachedContent.length} cached teens content (offline-first)');
      return cachedContent;
    }
    
    // Only fetch from server on first install or manual refresh
    try {
      final hasConnection = await _checkConnectivity();
      if (!hasConnection) {
        debugPrint('No connection, returning cached teens content');
        return cachedContent;
      }
      
      // Use getAllPages to fetch ALL paginated results
      final allResults = await _api.getAllPages(ApiConstants.teensContent);
      final content = allResults.map((json) => TeensContent.fromJson(json)).toList();
      
      // Cache in background to not block UI
      Future.microtask(() async {
        await _db.cacheTeensContent(content);
        await _db.updateSyncMetadata('teens_content');
      });
      
      debugPrint('Fetched and cached ${content.length} teens content (all pages)');
      return content;
    } catch (e) {
      debugPrint('Error fetching teens content: $e');
    }
    
    return cachedContent;
  }

  // Teens content by category with cache-first strategy
  // Only fetches from server on first install (no cache) or manual refresh
  Future<List<TeensContent>> getTeensContentByCategory(int categoryId, {bool forceRefresh = false}) async {
    await initialize();
    
    final cachedContent = await _db.getCachedTeensContent(categoryId: categoryId);
    
    // Return cached data if available and not forcing refresh
    if (cachedContent.isNotEmpty && !forceRefresh) {
      debugPrint('Returning ${cachedContent.length} cached teens content for category $categoryId (offline-first)');
      return cachedContent;
    }
    
    // Only fetch from server on first install or manual refresh
    try {
      final hasConnection = await _checkConnectivity();
      if (!hasConnection) {
        debugPrint('No connection, returning cached teens content');
        return cachedContent;
      }
      
      // Use getAllPages to fetch ALL paginated results (not just first page)
      final allResults = await _api.getAllPages('${ApiConstants.teensContentByCategory}?category_id=$categoryId');
      final content = allResults.map((json) => TeensContent.fromJson(json as Map<String, dynamic>)).toList();
      
      // Cache in background to not block UI
      Future.microtask(() async {
        await _db.cacheTeensContent(content, categoryId: categoryId);
        await _db.updateSyncMetadata('teens_content_$categoryId');
      });
      
      debugPrint('Fetched and cached ${content.length} teens content for category $categoryId (all pages)');
      return content;
    } catch (e) {
      debugPrint('Error fetching teens content by category: $e');
    }
    
    return cachedContent;
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
