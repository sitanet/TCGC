import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';

// Top-level function for compute isolate - parses JSON in background
List<dynamic> _parseJsonList(String body) {
  final decoded = jsonDecode(body);
  if (decoded is List) return decoded;
  if (decoded is Map) {
    return decoded['results'] ?? decoded['data'] ?? [];
  }
  return [];
}

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
      print('ApiService POST: ${ApiConstants.baseUrl}$endpoint');
      var response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}$endpoint'),
        headers: _headers,
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 60));

      print('ApiService POST response: ${response.statusCode}');

      if (response.statusCode == 401 && await _refreshAccessToken()) {
        response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}$endpoint'),
          headers: _headers,
          body: jsonEncode(data),
        ).timeout(const Duration(seconds: 60));
      }

      return ApiResponse(
        statusCode: response.statusCode,
        body: response.body,
        isSuccess: response.statusCode >= 200 && response.statusCode < 300,
      );
    } catch (e) {
      print('ApiService POST error: $e');
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

  /// Fetches all pages from a paginated endpoint and returns combined results
  /// Uses compute isolate for JSON parsing to prevent UI jank
  Future<List<dynamic>> getAllPages(String endpoint) async {
    final allResults = <dynamic>[];
    String? nextUrl = '${ApiConstants.baseUrl}$endpoint';
    int pageCount = 0;
    const maxPages = 50; // Safety limit to prevent infinite loops
    
    while (nextUrl != null && pageCount < maxPages) {
      pageCount++;
      try {
        var response = await http.get(
          Uri.parse(nextUrl),
          headers: _headers,
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 401 && await _refreshAccessToken()) {
          response = await http.get(
            Uri.parse(nextUrl),
            headers: _headers,
          ).timeout(const Duration(seconds: 30));
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          // Parse JSON in isolate to prevent main thread blocking
          final results = await compute(_parseJsonList, response.body);
          allResults.addAll(results);
          
          // Check for next page
          try {
            final decoded = jsonDecode(response.body);
            nextUrl = (decoded is Map) ? decoded['next'] : null;
          } catch (_) {
            nextUrl = null;
          }
        } else {
          break;
        }
      } catch (e) {
        debugPrint('Error fetching page $pageCount: $e');
        break;
      }
    }
    
    return allResults;
  }

  Future<ApiResponse> uploadFile(
    String endpoint,
    File file, {
    String fieldName = 'file',
    Map<String, String>? additionalFields,
  }) async {
    try {
      var request = http.MultipartRequest(
        'PATCH',
        Uri.parse('${ApiConstants.baseUrl}$endpoint'),
      );

      // Add authorization header
      if (_accessToken != null) {
        request.headers['Authorization'] = 'Bearer $_accessToken';
      }

      // Add the file
      request.files.add(
        await http.MultipartFile.fromPath(fieldName, file.path),
      );

      // Add additional fields if any
      if (additionalFields != null) {
        request.fields.addAll(additionalFields);
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      // Handle token refresh
      if (response.statusCode == 401 && await _refreshAccessToken()) {
        request = http.MultipartRequest(
          'PATCH',
          Uri.parse('${ApiConstants.baseUrl}$endpoint'),
        );
        request.headers['Authorization'] = 'Bearer $_accessToken';
        request.files.add(
          await http.MultipartFile.fromPath(fieldName, file.path),
        );
        if (additionalFields != null) {
          request.fields.addAll(additionalFields);
        }
        streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
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

  Future<ApiResponse> postMultipart(
    String endpoint, {
    required Map<String, String> fields,
    Map<String, File>? files,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConstants.baseUrl}$endpoint'),
      );

      if (_accessToken != null) {
        request.headers['Authorization'] = 'Bearer $_accessToken';
      }

      request.fields.addAll(fields);

      if (files != null) {
        for (var entry in files.entries) {
          request.files.add(
            await http.MultipartFile.fromPath(entry.key, entry.value.path),
          );
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401 && await _refreshAccessToken()) {
        request = http.MultipartRequest(
          'POST',
          Uri.parse('${ApiConstants.baseUrl}$endpoint'),
        );
        request.headers['Authorization'] = 'Bearer $_accessToken';
        request.fields.addAll(fields);
        if (files != null) {
          for (var entry in files.entries) {
            request.files.add(
              await http.MultipartFile.fromPath(entry.key, entry.value.path),
            );
          }
        }
        streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
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
  
  /// Check if response has pagination info
  bool get hasPagination {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map && decoded.containsKey('next');
    } catch (_) {
      return false;
    }
  }
  
  /// Get next page URL from paginated response
  String? get nextPageUrl {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return decoded['next'];
      }
    } catch (_) {}
    return null;
  }
  
  /// Get results list from paginated response
  List<dynamic> get paginatedResults {
    try {
      final decoded = jsonDecode(body);
      if (decoded is List) return decoded;
      if (decoded is Map) {
        return decoded['results'] ?? decoded['data'] ?? [];
      }
    } catch (_) {}
    return [];
  }
}
