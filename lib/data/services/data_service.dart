import '../../core/constants/api_constants.dart';
import '../../domain/entities/sermon.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/teens_content.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/promotion.dart';
import 'api_service.dart';

class DataService {
  final ApiService _api = ApiService();

  // Message Categories
  Future<List<MessageCategory>> getMessageCategories() async {
    final response = await _api.get(ApiConstants.messageCategories);
    if (response.isSuccess) {
      final decoded = response.data;
      // Handle both paginated and non-paginated responses
      final List<dynamic> data = decoded is List ? decoded : (decoded['results'] ?? decoded);
      return data.map((json) => MessageCategory.fromJson(json)).toList();
    }
    return [];
  }

  // Messages/Sermons
  Future<List<Sermon>> getMessages() async {
    final response = await _api.get(ApiConstants.messages);
    if (response.isSuccess) {
      final data = response.data;
      final List<dynamic> results = data['results'] ?? data;
      return results.map((json) => Sermon.fromJson(json)).toList();
    }
    return [];
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

  // Events
  Future<List<Event>> getEvents() async {
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
    if (response.isSuccess) {
      final List<dynamic> data = response.dataList;
      return data.map((json) => TeensContent.fromJson(json)).toList();
    }
    return [];
  }

  Future<List<TeensContent>> getRetreats() async {
    final response = await _api.get(ApiConstants.retreats);
    if (response.isSuccess) {
      final List<dynamic> data = response.dataList;
      return data.map((json) => TeensContent.fromJson(json)).toList();
    }
    return [];
  }

  Future<List<TeensContent>> getForgeCamp() async {
    final response = await _api.get(ApiConstants.forgeCamp);
    if (response.isSuccess) {
      final List<dynamic> data = response.dataList;
      return data.map((json) => TeensContent.fromJson(json)).toList();
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
