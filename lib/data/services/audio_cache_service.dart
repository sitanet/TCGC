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
  // Pre-buffer 3 minutes of audio at 64kbps = ~1.5MB
  // 64kbps = 8KB/s, 3 min = 180s, 180 * 8KB = 1.44MB
  static const int _preBufferBytes = 1536 * 1024; // 1.5MB = ~3 minutes at 64kbps
  static const int _maxPreBufferItems = 20;

  Future<void> initialize() async {
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

  /// Pre-buffer audio files for a category (first N items)
  Future<void> preBufferCategory(List<Sermon> sermons, {int count = _maxPreBufferItems}) async {
    final toBuffer = sermons.take(count).toList();
    debugPrint('Pre-buffering ${toBuffer.length} audio files (~3 min each)...');
    
    for (final sermon in toBuffer) {
      if (sermon.audioUrl != null && sermon.audioUrl!.isNotEmpty) {
        // Don't wait, buffer in background
        _preBufferAudio(sermon.id, sermon.audioUrl!);
      }
    }
  }
  
  /// Pre-buffer additional items (for infinite scroll)
  Future<void> preBufferMore(List<Sermon> sermons, int startIndex, {int count = 10}) async {
    final endIndex = (startIndex + count).clamp(0, sermons.length);
    if (startIndex >= sermons.length) return;
    
    final toBuffer = sermons.sublist(startIndex, endIndex);
    debugPrint('Pre-buffering ${toBuffer.length} more audio files (index $startIndex-$endIndex)...');
    
    for (final sermon in toBuffer) {
      if (sermon.audioUrl != null && sermon.audioUrl!.isNotEmpty) {
        _preBufferAudio(sermon.id, sermon.audioUrl!);
      }
    }
  }

  /// Pre-buffer the initial bytes of an audio file for instant playback
  Future<void> _preBufferAudio(String sermonId, String url) async {
    if (_bufferingInProgress[sermonId] == true) return;
    if (_audioBuffers.containsKey(sermonId)) return;
    
    _bufferingInProgress[sermonId] = true;
    _bufferProgress[sermonId] = 0.0;
    
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Range'] = 'bytes=0-${_preBufferBytes - 1}';
      
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      
      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 206) {
        final bytes = <int>[];
        final contentLength = streamedResponse.contentLength ?? _preBufferBytes;
        
        await for (final chunk in streamedResponse.stream) {
          bytes.addAll(chunk);
          _bufferProgress[sermonId] = bytes.length / contentLength;
          
          if (bytes.length >= _preBufferBytes) break;
        }
        
        _audioBuffers[sermonId] = bytes;
        _bufferProgress[sermonId] = 1.0;
        debugPrint('Pre-buffered ${bytes.length ~/ 1024}KB for sermon: $sermonId');
        
        // Also save to disk for persistence
        await _saveBufferToDisk(sermonId, bytes);
      }
    } catch (e) {
      debugPrint('Pre-buffer error for $sermonId: $e');
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

  /// Check if audio is pre-buffered and ready for instant playback
  bool isPreBuffered(String sermonId) {
    return _audioBuffers.containsKey(sermonId);
  }

  /// Get pre-buffered bytes for a sermon
  Future<List<int>?> getPreBufferedBytes(String sermonId) async {
    if (_audioBuffers.containsKey(sermonId)) {
      return _audioBuffers[sermonId];
    }
    // Try loading from disk
    final diskBuffer = await _loadBufferFromDisk(sermonId);
    if (diskBuffer != null) {
      _audioBuffers[sermonId] = diskBuffer;
      return diskBuffer;
    }
    return null;
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
  Future<void> preBufferSingle(Sermon sermon) async {
    if (sermon.audioUrl != null && sermon.audioUrl!.isNotEmpty) {
      await _preBufferAudio(sermon.id, sermon.audioUrl!);
    }
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
