import '../../data/services/api_service.dart';

/// Simple token service that wraps ApiService for Ask Wing AI integration
class TokenService {
  final ApiService _apiService;

  TokenService({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  /// Get the current access token
  Future<String?> getToken() async {
    await _apiService.loadTokens();
    return _apiService.accessToken;
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _apiService.isAuthenticated;

  /// Clear tokens (logout)
  Future<void> clearTokens() async {
    await _apiService.clearTokens();
  }
}