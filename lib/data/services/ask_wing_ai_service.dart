import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/ask_wing_ai/ask_wing_ai_response_model.dart';
import '../models/ask_wing_ai/chat_message_model.dart';
import '../../core/services/token_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/error_handler.dart';

class AskWingAIService {
  final TokenService _tokenService;
  final String _baseUrl;

  AskWingAIService({
    required TokenService tokenService,
    String? baseUrl,
  })  : _tokenService = tokenService,
        _baseUrl = baseUrl ?? ApiConstants.baseUrl;

  /// Check if Ask Wing AI feature is enabled
  Future<FeatureStatusModel> checkFeatureStatus() async {
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        // Default to enabled if no token - will fail on actual question submission
        return const FeatureStatusModel(isEnabled: true, message: null);
      }

      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/ask-wing-ai/feature-status/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          return FeatureStatusModel.fromJson(data);
        }
      } catch (e) {
        print('Error calling feature status endpoint: $e');
      }

      // Default to enabled on error to avoid blocking users
      // The actual feature availability will be checked on first question submission
      return const FeatureStatusModel(isEnabled: true, message: null);
    } catch (e) {
      print('Error checking feature status: $e');
      // Default to enabled on error
      return const FeatureStatusModel(isEnabled: true, message: null);
    }
  }

  /// Submit a question to Ask Wing AI
  Future<AskWingAIResponseModel> submitQuestion({
    required String question,
    List<int>? previousMessageIds,
    String? sessionId,
  }) async {
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        throw Exception('No authentication token found. Please log in again.');
      }

      final body = {
        'question': question,
        if (previousMessageIds != null && previousMessageIds.isNotEmpty)
          'previous_message_ids': previousMessageIds,
        if (sessionId != null) 'session_id': sessionId,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/ask-wing-ai/questions/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      ).timeout(const Duration(seconds: 75));

      if (response.statusCode == 200 || response.statusCode == 202) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return AskWingAIResponseModel.fromJson(data);
      } else if (response.statusCode == 429) {
        // Rate limit exceeded
        final data = json.decode(response.body) as Map<String, dynamic>;
        throw RateLimitException(data['message'] as String? ?? 'Daily question limit reached');
      } else if (response.statusCode == 503) {
        // Feature disabled
        final data = json.decode(response.body) as Map<String, dynamic>;
        throw FeatureDisabledException(data['message'] as String? ?? 'Ask Wing AI is temporarily unavailable');
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final errorMessage = data['message'] ?? data['error'] ?? 'Failed to submit question';
        throw Exception(ErrorHandler.getErrorMessage(Exception(errorMessage)));
      }
    } on RateLimitException {
      rethrow;
    } on FeatureDisabledException {
      rethrow;
    } catch (e) {
      // Surface the real error instead of hiding it with a mock response
      debugPrint('Wing AI submitQuestion error: $e');
      throw Exception(ErrorHandler.getErrorMessage(e));
    }
  }

  /// Get chat history with pagination
  Future<ChatHistoryResponse> getChatHistory({
    int limit = 50,
    int offset = 0,
    String? sessionId,
  }) async {
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        // Return empty history if no token
        return ChatHistoryResponse(
          messages: [],
          total: 0,
          hasMore: false,
          sessionId: sessionId,
        );
      }

      final queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
        if (sessionId != null) 'session_id': sessionId,
      };

      final uri = Uri.parse('$_baseUrl/ask-wing-ai/history/')
          .replace(queryParameters: queryParams);

      try {
        final response = await http.get(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          return ChatHistoryResponse.fromJson(data);
        }
      } catch (e) {
        print('Error loading chat history: $e');
      }

      // Return empty history on error
      return ChatHistoryResponse(
        messages: [],
        total: 0,
        hasMore: false,
        sessionId: sessionId,
      );
    } catch (e) {
      print('Error loading chat history: $e');
      return ChatHistoryResponse(
        messages: [],
        total: 0,
        hasMore: false,
        sessionId: sessionId,
      );
    }
  }

  /// Clear chat history
  Future<void> clearChatHistory({String? sessionId}) async {
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        // No token (unauthenticated/guest) - nothing to clear on backend
        return;
      }

      final body = sessionId != null ? {'session_id': sessionId} : <String, dynamic>{};

      final response = await http.post(
        Uri.parse('$_baseUrl/ask-wing-ai/clear/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      // If POST /clear/ returned 404 or 405, also attempt DELETE /history/
      if (response.statusCode == 404 || response.statusCode == 405) {
        final deleteUri = Uri.parse('$_baseUrl/ask-wing-ai/history/').replace(
          queryParameters: sessionId != null ? {'session_id': sessionId} : null,
        );
        final delResponse = await http.delete(
          deleteUri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 8));
        if (delResponse.statusCode >= 200 && delResponse.statusCode < 300) {
          return;
        }
      }

      debugPrint('clearChatHistory server responded with status: ${response.statusCode}');
    } catch (e) {
      debugPrint('clearChatHistory network/backend error: $e');
    }
  }
  /// Get rate limit status
  Future<RateLimitModel> getRateLimitStatus() async {
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        // Return default rate limit if no token
        return RateLimitModel(
          dailyLimit: 50,
          dailyUsed: 0,
          dailyRemaining: 50,
          resetTime: DateTime.now().add(const Duration(days: 1)),
        );
      }

      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/ask-wing-ai/limits/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          return RateLimitModel.fromJson(data);
        }
      } catch (e) {
        print('Error calling rate limit endpoint: $e');
      }

      // Return default rate limit on error
      return RateLimitModel(
        dailyLimit: 50,
        dailyUsed: 0,
        dailyRemaining: 50,
        resetTime: DateTime.now().add(const Duration(days: 1)),
      );
    } catch (e) {
      print('Error getting rate limit status: $e');
      // Return default rate limit on error
      return RateLimitModel(
        dailyLimit: 50,
        dailyUsed: 0,
        dailyRemaining: 50,
        resetTime: DateTime.now().add(const Duration(days: 1)),
      );
    }
  }
}

/// Chat history response model
class ChatHistoryResponse {
  final List<ChatMessageModel> messages;
  final int total;
  final bool hasMore;
  final String? sessionId;

  ChatHistoryResponse({
    required this.messages,
    required this.total,
    required this.hasMore,
    this.sessionId,
  });

  factory ChatHistoryResponse.fromJson(Map<String, dynamic> json) {
    return ChatHistoryResponse(
      messages: (json['messages'] as List<dynamic>)
          .map((m) => ChatMessageModel.fromJson(m as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      hasMore: json['has_more'] as bool,
      sessionId: json['session_id'] as String?,
    );
  }
}

/// Custom exceptions
class RateLimitException implements Exception {
  final String message;
  RateLimitException(this.message);

  @override
  String toString() => message;
}

class FeatureDisabledException implements Exception {
  final String message;
  FeatureDisabledException(this.message);

  @override
  String toString() => message;
}
