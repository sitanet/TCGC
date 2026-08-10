import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import '../../domain/entities/sermon.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/teens_content.dart';
import '../../domain/entities/teens_category.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/promotion.dart';
import '../../domain/entities/transcript.dart';
import 'api_service.dart';
import 'content_cache_service.dart';

class DataService {
  final ApiService _api = ApiService();
  final ContentCacheService _cacheService = ContentCacheService();

  // Message Categories - Now uses cache-first strategy
  Future<List<MessageCategory>> getMessageCategories({
    bool forceRefresh = false,
  }) async {
    return await _cacheService.getCategories(forceRefresh: forceRefresh);
  }

  // Legacy method for backward compatibility (fetches directly from API)
  Future<List<MessageCategory>> getMessageCategoriesFromServer() async {
    final response = await _api.get(ApiConstants.messageCategories);
    if (response.isSuccess) {
      final decoded = response.data;
      final List<dynamic> data = decoded is List
          ? decoded
          : (decoded['results'] ?? decoded);
      return data.map((json) => MessageCategory.fromJson(json)).toList();
    }
    return [];
  }

  // Messages/Sermons - Now uses cache-first strategy
  Future<List<Sermon>> getMessages({bool forceRefresh = false}) async {
    return await _cacheService.getSermons(forceRefresh: forceRefresh);
  }

  /// Clears all cached sermons and fetches fresh data from server
  /// Use this when audio URLs are missing or corrupted
  Future<List<Sermon>> clearAndRefreshMessages() async {
    return await _cacheService.clearAndRefreshSermons();
  }

  // Legacy method for backward compatibility (fetches ALL pages directly from API)
  Future<List<Sermon>> getMessagesFromServer() async {
    final allResults = await _api.getAllPages(ApiConstants.messages);
    return allResults.map((json) => Sermon.fromJson(json)).toList();
  }

  Future<Sermon?> getMessageById(String messageId) async {
    final response = await _api.get('${ApiConstants.messages}$messageId/');
    if (response.isSuccess) {
      return Sermon.fromJson(response.data);
    }
    return null;
  }

  Future<List<Sermon>> getMessagesByCategory(String categoryId) async {
    final response = await _api.get(
      '${ApiConstants.messagesByCategory}?category_id=$categoryId',
    );
    if (response.isSuccess) {
      final List<dynamic> data = response.dataList;
      return data.map((json) => Sermon.fromJson(json)).toList();
    }
    return [];
  }

  Future<List<Sermon>> getMessagesByCategoryName(String categoryName) async {
    final response = await _api.get(
      '${ApiConstants.messagesByCategory}?category=$categoryName',
    );
    if (response.isSuccess) {
      final List<dynamic> data = response.dataList;
      return data.map((json) => Sermon.fromJson(json)).toList();
    }
    return [];
  }

  // Get messages by speaker
  Future<List<Sermon>> getMessagesBySpeaker(String speaker) async {
    final encodedSpeaker = Uri.encodeComponent(speaker);
    debugPrint(
      'Fetching messages for speaker: $speaker (encoded: $encodedSpeaker)',
    );
    final response = await _api.get(
      '${ApiConstants.messages}by_speaker/?speaker=$encodedSpeaker',
    );
    debugPrint(
      'Response isSuccess: ${response.isSuccess}, data: ${response.data}',
    );
    if (response.isSuccess) {
      final List<dynamic> data = response.dataList;
      debugPrint('Found ${data.length} messages by speaker');
      return data.map((json) => Sermon.fromJson(json)).toList();
    }
    return [];
  }

  static List<SpeakerModel>? _cachedSpeakers;

