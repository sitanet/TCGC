import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../domain/entities/transcript.dart';
import '../../core/constants/api_constants.dart';

class TranscriptCacheService {
  static final TranscriptCacheService _instance = TranscriptCacheService._internal();
  factory TranscriptCacheService() => _instance;
  TranscriptCacheService._internal();

  static const String _htmlCachePrefix = 'transcript_html_';
  static const String _transcriptsCacheKey = 'cached_transcripts_v2';

  Future<String?> getCachedHtml(String transcriptId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_htmlCachePrefix$transcriptId');
    } catch (e) {
      debugPrint('Error loading cached HTML: $e');
      return null;
    }
  }

  Future<void> cacheHtml(String transcriptId, String html) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_htmlCachePrefix$transcriptId', html);
    } catch (e) {
      debugPrint('Error caching HTML: $e');
    }
  }

  Future<String?> fetchAndCacheHtml(String transcriptId) async {
    try {
      final url = ApiConstants.standaloneTranscriptUrl(transcriptId);
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 30),
      );
      
      if (response.statusCode == 200) {
        final html = response.body;
        await cacheHtml(transcriptId, html);
        return html;
      }
    } catch (e) {
      debugPrint('Error fetching transcript HTML: $e');
    }
    return null;
  }

  Future<String?> getHtml(String transcriptId, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await getCachedHtml(transcriptId);
      if (cached != null && cached.isNotEmpty) {
        _refreshHtmlInBackground(transcriptId);
        return cached;
      }
    }
    return await fetchAndCacheHtml(transcriptId);
  }

  void _refreshHtmlInBackground(String transcriptId) {
    Future.delayed(const Duration(seconds: 2), () async {
      await fetchAndCacheHtml(transcriptId);
    });
  }

  Future<List<Transcript>> getCachedTranscripts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_transcriptsCacheKey);
      if (cached != null) {
        final List<dynamic> jsonList = json.decode(cached);
        return jsonList.map((j) => Transcript.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('Error loading cached transcripts: $e');
    }
    return [];
  }

  Future<void> cacheTranscripts(List<Transcript> transcripts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = transcripts.map((t) => t.toJson()).toList();
      await prefs.setString(_transcriptsCacheKey, json.encode(jsonList));
    } catch (e) {
      debugPrint('Error caching transcripts: $e');
    }
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_htmlCachePrefix) || key == _transcriptsCacheKey) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('Error clearing transcript cache: $e');
    }
  }
}
