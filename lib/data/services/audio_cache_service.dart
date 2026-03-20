import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../domain/entities/sermon.dart';

class AudioCacheService {
  static final AudioCacheService _instance = AudioCacheService._internal();
  factory AudioCacheService() => _instance;
  AudioCacheService._internal();

  Directory? _cacheDir;
  final Map<String, List<int>> _audioBuffers = {};
  final Map<String, bool> _bufferingInProgress = {};
  final Map<String, double> _bufferProgress = {};
  
  static const String _metadataCacheKey = 'audio_metadata_cache';
  static const String _categoriesCacheKey = 'categories_cache';
  // Pre-buffer ~30 seconds of audio for instant playback
  // At 128kbps (16KB/s), 30 seconds = ~480KB. We use 512KB for comfortable buffer.
  static const int _preBufferBytes = 512 * 1024; // 512KB for ~30 seconds
  static const int _maxPreBufferItems = 5; // Only buffer first 5 sermons to avoid memory issues
  
  // Store full URLs for pre-buffered content
  final Map<String, String> _audioUrls = {};

  Future<void> initialize() async {
    // Skip file-based caching on web platform
    if (kIsWeb) {
      debugPrint('AudioCacheService initialized (web mode - no file caching)');
      return;
    }
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/audio_buffer_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      debugPrint('AudioCacheService initialized: ${_cacheDir!.path}');
    } catch (e) {
      debugPrint('AudioCacheService init error: $e');
    }
  }

  // Cache metadata (categories and sermons)
  Future<void> cacheMetadata({
    List<MessageCategory>? categories,
    List<Sermon>? sermons,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (categories != null) {
        final categoriesJson = categories.map((c) => c.toJson()).toList();
        await prefs.setString(_categoriesCacheKey, jsonEncode(categoriesJson));
        debugPrint('Cached ${categories.length} categories');
      }
      
      if (sermons != null) {
        final sermonsJson = sermons.map((s) => s.toJson()).toList();
        await prefs.setString(_metadataCacheKey, jsonEncode(sermonsJson));
        debugPrint('Cached ${sermons.length} sermons metadata');
      }
    } catch (e) {
      debugPrint('Error caching metadata: $e');
    }
  }

  Future<List<MessageCategory>?> getCachedCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_categoriesCacheKey);
      if (data != null) {
        final List<dynamic> json = jsonDecode(data);
        return json.map((j) => MessageCategory.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('Error reading cached categories: $e');
    }
    return null;
  }

  Future<List<Sermon>?> getCachedSermons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_metadataCacheKey);
      if (data != null) {
        final List<dynamic> json = jsonDecode(data);
        return json.map((j) => Sermon.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('Error reading cached sermons: $e');
    }
    return null;
  }

  /// Pre-buffer audio files silently in background for instant playback
  /// DISABLED: Causing ANR issues, audio will stream directly instead
  Future<void> preBufferCategory(List<Sermon> sermons, {int count = _maxPreBufferItems}) async {
    // Disabled pre-buffering to prevent ANR - audio will stream on demand
    debugPrint('Pre-buffering disabled to prevent ANR issues');
    return;
  }
  
  /// Pre-buffer additional items (for infinite scroll)
  /// DISABLED: Causing ANR issues
  Future<void> preBufferMore(List<Sermon> sermons, int startIndex, {int count = 10}) async {
    // Disabled to prevent ANR
    return;
  }

  /// Pre-buffer ~1 minute of audio for instant playback
  Future<void> _preBufferAudio(String sermonId, String url) async {
    if (_bufferingInProgress[sermonId] == true) return;
    if (_audioBuffers.containsKey(sermonId)) return;
    
    _bufferingInProgress[sermonId] = true;
    _bufferProgress[sermonId] = 0.0;
    
    try {
      // First check if server supports range requests
      final headResponse = await http.head(Uri.parse(url)).timeout(
        const Duration(seconds: 5),
      );
      final contentLength = int.tryParse(headResponse.headers['content-length'] ?? '');
      final acceptsRanges = headResponse.headers['accept-ranges'] == 'bytes';
      
      // Determine how much to buffer (min of 1 minute worth or full file)
      final bytesToBuffer = contentLength != null 
          ? (contentLength < _preBufferBytes ? contentLength : _preBufferBytes)
          : _preBufferBytes;
      
      final request = http.Request('GET', Uri.parse(url));
      if (acceptsRanges) {
        request.headers['Range'] = 'bytes=0-${bytesToBuffer - 1}';
      }
      
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30), // 30s timeout for 1MB
      );
      
      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 206) {
        final bytes = <int>[];
        final expectedLength = streamedResponse.contentLength ?? bytesToBuffer;
        
        await for (final chunk in streamedResponse.stream) {
          bytes.addAll(chunk);
          _bufferProgress[sermonId] = (bytes.length / expectedLength).clamp(0.0, 1.0);
          
          // Stop if we have enough
          if (bytes.length >= bytesToBuffer) break;
        }
        
        _audioBuffers[sermonId] = bytes;
        _audioUrls[sermonId] = url;
        _bufferProgress[sermonId] = 1.0;
        
        // Save to disk for persistence across app restarts
        await _saveBufferToDisk(sermonId, bytes);
        await _saveUrlToDisk(sermonId, url);
      }
    } catch (e) {
      debugPrint('Pre-buffer error for $sermonId: $e');
      _bufferProgress[sermonId] = 0.0;
    } finally {
      _bufferingInProgress[sermonId] = false;
    }
  }

  Future<void> _saveBufferToDisk(String sermonId, List<int> bytes) async {
    if (_cacheDir == null) return;
    try {
      final file = File('${_cacheDir!.path}/${_sanitizeFileName(sermonId)}.buf');
      await file.writeAsBytes(bytes);
    } catch (e) {
      debugPrint('Error saving buffer to disk: $e');
    }
  }

  Future<void> _saveUrlToDisk(String sermonId, String url) async {
    if (_cacheDir == null) return;
    try {
      final file = File('${_cacheDir!.path}/${_sanitizeFileName(sermonId)}.url');
      await file.writeAsString(url);
    } catch (e) {
      debugPrint('Error saving URL to disk: $e');
    }
  }

  Future<String?> _loadUrlFromDisk(String sermonId) async {
    if (_cacheDir == null) return null;
    try {
      final file = File('${_cacheDir!.path}/${_sanitizeFileName(sermonId)}.url');
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      debugPrint('Error loading URL from disk: $e');
    }
    return null;
  }

  Future<List<int>?> _loadBufferFromDisk(String sermonId) async {
    if (_cacheDir == null) return null;
    try {
      final file = File('${_cacheDir!.path}/${_sanitizeFileName(sermonId)}.buf');
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('Error loading buffer from disk: $e');
    }
    return null;
  }

  /// Check if audio is pre-buffered and ready for instant playback (memory only for speed)
  bool isPreBuffered(String sermonId) {
    return _audioBuffers.containsKey(sermonId);
  }
  
  /// Check if audio exists on disk (for when memory cache is cold)
  Future<bool> isPreBufferedOnDisk(String sermonId) async {
    if (_audioBuffers.containsKey(sermonId)) return true;
    if (_cacheDir == null) return false;
    final file = File('${_cacheDir!.path}/${_sanitizeFileName(sermonId)}.buf');
    return await file.exists();
  }

  /// Get pre-buffered bytes for a sermon (checks memory then disk)
  Future<List<int>?> getPreBufferedBytes(String sermonId) async {
    if (_audioBuffers.containsKey(sermonId)) {
      return _audioBuffers[sermonId];
    }
    // Try loading from disk
    final diskBuffer = await _loadBufferFromDisk(sermonId);
    if (diskBuffer != null) {
      _audioBuffers[sermonId] = diskBuffer;
      // Also load the URL
      final url = await _loadUrlFromDisk(sermonId);
      if (url != null) {
        _audioUrls[sermonId] = url;
      }
      return diskBuffer;
    }
    return null;
  }

  /// Get the URL for a pre-buffered sermon
  String? getPreBufferedUrl(String sermonId) {
    return _audioUrls[sermonId];
  }

  /// Get buffer progress (0.0 to 1.0)
  double getBufferProgress(String sermonId) {
    return _bufferProgress[sermonId] ?? 0.0;
  }

  /// Check if buffering is in progress
  bool isBuffering(String sermonId) {
    return _bufferingInProgress[sermonId] == true;
  }

  /// Pre-buffer a single sermon (call when user might play it soon)
  /// DISABLED: Causing ANR issues
  Future<void> preBufferSingle(Sermon sermon) async {
    // Disabled to prevent ANR
    return;
  }

  String _sanitizeFileName(String id) {
    return id.replaceAll(RegExp(r'[^\w\-]'), '_');
  }

  /// Clear all buffers from memory (keeps disk cache)
  void clearMemoryBuffers() {
    _audioBuffers.clear();
    _bufferProgress.clear();
    debugPrint('Memory buffers cleared');
  }

  /// Clear all cached data
  Future<void> clearAllCache() async {
    _audioBuffers.clear();
    _bufferProgress.clear();
    _bufferingInProgress.clear();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_metadataCacheKey);
      await prefs.remove(_categoriesCacheKey);
      
      if (_cacheDir != null && await _cacheDir!.exists()) {
        await for (var entity in _cacheDir!.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
      debugPrint('All audio cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  /// Clear only metadata cache (categories and sermons list)
  Future<void> clearMetadataCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_metadataCacheKey);
      await prefs.remove(_categoriesCacheKey);
      debugPrint('Audio metadata cache cleared');
    } catch (e) {
      debugPrint('Error clearing metadata cache: $e');
    }
  }

  /// Get total cache size
  Future<int> getCacheSize() async {
    int totalSize = 0;
    
    // Memory buffers
    for (final buffer in _audioBuffers.values) {
      totalSize += buffer.length;
    }
    
    // Disk cache
    if (_cacheDir != null && await _cacheDir!.exists()) {
      await for (var entity in _cacheDir!.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    }
    
    return totalSize;
  }
}