  // Get all speakers with memory caching
  Future<List<SpeakerModel>> getSpeakers({bool forceRefresh = false}) async {
    if (_cachedSpeakers != null && _cachedSpeakers!.isNotEmpty && !forceRefresh) {
      return _cachedSpeakers!;
    }

    try {
      final response = await _api.get('${ApiConstants.messages}speakers/');
      if (response.isSuccess) {
        final data = response.data;
        final List<dynamic> speakers = data['speakers'] ?? [];
        _cachedSpeakers = speakers.map((s) => SpeakerModel.fromJson(s)).toList();
        return _cachedSpeakers!;
      }
    } catch (e) {
      debugPrint('Error fetching speakers: $e');
    }
    return _cachedSpeakers ?? [];
  }

  // Get recommended messages - Now uses cache-first strategy
  Future<List<Sermon>> getRecommendedMessages({
    bool forceRefresh = false,
  }) async {
    return await _cacheService.getRecommendedSermons(
      forceRefresh: forceRefresh,
    );
  }

  // Get speaker names only (for filtering)
  Future<List<String>> getSpeakerNames() async {
    final speakers = await getSpeakers();
    return speakers.map((s) => s.fullName).toList();
  }

  // Track message statistics (favorite, share)
  Future<bool> trackMessageStat({
    required String messageId,
    required String action,
    required bool added,
  }) async {
    try {
      final response = await _api.post(ApiConstants.messageStats, {
        'message_id': messageId,
        'action': action,
        'added': added,
      });
      return response.isSuccess;
    } catch (e) {
      return false;
    }
  }

  // Transcripts (standalone) — cache-first strategy
  static const String _transcriptsCacheKey = 'cached_transcripts';
  static const Duration _transcriptsCacheTtl = Duration(hours: 6);
  static const String _transcriptsCacheTimeKey = 'cached_transcripts_time';

  Future<List<Transcript>> getTranscripts({bool forceRefresh = false}) async {
    // 1. Try cache first (unless force refresh)
    if (!forceRefresh) {
      final cached = await _getCachedTranscripts();
      if (cached != null && cached.isNotEmpty) {
        // Refresh in background without blocking UI
        _refreshTranscriptsInBackground();
        return cached;
      }
    }

    // 2. Fetch from server
    return await _fetchTranscriptsFromServer() ?? [];
  }

