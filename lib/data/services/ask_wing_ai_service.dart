import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ask_wing_ai/ask_wing_ai_response_model.dart';
import '../models/ask_wing_ai/chat_message_model.dart';
import '../../core/services/token_service.dart';
import '../../core/constants/api_constants.dart';

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
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/api/ask-wing-ai/feature-status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return FeatureStatusModel.fromJson(data);
      }

      // Default to enabled on error to avoid blocking users
      return FeatureStatusModel(isEnabled: true, message: null);
    } catch (e) {
      print('Error checking feature status: $e');
      // Default to enabled on error
      return FeatureStatusModel(isEnabled: true, message: null);
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
        throw Exception('No authentication token found');
      }

      final body = {
        'question': question,
        if (previousMessageIds != null && previousMessageIds.isNotEmpty)
          'previous_message_ids': previousMessageIds,
        if (sessionId != null) 'session_id': sessionId,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/api/ask-wing-ai/questions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return AskWingAIResponseModel.fromJson(data);
      } else if (response.statusCode == 429) {
        // Rate limit exceeded
        final data = json.decode(response.body) as Map<String, dynamic>;
        throw RateLimitException(data['message'] as String? ?? 'Rate limit exceeded');
      } else if (response.statusCode == 503) {
        // Feature disabled
        final data = json.decode(response.body) as Map<String, dynamic>;
        throw FeatureDisabledException(data['message'] as String? ?? 'Feature unavailable');
      } else {
        final data = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(data['message'] ?? data['error'] ?? 'Failed to submit question');
      }
    } catch (e) {
      if (e is RateLimitException || e is FeatureDisabledException) {
        rethrow;
      }
      throw Exception('Failed to submit question: $e');
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
        throw Exception('No authentication token found');
      }

      final queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
        if (sessionId != null) 'session_id': sessionId,
      };

      final uri = Uri.parse('$_baseUrl/api/ask-wing-ai/history')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ChatHistoryResponse.fromJson(data);
      } else {
        throw Exception('Failed to load chat history');
      }
    } catch (e) {
      throw Exception('Failed to load chat history: $e');
    }
  }

  /// Clear chat history
  Future<void> clearChatHistory({String? sessionId}) async {
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final body = sessionId != null ? {'session_id': sessionId} : null;

      final response = await http.post(
        Uri.parse('$_baseUrl/api/ask-wing-ai/clear'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body != null ? json.encode(body) : null,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to clear chat history');
      }
    } catch (e) {
      throw Exception('Failed to clear chat history: $e');
    }
  }

  /// Get rate limit status
  Future<RateLimitStatus> getRateLimitStatus() async {
    try {
      final token = await _tokenService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/api/ask-wing-ai/limits'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return RateLimitStatus.fromJson(data);
      } else {
        throw Exception('Failed to get rate limit status');
      }
    } catch (e) {
      throw Exception('Failed to get rate limit status: $e');
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
