import 'package:flutter/foundation.dart';
import '../../data/services/api_service.dart';
import '../constants/api_constants.dart';

class AppConfig {
  final bool walletPageDisabled;
  final String walletPageDisabledMessage;
  final bool teensPageDisabled;
  final String teensPageDisabledMessage;

  AppConfig({
    this.walletPageDisabled = true,
    this.walletPageDisabledMessage = 'Wallet is temporarily disabled as we are working on improvements. Please check back later.',
    this.teensPageDisabled = true,
    this.teensPageDisabledMessage = 'Teens page is temporarily disabled as we are working on improvements. Please check back later.',
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      walletPageDisabled: json['wallet_page_disabled'] ?? false,
      walletPageDisabledMessage: json['wallet_page_disabled_message'] ?? 'Wallet is temporarily disabled as we are working on improvements. Please check back later.',
      teensPageDisabled: json['teens_page_disabled'] ?? false,
      teensPageDisabledMessage: json['teens_page_disabled_message'] ?? 'Teens page is temporarily disabled as we are working on improvements. Please check back later.',
    );
  }
}

class AppConfigProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  AppConfig _config = AppConfig();
  bool _isLoading = false;
  bool _isInitialized = false;

  AppConfig get config => _config;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  Future<void> fetchConfig() async {
    if (_isLoading) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.get(ApiConstants.appConfig);
      if (response.isSuccess) {
        _config = AppConfig.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error fetching app config: $e');
    }

    _isLoading = false;
    _isInitialized = true;
    notifyListeners();
  }
}

