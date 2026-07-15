import 'package:equatable/equatable.dart';
import '../../../data/models/ask_wing_ai/chat_message_model.dart';
import '../../../data/models/ask_wing_ai/ask_wing_ai_response_model.dart';

/// Base state for Ask Wing AI
abstract class AskWingAIState extends Equatable {
  const AskWingAIState();

  @override
  List<Object?> get props => [];
}

/// Initial state - chat interface not opened
class AskWingAIInitial extends AskWingAIState {
  const AskWingAIInitial();
}

/// Loading state - waiting for response from server
class AskWingAILoading extends AskWingAIState {
  final List<ChatMessageModel> messages;
  final String currentQuestion;

  const AskWingAILoading({
    required this.messages,
    required this.currentQuestion,
  });

  @override
  List<Object?> get props => [messages, currentQuestion];
}

/// Success state - response received and displayed
class AskWingAISuccess extends AskWingAIState {
  final List<ChatMessageModel> messages;
  final int dailyQuestionsRemaining;
  final int dailyQuestionsLimit;

  const AskWingAISuccess({
    required this.messages,
    required this.dailyQuestionsRemaining,
    required this.dailyQuestionsLimit,
  });

  @override
  List<Object?> get props => [
        messages,
        dailyQuestionsRemaining,
        dailyQuestionsLimit,
      ];

  /// Create a copy with updated fields
  AskWingAISuccess copyWith({
    List<ChatMessageModel>? messages,
    int? dailyQuestionsRemaining,
    int? dailyQuestionsLimit,
  }) {
    return AskWingAISuccess(
      messages: messages ?? this.messages,
      dailyQuestionsRemaining:
          dailyQuestionsRemaining ?? this.dailyQuestionsRemaining,
      dailyQuestionsLimit: dailyQuestionsLimit ?? this.dailyQuestionsLimit,
    );
  }
}

/// Error state - something went wrong
class AskWingAIError extends AskWingAIState {
  final String message;
  final List<ChatMessageModel> previousMessages;
  final String? errorCode;
  final bool isRateLimited;
  final bool isNetworkError;
  final bool isAuthenticationError;

  const AskWingAIError({
    required this.message,
    required this.previousMessages,
    this.errorCode,
    this.isRateLimited = false,
    this.isNetworkError = false,
    this.isAuthenticationError = false,
  });

  @override
  List<Object?> get props => [
        message,
        previousMessages,
        errorCode,
        isRateLimited,
        isNetworkError,
        isAuthenticationError,
      ];
}

/// Rate limit exceeded state
class AskWingAIRateLimited extends AskWingAIState {
  final String message;
  final List<ChatMessageModel> messages;
  final int dailyLimit;
  final DateTime resetTime;

  const AskWingAIRateLimited({
    required this.message,
    required this.messages,
    required this.dailyLimit,
    required this.resetTime,
  });

  @override
  List<Object?> get props => [message, messages, dailyLimit, resetTime];
}

/// Authentication required state
class AskWingAIAuthenticationRequired extends AskWingAIState {
  final String message;

  const AskWingAIAuthenticationRequired({
    this.message = 'Please log in to use Ask Wing AI',
  });

  @override
  List<Object?> get props => [message];
}

/// History cleared state
class AskWingAIHistoryCleared extends AskWingAIState {
  final List<ChatMessageModel> emptyMessages;

  const AskWingAIHistoryCleared({
    this.emptyMessages = const [],
  });

  @override
  List<Object?> get props => [emptyMessages];
}
