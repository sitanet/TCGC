import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/ask_wing_ai/chat_message_model.dart';
import '../models/ask_wing_ai/ask_wing_ai_response_model.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/auth_service.dart';

/// Abstract interface for Ask Wing AI remote data source
abstract class AskWingAIRemoteDataSource {
  /// Submit a question to Ask Wing AI
  /// 
  /// Returns the response with answer and citations
  Future<AskWingAIResponseModel> submitQuestion(
    String question, {
    List<String>? previousMessageIds,
  });

  /// Get chat history for the current session
  /// 
  /// Supports pagination with limit and offset
  Future<ChatHistoryModel> getChatHistory({
    int limit = 50,
    int offset = 0,
  });

  /// Clear the current chat session history
  Future<void> clearChatHistory();

  /// Get rate limit status for the current user
  Future<RateLimitModel> getRateLimitStatus();

  /// Poll for question processing status
  /// 
  /// Used when the server returns 202 Accepted
  Future<AskWingAIResponseModel> checkQuestionStatus(String messageId);
}

/// Implementation of Ask Wing AI remote data source
class AskWingAIRemoteDataSourceImpl implements AskWingAIRemoteDataSource {
  final http.Client httpClient;
  final AuthService authService;
  final String baseUrl;

  AskWingAIRemoteDataSourceImpl({
    required this.httpClient,
    required this.authService,
    required this.baseUrl,
  });

