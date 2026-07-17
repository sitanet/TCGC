import 'package:equatable/equatable.dart';
import 'chat_message_model.dart';

/// Represents the status of the Ask Wing AI feature
class FeatureStatusModel extends Equatable {
  final bool isEnabled;
  final String? message;

  const FeatureStatusModel({
    required this.isEnabled,
    this.message,
  });

  /// Create from JSON response
  factory FeatureStatusModel.fromJson(Map<String, dynamic> json) {
    return FeatureStatusModel(
      isEnabled: json['is_enabled'] ?? json['enabled'] ?? true,
      message: json['message'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'is_enabled': isEnabled,
      'message': message,
    };
  }

  @override
  List<Object?> get props => [isEnabled, message];
}

/// Represents the response from Ask Wing AI backend API
class AskWingAIResponseModel extends Equatable {
  final String messageId;
  final String question;
  final String response;
  final List<CitationModel> citations;
  final int processingTimeMs;
  final DateTime timestamp;
  final String? error;
  final String? sessionId;
  final RateLimitModel? rateLimit;

  const AskWingAIResponseModel({
    required this.messageId,
    required this.question,
    required this.response,
    required this.citations,
    required this.processingTimeMs,
    required this.timestamp,
    this.error,
    this.sessionId,
    this.rateLimit,
  });

  /// Create from JSON response from backend
  factory AskWingAIResponseModel.fromJson(Map<String, dynamic> json) {
    return AskWingAIResponseModel(
      messageId: (json['message_id'] ?? '').toString(),
      question: json['question'] ?? '',
      response: json['response'] ?? '',
      citations: (json['citations'] as List<dynamic>?)
              ?.map((c) => CitationModel.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      processingTimeMs: json['processing_time_ms'] ?? 0,
      timestamp: DateTime.parse(
          json['timestamp'] ?? DateTime.now().toIso8601String()),
      error: json['error'],
      sessionId: json['session_id'] as String?,
      rateLimit: json['rate_limit'] != null 
          ? RateLimitModel.fromJson(json['rate_limit'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Convert to JSON for storage or debugging
  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'question': question,
      'response': response,
      'citations': citations.map((c) => c.toJson()).toList(),
      'processing_time_ms': processingTimeMs,
      'timestamp': timestamp.toIso8601String(),
      'error': error,
      'session_id': sessionId,
      'rate_limit': rateLimit?.toJson(),
    };
  }

  @override
  List<Object?> get props => [
        messageId,
        question,
        response,
        citations,
        processingTimeMs,
        timestamp,
        error,
        sessionId,
        rateLimit,
      ];
}

/// Represents the rate limit status from backend
class RateLimitModel extends Equatable {
  final int dailyLimit;
  final int dailyUsed;
  final int dailyRemaining;
  final DateTime resetTime;

  const RateLimitModel({
    required this.dailyLimit,
    required this.dailyUsed,
    required this.dailyRemaining,
    required this.resetTime,
  });

  /// Check if at limit
  bool get isAtLimit => dailyRemaining <= 0;

  /// Check if near limit (within 5 questions)
  bool get isNearLimit => dailyRemaining > 0 && dailyRemaining <= 5;

  /// Check if user can ask more questions
  bool get canAsk => dailyRemaining > 0;

  /// Get usage percentage (0.0 to 1.0)
  double get usagePercentage => dailyUsed / dailyLimit;

  /// Create from JSON response
  factory RateLimitModel.fromJson(Map<String, dynamic> json) {
    return RateLimitModel(
      dailyLimit: json['daily_limit'] ?? 50,
      dailyUsed: json['daily_used'] ?? 0,
      dailyRemaining: json['daily_remaining'] ?? 50,
      resetTime: DateTime.parse(
          json['reset_time'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'daily_limit': dailyLimit,
      'daily_used': dailyUsed,
      'daily_remaining': dailyRemaining,
      'reset_time': resetTime.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        dailyLimit,
        dailyUsed,
        dailyRemaining,
        resetTime,
      ];
}

/// Alias for backward compatibility
typedef RateLimitStatus = RateLimitModel;

/// Represents chat history from backend
class ChatHistoryModel extends Equatable {
  final List<ChatMessageModel> messages;
  final int total;
  final bool hasMore;

  const ChatHistoryModel({
    required this.messages,
    required this.total,
    required this.hasMore,
  });

  /// Create from JSON response
  factory ChatHistoryModel.fromJson(Map<String, dynamic> json) {
    return ChatHistoryModel(
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) => ChatMessageModel.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] ?? 0,
      hasMore: json['has_more'] ?? false,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'messages': messages.map((m) => m.toJson()).toList(),
      'total': total,
      'has_more': hasMore,
    };
  }

  @override
  List<Object?> get props => [messages, total, hasMore];
}

/// Represents the status of a question submission
class QuestionStatusModel extends Equatable {
  final String messageId;
  final QuestionProcessingStatus status;
  final DateTime timestamp;
  final String? error;

  const QuestionStatusModel({
    required this.messageId,
    required this.status,
    required this.timestamp,
    this.error,
  });

  /// Create from JSON response
  factory QuestionStatusModel.fromJson(Map<String, dynamic> json) {
    return QuestionStatusModel(
      messageId: json['message_id'] ?? '',
      status: QuestionProcessingStatus.fromValue(
          json['status'] ?? 'processing'),
      timestamp: DateTime.parse(
          json['timestamp'] ?? DateTime.now().toIso8601String()),
      error: json['error'],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'status': status.value,
      'timestamp': timestamp.toIso8601String(),
      'error': error,
    };
  }

  @override
  List<Object?> get props => [messageId, status, timestamp, error];
}

/// Enum for question processing status
enum QuestionProcessingStatus {
  processing('processing'),
  completed('completed'),
  failed('failed');

  final String value;
  const QuestionProcessingStatus(this.value);

  factory QuestionProcessingStatus.fromValue(String value) {
    return QuestionProcessingStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => QuestionProcessingStatus.processing,
    );
  }
}
