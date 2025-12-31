import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _accessToken;
  String? _refreshToken;

  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
  }

  Future<void> saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
    _accessToken = access;
    _refreshToken = refresh;
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    _accessToken = null;
    _refreshToken = null;
  }

  bool get isAuthenticated => _accessToken != null;
  String? get accessToken => _accessToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;
    
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.refreshToken}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': _refreshToken}),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveTokens(data['access'], _refreshToken!);
        return true;
      }
    } catch (e) {
      // Token refresh failed
    }
    return false;
  }

  Future<ApiResponse> get(String endpoint) async {
    try {
      var response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}$endpoint'),
        headers: _headers,
      );

      if (response.statusCode == 401 && await _refreshAccessToken()) {
        response = await http.get(
          Uri.parse('${ApiConstants.baseUrl}$endpoint'),
          headers: _headers,
        );
      }

      return ApiResponse(
        statusCode: response.statusCode,
        body: response.body,
        isSuccess: response.statusCode >= 200 && response.statusCode < 300,
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 0,
        body: jsonEncode({'error': e.toString()}),
        isSuccess: false,
      );
    }
  }

  Future<ApiResponse> post(String endpoint, Map<String, dynamic> data) async {
    try {
      var response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}$endpoint'),
        headers: _headers,
        body: jsonEncode(data),
      );

      if (response.statusCode == 401 && await _refreshAccessToken()) {
        response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}$endpoint'),
          headers: _headers,
          body: jsonEncode(data),
        );
      }

      return ApiResponse(
        statusCode: response.statusCode,
        body: response.body,
        isSuccess: response.statusCode >= 200 && response.statusCode < 300,
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 0,
        body: jsonEncode({'error': e.toString()}),
        isSuccess: false,
      );
    }
  }

  Future<ApiResponse> put(String endpoint, Map<String, dynamic> data) async {
    try {
      var response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}$endpoint'),
        headers: _headers,
        body: jsonEncode(data),
      );

      if (response.statusCode == 401 && await _refreshAccessToken()) {
        response = await http.put(
          Uri.parse('${ApiConstants.baseUrl}$endpoint'),
          headers: _headers,
          body: jsonEncode(data),
        );
      }

      return ApiResponse(
        statusCode: response.statusCode,
        body: response.body,
        isSuccess: response.statusCode >= 200 && response.statusCode < 300,
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 0,
        body: jsonEncode({'error': e.toString()}),
        isSuccess: false,
      );
    }
  }

  Future<ApiResponse> patch(String endpoint, Map<String, dynamic> data) async {
    try {
      var response = await http.patch(
        Uri.parse('${ApiConstants.baseUrl}$endpoint'),
        headers: _headers,
        body: jsonEncode(data),
      );

      if (response.statusCode == 401 && await _refreshAccessToken()) {
        response = await http.patch(
          Uri.parse('${ApiConstants.baseUrl}$endpoint'),
          headers: _headers,
          body: jsonEncode(data),
        );
      }

      return ApiResponse(
        statusCode: response.statusCode,
        body: response.body,
        isSuccess: response.statusCode >= 200 && response.statusCode < 300,
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 0,
        body: jsonEncode({'error': e.toString()}),
        isSuccess: false,
      );
    }
  }

  Future<ApiResponse> delete(String endpoint) async {
    try {
      var response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}$endpoint'),
        headers: _headers,
      );

      if (response.statusCode == 401 && await _refreshAccessToken()) {
        response = await http.delete(
          Uri.parse('${ApiConstants.baseUrl}$endpoint'),
          headers: _headers,
        );
      }

      return ApiResponse(
        statusCode: response.statusCode,
        body: response.body,
        isSuccess: response.statusCode >= 200 && response.statusCode < 300,
      );
    } catch (e) {
      return ApiResponse(
        statusCode: 0,
        body: jsonEncode({'error': e.toString()}),
        isSuccess: false,
      );
    }
  }
}

class ApiResponse {
  final int statusCode;
  final String body;
  final bool isSuccess;

  ApiResponse({
    required this.statusCode,
    required this.body,
    required this.isSuccess,
  });

  Map<String, dynamic> get data => jsonDecode(body);
  List<dynamic> get dataList => jsonDecode(body);
  String? get errorMessage {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return decoded['error'] ?? decoded['detail'] ?? decoded['message'];
      }
    } catch (_) {}
    return null;
  }
}