  Future<List<Transcript>?> _getCachedTranscripts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_transcriptsCacheKey);
      final cachedTime = prefs.getInt(_transcriptsCacheTimeKey) ?? 0;

      if (cachedJson == null) return null;

      // Check TTL
      final age = DateTime.now().millisecondsSinceEpoch - cachedTime;
      if (age > _transcriptsCacheTtl.inMilliseconds) {
        debugPrint('Transcripts cache expired, will refresh');
        return null;
      }

      final List<dynamic> jsonList = jsonDecode(cachedJson);
      return jsonList.map((j) => Transcript.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error reading transcripts cache: $e');
      return null;
    }
  }

  Future<List<Transcript>?> _fetchTranscriptsFromServer() async {
    try {
      final response = await _api.get(ApiConstants.transcripts);
      if (response.isSuccess) {
        final data = response.data;
        final List<dynamic> results = data is List
            ? data
            : (data['results'] ?? data);
        final transcripts = results
            .map((json) => Transcript.fromJson(json))
            .toList();
        // Save to cache
        await _saveTranscriptsCache(transcripts);
        return transcripts;
      }
    } catch (e) {
      debugPrint('Error fetching transcripts from server: $e');
    }
    return null;
  }

  Future<void> _saveTranscriptsCache(List<Transcript> transcripts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = transcripts.map((t) => t.toJson()).toList();
      await prefs.setString(_transcriptsCacheKey, jsonEncode(jsonList));
      await prefs.setInt(
        _transcriptsCacheTimeKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      debugPrint('Cached ${transcripts.length} transcripts');
    } catch (e) {
      debugPrint('Error saving transcripts cache: $e');
    }
  }

  void _refreshTranscriptsInBackground() {
    Future.microtask(() async {
      await _fetchTranscriptsFromServer();
      debugPrint('Transcripts cache refreshed in background');
    });
  }

  Future<Transcript?> getTranscriptById(String transcriptId) async {
    final response = await _api.get(
      '${ApiConstants.transcripts}$transcriptId/',
    );
    if (response.isSuccess) {
      return Transcript.fromJson(response.data);
    }
    return null;
  }

  Future<List<Transcript>> getTranscriptsByCategory(String categoryId) async {
    final response = await _api.get(
      '${ApiConstants.transcriptsByCategory}?category_id=$categoryId',
    );
    if (response.isSuccess) {
      final List<dynamic> data = response.dataList;
      return data.map((json) => Transcript.fromJson(json)).toList();
    }
    return [];
  }

  Future<List<Transcript>> getFeaturedTranscripts() async {
    final response = await _api.get(ApiConstants.featuredTranscripts);
    if (response.isSuccess) {
      final List<dynamic> data = response.dataList;
      return data.map((json) => Transcript.fromJson(json)).toList();
    }
    return [];
  }

  // Events - Now uses cache-first strategy
  Future<List<Event>> getEvents({bool forceRefresh = false}) async {
    return await _cacheService.getEvents(forceRefresh: forceRefresh);
  }

  // Legacy method for backward compatibility
  Future<List<Event>> getEventsFromServer() async {
    final response = await _api.get(ApiConstants.events);
    if (response.isSuccess) {
      final data = response.data;
      final List<dynamic> results = data['results'] ?? data;
      return results.map((json) => Event.fromJson(json)).toList();
    }
    return [];
  }

  Future<List<Event>> getTeensEvents({bool forceRefresh = false}) async {
    const cacheKey = 'cached_teens_events';
    const cacheTimeKey = 'cached_teens_events_time';
    const ttl = Duration(hours: 6);

    if (!forceRefresh) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(cacheKey);
        final cachedTime = prefs.getInt(cacheTimeKey) ?? 0;
        final age = DateTime.now().millisecondsSinceEpoch - cachedTime;
        if (cached != null && age < ttl.inMilliseconds) {
          final list = jsonDecode(cached) as List;
          _refreshInBackground(() => getTeensEvents(forceRefresh: true));
          return list.map((j) => Event.fromJson(j)).toList();
        }
      } catch (_) {}
    }

    final response = await _api.get(ApiConstants.teensEvents);
    if (response.isSuccess) {
      final data = response.dataList;
      final events = data.map((j) => Event.fromJson(j)).toList();
      _saveCache(
        'cached_teens_events',
        'cached_teens_events_time',
        events.map((e) => e.toJson()).toList(),
      );
      return events;
    }
    return [];
  }

  Future<List<Event>> getLiveEvents() async {
    final response = await _api.get(ApiConstants.liveEvents);
    if (response.isSuccess) {
      final List<dynamic> data = response.dataList;
      return data.map((json) => Event.fromJson(json)).toList();
    }
    return [];
  }

  // Teens Categories - Now uses cache-first strategy
  Future<List<TeensCategory>> getTeensCategories({
    bool forceRefresh = false,
  }) async {
    return await _cacheService.getTeensCategories(forceRefresh: forceRefresh);
  }

  // Legacy method for backward compatibility
  Future<List<TeensCategory>> getTeensCategoriesFromServer() async {
    final response = await _api.get(ApiConstants.teensCategories);
    if (response.isSuccess) {
      final data = response.data;
      final List<dynamic> results = data is List
          ? data
          : (data['results'] ?? data);
      return results.map((json) => TeensCategory.fromJson(json)).toList();
    }
    return [];
  }

  // Teens Banner — cache-first
  Future<String?> getTeensBannerUrl({bool forceRefresh = false}) async {
    const cacheKey = 'cached_teens_banner_url';
    const cacheTimeKey = 'cached_teens_banner_url_time';
    const ttl = Duration(hours: 12);

    if (!forceRefresh) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(cacheKey);
        final cachedTime = prefs.getInt(cacheTimeKey) ?? 0;
        final age = DateTime.now().millisecondsSinceEpoch - cachedTime;
        if (cached != null && age < ttl.inMilliseconds) {
          _refreshInBackground(() => getTeensBannerUrl(forceRefresh: true));
          return cached;
        }
      } catch (_) {}
    }

    final response = await _api.get(ApiConstants.teensBanner);
    if (response.isSuccess) {
      final url = response.data['image_url'] as String?;
      if (url != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(cacheKey, url);
          await prefs.setInt(
            cacheTimeKey,
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (_) {}
      }
      return url;
    }
    return null;
  }

  // Devotionals — cache-first
  Future<List<TeensContent>> getDevotionals({bool forceRefresh = false}) async {
    return await _getTeensContentCached(
      cacheKey: 'cached_teens_devotionals',
      apiUrl: ApiConstants.devotionals,
      forceRefresh: forceRefresh,
      label: 'Devotionals',
    );
  }

  // Retreats — cache-first
  Future<List<TeensContent>> getRetreats({bool forceRefresh = false}) async {
    return await _getTeensContentCached(
      cacheKey: 'cached_teens_retreats',
      apiUrl: ApiConstants.retreats,
      forceRefresh: forceRefresh,
      label: 'Retreats',
    );
  }

  // Forge Camp — cache-first
  Future<List<TeensContent>> getForgeCamp({bool forceRefresh = false}) async {
    return await _getTeensContentCached(
      cacheKey: 'cached_teens_forgecamp',
      apiUrl: ApiConstants.forgeCamp,
      forceRefresh: forceRefresh,
      label: 'ForgeCamp',
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  /// Generic cache-first loader for TeensContent lists
  Future<List<TeensContent>> _getTeensContentCached({
    required String cacheKey,
    required String apiUrl,
    required bool forceRefresh,
    required String label,
  }) async {
    final cacheTimeKey = '${cacheKey}_time';
    const ttl = Duration(hours: 6);

    if (!forceRefresh) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(cacheKey);
        final cachedTime = prefs.getInt(cacheTimeKey) ?? 0;
        final age = DateTime.now().millisecondsSinceEpoch - cachedTime;
        if (cached != null && age < ttl.inMilliseconds) {
          final list = jsonDecode(cached) as List;
          // Refresh in background
          _refreshInBackground(
            () => _getTeensContentCached(
              cacheKey: cacheKey,
              apiUrl: apiUrl,
              forceRefresh: true,
              label: label,
            ),
          );
          return list
              .map((j) => TeensContent.fromJson(j as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('$label cache read error: $e');
      }
    }

    // Fetch from server
    final response = await _api.get(apiUrl);
    if (response.isSuccess) {
      try {
        final decoded = jsonDecode(response.body);
        List<dynamic> results;
        if (decoded is List) {
          results = decoded;
        } else if (decoded is Map) {
          results = decoded['results'] ?? decoded['data'] ?? [];
        } else {
          results = [];
        }
        final items = results
            .map((j) => TeensContent.fromJson(j as Map<String, dynamic>))
            .toList();
        // Save to cache
        await _saveCache(
          cacheKey,
          cacheTimeKey,
          items.map((i) => i.toJson()).toList(),
        );
        debugPrint('$label: fetched ${items.length} items from server');
        return items;
      } catch (e) {
        debugPrint('$label parse error: $e');
      }
    }
    debugPrint('$label API failed: ${response.errorMessage}');
    return [];
  }

  /// Save a JSON list to SharedPreferences cache
  Future<void> _saveCache(
    String key,
    String timeKey,
    List<dynamic> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(data));
      await prefs.setInt(timeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Cache save error ($key): $e');
    }
  }

  /// Run a refresh in the background without blocking the caller
  void _refreshInBackground(Future<dynamic> Function() fn) {
    Future.microtask(() async {
      try {
        await fn();
      } catch (e) {
        debugPrint('Background refresh error: $e');
      }
    });
  }

  // Teens Content - Now uses cache-first strategy
  Future<List<TeensContent>> getTeensContent({
    bool forceRefresh = false,
  }) async {
    return await _cacheService.getTeensContent(forceRefresh: forceRefresh);
  }

  Future<List<TeensContent>> getTeensContentByCategory(
    int categoryId, {
    bool forceRefresh = false,
  }) async {
    return await _cacheService.getTeensContentByCategory(
      categoryId,
      forceRefresh: forceRefresh,
    );
  }

  // Legacy method for backward compatibility
  Future<List<TeensContent>> getTeensContentFromServer(int categoryId) async {
    final url =
        '${ApiConstants.teensContentByCategory}?category_id=$categoryId';
    debugPrint(
      'Fetching teens content by category: ${ApiConstants.baseUrl}$url',
    );
    final response = await _api.get(url);
    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response body: ${response.body}');
    if (response.isSuccess) {
      try {
        final decoded = jsonDecode(response.body);
        debugPrint('Decoded type: ${decoded.runtimeType}');
        List<dynamic> results;
        if (decoded is List) {
          results = decoded;
        } else if (decoded is Map) {
          results = decoded['results'] ?? [];
        } else {
          results = [];
        }
        debugPrint('Teens content results count: ${results.length}');
        return results
            .map((json) => TeensContent.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e, stackTrace) {
        debugPrint('Error parsing teens content: $e');
        debugPrint('Stack trace: $stackTrace');
      }
    }
    debugPrint('Teens content API failed: ${response.errorMessage}');
    return [];
  }

  Future<List<TeensContent>> getTeensContentByCategoryName(
    String categoryName,
  ) async {
    final response = await _api.get(
      '${ApiConstants.teensContentByCategory}?category=$categoryName',
    );
    if (response.isSuccess) {
      final data = response.data;
      final List<dynamic> results = data is List
          ? data
          : (data['results'] ?? data);
      return results.map((json) => TeensContent.fromJson(json)).toList();
    }
    return [];
  }

  // Wallet
  Future<Wallet?> getWallet() async {
    final response = await _api.get(ApiConstants.wallet);
    if (response.isSuccess) {
      return Wallet.fromJson(response.data);
    }
    return null;
  }

  Future<List<Transaction>> getTransactions() async {
    final response = await _api.get(ApiConstants.transactions);
    if (response.isSuccess) {
      final data = response.data;
      final List<dynamic> results = data['results'] ?? data;
      return results.map((json) => Transaction.fromJson(json)).toList();
    }
    return [];
  }

  Future<WalletResult> addMoney(double amount) async {
    final response = await _api.post(ApiConstants.addMoney, {'amount': amount});
    if (response.isSuccess) {
      return WalletResult(
        success: true,
        newBalance: double.tryParse(response.data['new_balance'] ?? '0'),
      );
    }
    return WalletResult(
      success: false,
      error: response.errorMessage ?? 'Failed to add money',
    );
  }

  Future<WalletResult> sendMoney(
    String recipientEmail,
    double amount,
    String pin,
  ) async {
    final response = await _api.post(ApiConstants.sendMoney, {
      'recipient_email': recipientEmail,
      'amount': amount,
      'pin': pin,
    });
    if (response.isSuccess) {
      return WalletResult(
        success: true,
        newBalance: double.tryParse(response.data['new_balance'] ?? '0'),
      );
    }
    return WalletResult(
      success: false,
      error: response.errorMessage ?? 'Failed to send money',
    );
  }

  // Give Options
  Future<List<GiveOption>> getGiveOptions() async {
    final response = await _api.get(ApiConstants.giveOptions);
    if (response.isSuccess) {
      final List<dynamic> data = response.dataList;
      return data.map((json) => GiveOption.fromJson(json)).toList();
    }
    return [];
  }

  Future<WalletResult> give(int giveOptionId, double amount) async {
    final response = await _api.post(ApiConstants.givings, {
      'give_option': giveOptionId,
      'amount': amount,
    });
    if (response.isSuccess) {
      return WalletResult(success: true);
    }
    return WalletResult(
      success: false,
      error: response.errorMessage ?? 'Failed to process giving',
    );
  }

  // Promotions
  Future<List<Promotion>> getActivePromotions() async {
    final response = await _api.get(ApiConstants.activePromotion);
    if (response.isSuccess) {
      try {
        final List<dynamic> data = response.dataList;
        return data.map((json) => Promotion.fromJson(json)).toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  Future<AppUpdateInfo?> checkForAppUpdate(
    String currentVersion,
    String platform,
  ) async {
    final response = await _api.get(
      '${ApiConstants.checkAppUpdate}?version=$currentVersion&platform=$platform',
    );
    if (response.isSuccess) {
      try {
        return AppUpdateInfo.fromJson(response.data);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}

class WalletResult {
  final bool success;
  final String? error;
  final double? newBalance;

  WalletResult({required this.success, this.error, this.newBalance});
}

class GiveOption {
  final int id;
  final String name;
  final String? description;
  final bool isActive;

  GiveOption({
    required this.id,
    required this.name,
    this.description,
    this.isActive = true,
  });

  factory GiveOption.fromJson(Map<String, dynamic> json) {
    return GiveOption(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      isActive: json['is_active'] ?? true,
    );
  }
}

class AppUpdateInfo {
  final bool updateAvailable;
  final bool forceUpdate;
  final String currentVersion;
  final String latestVersion;
  final String minimumVersion;
  final String updateMessage;
  final String? updateUrl;

  AppUpdateInfo({
    required this.updateAvailable,
    required this.forceUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.minimumVersion,
    required this.updateMessage,
    this.updateUrl,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      updateAvailable: json['update_available'] ?? false,
      forceUpdate: json['force_update'] ?? false,
      currentVersion: json['current_version'] ?? '',
      latestVersion: json['latest_version'] ?? '',
      minimumVersion: json['minimum_version'] ?? '',
      updateMessage: json['update_message'] ?? '',
      updateUrl: json['update_url'],
    );
  }
}

class SpeakerModel {
  final int id;
  final String name;
  final String? title;
  final String fullName;
  final String? bio;
  final String? photoUrl;
  final bool isActive;
  final bool isMainSpeaker;
  final bool seniorPastor;
  final bool showExploreSection;

  SpeakerModel({
    required this.id,
    required this.name,
    this.title,
    required this.fullName,
    this.bio,
    this.photoUrl,
    this.isActive = true,
    this.isMainSpeaker = false,
    this.seniorPastor = false,
    this.showExploreSection = false,
  });

  factory SpeakerModel.fromJson(Map<String, dynamic> json) {
    String? rawPhotoUrl =
        json['photo_url'] ??
        json['image_url'] ??
        json['picture'] ??
        json['avatar'] ??
        json['photo'];
    // If it's a relative URL, prepend the base URL
    if (rawPhotoUrl != null &&
        rawPhotoUrl.isNotEmpty &&
        !rawPhotoUrl.startsWith('http')) {
      rawPhotoUrl = 'https://tcgc.thecitygatechurch.org$rawPhotoUrl';
    }
    return SpeakerModel(
      id: json['id'],
      name: json['name'] ?? '',
      title: json['title'],
      fullName: json['full_name'] ?? json['name'] ?? '',
      bio: json['bio'],
      photoUrl: rawPhotoUrl,
      isActive: json['is_active'] ?? true,
      isMainSpeaker: json['is_main_speaker'] ?? false,
      seniorPastor: json['senior_pastor'] ?? false,
      showExploreSection: json['show_explore_section'] ?? false,
    );
  }
}
