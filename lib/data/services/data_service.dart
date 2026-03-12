import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/constants/api_constants.dart';
import '../../domain/entities/sermon.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/teens_content.dart';
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
  Future<List<MessageCategory>> getMessageCategories({bool forceRefresh = false}) async {
    return await _cacheService.getCategories(forceRefresh: forceRefresh);
  }
  
  // Legacy method for backward compatibility (fetches directly from API)
  Future<List<MessageCategory>> getMessageCategoriesFromServer() async {
    final response = await _api.get(ApiConstants.messageCategories);
    if (response.isSuccess) {
      final decoded = response.data;
      final List<dynamic> data = decoded is List ? decoded : (decoded['results'] ?? decoded);
      return data.map((json) => MessageCategory.fromJson(json)).toList();
    }
    return [];
  }

  // Messages/Sermons - Now uses cache-first strategy
  Future<List<Sermon>> getMessages({bool forceRefresh = false}) async {
    return await _cacheService.getSermons(forceRefresh: forceRefresh);
  }
  
  // Legacy method for backward compatibility (fetches directly from API)
  Future<List<Sermon>> getMessagesFromServer() async {
    final response = await _api.get(ApiConstants.messages);
    if (response.isSuccess) {
      final data = response.data;
      final List<dynamic> results = data['results'] ?? data;
      return results.map((json) => Sermon.fromJson(json)).toList();
    }
    return [];
  }

  Future<Sermon?> getMessageById(String messageId) async {
    final response = await _api.get('${ApiConstants.messages}$messageId/');
    if (response.isSuccess) {
      return Sermon.fromJson(response.data);
    }
    return null;
  }

  Future<List<Sermon>> getMessagesByCategory(String categoryId) async {
    final response = await _api.get('${ApiConstants.messagesByCategory}?category_id=$categoryId');
    if (response.isSuccess) {
      final List<dynamic> data = response.dataList;
      return data.map((json) => Sermon.fromJson(json)).toList();
    }
    return [];
  }

  Future<List<Sermon>> getMessagesByCategoryName(String categoryName) async {
    final response = await _api.get('${ApiConstants.messagesByCategory}?category=$categoryName');
    if (response.isSuccess) {
      final List<dynamic> data = response.dataList;
      return data.map((json) => Sermon.fromJson(json)).toList();
    }
    return [];
  }

  // Get messages by speaker
  Future<List<Sermon>> getMessagesBySpeaker(String speaker) async {
    final response = await _api.get('${ApiConstants.messages}by_speaker/?speaker=$speaker');
    if (response.isSuccess) {
      final List<dynamic> data = response.dataList;
      return data.map((json) => Sermon.fromJson(json)).toList();
    }
    return [];
  }

  // Get all speakers
  Future<List<SpeakerModel>> getSpeakers() async {
    final response = await _api.get('${ApiConstants.messages}speakers/');
    if (response.isSuccess) {
      final data = response.data;
      final List<dynamic> speakers = data['speakers'] ?? [];
      return speakers.map((s) => SpeakerModel.fromJson(s)).toList();
    }
    return [];
  }

  // Get recommended messages - Now uses cache-first strategy
  Future<List<Sermon>> getRecommendedMessages({bool forceRefresh = false}) async {
    return await _cacheService.getRecommendedSermons(forceRefresh: forceRefresh);
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
      final response = await _api.post(
        ApiConstants.messageStats,
        {
          'message_id': messageId,
          'action': action,
          'added': added,
        },
      );
      return response.isSuccess;
    } catch (e) {
      return false;
    }
  }

  // Transcripts (standalone)
  Future<List<Transcript>> getTranscripts() async {
    final response = await _api.get(ApiConstants.transcripts);
    if (response.isSuccess) {
      final data = response.data;
      final List<dynamic> results = data is List ? data : (data['results'] ?? data);
      return results.map((json) => Transcript.fromJson(json)).toList();
    }
    return [];
  }

  Future<Transcript?> getTranscriptById(String transcriptId) async {
    final response = await _api.get('${ApiConstants.transcripts}$transcriptId/');
    if (response.isSuccess) {
      return Transcript.fromJson(response.data);
    }
    return null;
  }

  Future<List<Transcript>> getTranscriptsByCategory(String categoryId) async {
    final response = await _api.get('${ApiConstants.transcriptsByCategory}?category_id=$categoryId');
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

  Future<List<Event>> getTeensEvents() async {
    final response = await _api.get(ApiConstants.teensEvents);
    if (response.isSuccess) {
      final List<dynamic> data = response.dataList;
      return data.map((json) => Event.fromJson(json)).toList();
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

  // Teens Content
  Future<List<TeensContent>> getTeensContent() async {
    final response = await _api.get(ApiConstants.teensContent);
    if (response.isSuccess) {
      final data = response.data;
      final List<dynamic> results = data['results'] ?? data;
      return results.map((json) => TeensContent.fromJson(json)).toList();
    }
    return [];
  }

  Future<List<TeensContent>> getDevotionals() async {
    final response = await _api.get(ApiConstants.devotionals);
    debugPrint('Devotionals API URL: ${ApiConstants.baseUrl}${ApiConstants.devotionals}');
    debugPrint('Devotionals API response: ${response.statusCode}');
    debugPrint('Devotionals body: ${response.body}');
    if (response.isSuccess) {
      try {
        final decoded = jsonDecode(response.body);
        debugPrint('Devotionals decoded type: ${decoded.runtimeType}');
        List<dynamic> results;
        if (decoded is List) {
          results = decoded;
        } else if (decoded is Map) {
          results = decoded['results'] ?? decoded['data'] ?? [];
        } else {
          results = [];
        }
        debugPrint('Devotionals results count: ${results.length}');
        return results.map((json) => TeensContent.fromJson(json)).toList();
      } catch (e) {
        debugPrint('Devotionals parse error: $e');
      }
    }
    debugPrint('Devotionals API failed: ${response.errorMessage}');
    return [];
  }

  Future<List<TeensContent>> getRetreats() async {
    final response = await _api.get(ApiConstants.retreats);
    debugPrint('Retreats API URL: ${ApiConstants.baseUrl}${ApiConstants.retreats}');
    debugPrint('Retreats API response: ${response.statusCode}');
    debugPrint('Retreats body: ${response.body}');
    if (response.isSuccess) {
      try {
        final decoded = jsonDecode(response.body);
        debugPrint('Retreats decoded type: ${decoded.runtimeType}');
        List<dynamic> results;
        if (decoded is List) {
          results = decoded;
        } else if (decoded is Map) {
          results = decoded['results'] ?? decoded['data'] ?? [];
        } else {
          results = [];
        }
        debugPrint('Retreats results count: ${results.length}');
        return results.map((json) => TeensContent.fromJson(json)).toList();
      } catch (e) {
        debugPrint('Retreats parse error: $e');
      }
    }
    debugPrint('Retreats API failed: ${response.errorMessage}');
    return [];
  }

  Future<List<TeensContent>> getForgeCamp() async {
    final response = await _api.get(ApiConstants.forgeCamp);
    debugPrint('ForgeCamp API URL: ${ApiConstants.baseUrl}${ApiConstants.forgeCamp}');
    debugPrint('ForgeCamp API response: ${response.statusCode}');
    debugPrint('ForgeCamp body: ${response.body}');
    if (response.isSuccess) {
      try {
        final decoded = jsonDecode(response.body);
        debugPrint('ForgeCamp decoded type: ${decoded.runtimeType}');
        List<dynamic> results;
        if (decoded is List) {
          results = decoded;
        } else if (decoded is Map) {
          results = decoded['results'] ?? decoded['data'] ?? [];
        } else {
          results = [];
        }
        debugPrint('ForgeCamp results count: ${results.length}');
        return results.map((json) => TeensContent.fromJson(json)).toList();
      } catch (e) {
        debugPrint('ForgeCamp parse error: $e');
      }
    }
    debugPrint('ForgeCamp API failed: ${response.errorMessage}');
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

  Future<WalletResult> sendMoney(String recipientEmail, double amount, String pin) async {
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
  
  Future<AppUpdateInfo?> checkForAppUpdate(String currentVersion, String platform) async {
    final response = await _api.get(
      '${ApiConstants.checkAppUpdate}?version=$currentVersion&platform=$platform'
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

  SpeakerModel({
    required this.id,
    required this.name,
    this.title,
    required this.fullName,
    this.bio,
    this.photoUrl,
    this.isActive = true,
  });

  factory SpeakerModel.fromJson(Map<String, dynamic> json) {
    return SpeakerModel(
      id: json['id'],
      name: json['name'] ?? '',
      title: json['title'],
      fullName: json['full_name'] ?? json['name'] ?? '',
      bio: json['bio'],
      photoUrl: json['photo_url'],
      isActive: json['is_active'] ?? true,
    );
  }
}