  @override
  Future<AskWingAIResponseModel> submitQuestion(
    String question, {
    List<String>? previousMessageIds,
  }) async {
    try {
      final token = await authService.getAuthToken();
      if (token == null) {
        throw Exception('Authentication token not available');
      }

      final url = Uri.parse('$baseUrl${ApiConstants.askWingAiQuestionsEndpoint}');

      final requestBody = {
        'question': question,
        if (previousMessageIds != null && previousMessageIds.isNotEmpty)
          'previous_message_ids': previousMessageIds,
      };

      final response = await httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () =>
            throw TimeoutException('Question submission timeout (30s)'),
      );

      if (response.statusCode == 202) {
        // Async processing - need to poll
        final status = QuestionStatusModel.fromJson(
          jsonDecode(response.body),
        );
        // Wait a bit and then poll
        await _pollForCompletion(status.messageId);
        // Return a placeholder - real implementation would handle WebSocket
        throw Exception('Question submitted, check status');
      } else if (response.statusCode == 200) {
        return AskWingAIResponseModel.fromJson(
          jsonDecode(response.body),
        );
      } else if (response.statusCode == 401) {
        throw UnauthorizedException('Authentication failed');
      } else if (response.statusCode == 429) {
        throw RateLimitExceededException(
          'Daily question limit exceeded. Please try again tomorrow.',
        );
      } else {
        final error = jsonDecode(response.body);
        throw Exception(
          error['error'] ?? 'Failed to submit question (${response.statusCode})',
        );
      }
    } on SocketException catch (e) {
      throw NetworkException('Network error: ${e.message}');
    } on TimeoutException catch (e) {
      throw TimeoutException(e.message ?? 'Request timeout');
    } on Exception {
      rethrow;
    }
  }

  @override
  Future<ChatHistoryModel> getChatHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final token = await authService.getAuthToken();
      if (token == null) {
        throw Exception('Authentication token not available');
      }

      final url = Uri.parse(
        '$baseUrl${ApiConstants.askWingAiHistoryEndpoint}?limit=$limit&offset=$offset',
      );

      final response = await httpClient.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () =>
            throw TimeoutException('History retrieval timeout (15s)'),
      );

      if (response.statusCode == 200) {
        return ChatHistoryModel.fromJson(
          jsonDecode(response.body),
        );
      } else if (response.statusCode == 401) {
        throw UnauthorizedException('Authentication failed');
      } else {
        throw Exception(
          'Failed to retrieve chat history (${response.statusCode})',
        );
      }
    } on SocketException catch (e) {
      throw NetworkException('Network error: ${e.message}');
    } on TimeoutException catch (e) {
      throw TimeoutException(e.message ?? 'Request timeout');
    } on Exception {
      rethrow;
    }
  }

  @override
  Future<void> clearChatHistory() async {
    try {
      final token = await authService.getAuthToken();
      if (token == null) {
        throw Exception('Authentication token not available');
      }

      final url = Uri.parse(
        '$baseUrl${ApiConstants.askWingAiClearEndpoint}',
      );

      final response = await httpClient.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            throw TimeoutException('Clear history timeout (10s)'),
      );

      if (response.statusCode != 200) {
        if (response.statusCode == 401) {
          throw UnauthorizedException('Authentication failed');
        }
        throw Exception('Failed to clear chat history (${response.statusCode})');
      }
    } on SocketException catch (e) {
      throw NetworkException('Network error: ${e.message}');
    } on TimeoutException catch (e) {
      throw TimeoutException(e.message ?? 'Request timeout');
    } on Exception {
      rethrow;
    }
  }

  @override
  Future<RateLimitModel> getRateLimitStatus() async {
    try {
      final token = await authService.getAuthToken();
      if (token == null) {
        throw Exception('Authentication token not available');
      }

      final url = Uri.parse(
        '$baseUrl${ApiConstants.askWingAiLimitsEndpoint}',
      );

      final response = await httpClient.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            throw TimeoutException('Rate limit check timeout (10s)'),
      );

      if (response.statusCode == 200) {
        return RateLimitModel.fromJson(
          jsonDecode(response.body),
        );
      } else if (response.statusCode == 401) {
        throw UnauthorizedException('Authentication failed');
      } else {
        throw Exception(
          'Failed to get rate limit status (${response.statusCode})',
        );
      }
    } on SocketException catch (e) {
      throw NetworkException('Network error: ${e.message}');
    } on TimeoutException catch (e) {
      throw TimeoutException(e.message ?? 'Request timeout');
    } on Exception {
      rethrow;
    }
  }

  @override
  Future<AskWingAIResponseModel> checkQuestionStatus(String messageId) async {
    try {
      final token = await authService.getAuthToken();
      if (token == null) {
        throw Exception('Authentication token not available');
      }

      final url = Uri.parse(
        '$baseUrl${ApiConstants.askWingAiStatusEndpoint}/$messageId',
      );

      final response = await httpClient.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            throw TimeoutException('Status check timeout (10s)'),
      );

      if (response.statusCode == 200) {
        return AskWingAIResponseModel.fromJson(
          jsonDecode(response.body),
        );
      } else if (response.statusCode == 202) {
        // Still processing
        throw ProcessingException('Question still being processed');
      } else if (response.statusCode == 401) {
        throw UnauthorizedException('Authentication failed');
      } else {
        throw Exception('Failed to check status (${response.statusCode})');
      }
    } on SocketException catch (e) {
      throw NetworkException('Network error: ${e.message}');
    } on TimeoutException catch (e) {
      throw TimeoutException(e.message ?? 'Request timeout');
    } on Exception {
      rethrow;
    }
  }

  /// Poll for question completion with exponential backoff
  Future<void> _pollForCompletion(String messageId,
      {int maxAttempts = 120, int initialDelayMs = 500}) async {
    int attempts = 0;
    int delayMs = initialDelayMs;

    while (attempts < maxAttempts) {
      try {
        await Future.delayed(Duration(milliseconds: delayMs));
        final response = await checkQuestionStatus(messageId);
        // Response received, polling complete
        return;
      } on ProcessingException {
        attempts++;
        delayMs = (delayMs * 1.5).toInt();
        if (delayMs > 5000) delayMs = 5000; // Max 5 second delay
        continue;
      } catch (e) {
        // Other error, rethrow
        rethrow;
      }
    }

    throw TimeoutException('Question processing timeout after ${attempts}s');
  }
}

// Custom Exceptions
class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);

  @override
  String toString() => 'UnauthorizedException: $message';
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

class RateLimitExceededException implements Exception {
  final String message;
  RateLimitExceededException(this.message);

  @override
  String toString() => 'RateLimitExceededException: $message';
}

class ProcessingException implements Exception {
  final String message;
  ProcessingException(this.message);

  @override
  String toString() => 'ProcessingException: $message';
}

class TimeoutException implements Exception {
  final String? message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: ${message ?? 'Request timeout'}';
}

class SocketException implements Exception {
  final String message;
  SocketException(this.message);

  @override
  String toString() => 'SocketException: $message';
}
