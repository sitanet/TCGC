import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/teens_content.dart';

class TeensCacheService {
  static final TeensCacheService _instance = TeensCacheService._internal();
  factory TeensCacheService() => _instance;
  TeensCacheService._internal();

  static const String _devotionalsKey = 'cached_teens_devotionals';
  static const String _retreatsKey = 'cached_teens_retreats';
  static const String _forgeCampKey = 'cached_teens_forge_camp';
  static const String _transcriptPrefix = 'teens_transcript_';

  Future<List<TeensContent>> getCachedDevotionals() async {
    return _getCachedContents(_devotionalsKey);
  }

  Future<List<TeensContent>> getCachedRetreats() async {
    return _getCachedContents(_retreatsKey);
  }

  Future<List<TeensContent>> getCachedForgeCamp() async {
    return _getCachedContents(_forgeCampKey);
  }

  Future<void> cacheDevotionals(List<TeensContent> contents) async {
    await _cacheContents(_devotionalsKey, contents);
  }

  Future<void> cacheRetreats(List<TeensContent> contents) async {
    await _cacheContents(_retreatsKey, contents);
  }

  Future<void> cacheForgeCamp(List<TeensContent> contents) async {
    await _cacheContents(_forgeCampKey, contents);
  }

  Future<List<TeensContent>> _getCachedContents(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(key);
      if (cached != null) {
        final List<dynamic> jsonList = json.decode(cached);
        return jsonList.map((j) => TeensContent.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('Error loading cached teens content: $e');
    }
    return [];
  }

  Future<void> _cacheContents(String key, List<TeensContent> contents) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = contents.map((c) => c.toJson()).toList();
      await prefs.setString(key, json.encode(jsonList));
    } catch (e) {
      debugPrint('Error caching teens content: $e');
    }
  }

  Future<String?> getCachedTranscript(String contentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_transcriptPrefix$contentId');
    } catch (e) {
      debugPrint('Error loading cached transcript: $e');
      return null;
    }
  }

  Future<void> cacheTranscript(String contentId, String transcript) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_transcriptPrefix$contentId', transcript);
    } catch (e) {
      debugPrint('Error caching transcript: $e');
    }
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key == _devotionalsKey || 
            key == _retreatsKey || 
            key == _forgeCampKey ||
            key.startsWith(_transcriptPrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('Error clearing teens cache: $e');
    }
  }
}
