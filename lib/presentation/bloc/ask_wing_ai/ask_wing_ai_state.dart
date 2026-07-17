import 'package:equatable/equatable.dart';
import '../../../data/models/ask_wing_ai/chat_message_model.dart';
import '../../../data/models/ask_wing_ai/ask_wing_ai_response_model.dart';

// Use RateLimitStatus alias from ask_wing_ai_response_model
typedef RateLimitStatusAlias = RateLimitStatus;

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

/// Feature check loading state
class AskWingAIFeatureCheckLoading extends AskWingAIState {
  const AskWingAIFeatureCheckLoading();
}

/// Feature disabled state
class AskWingAIFeatureDisabled extends AskWingAIState {
  final String message;

  const AskWingAIFeatureDisabled(this.message);

  @override
  List<Object?> get props => [message];
}

/// Ready state - feature is enabled and ready to use
class AskWingAIReady extends AskWingAIState {
  final List<ChatMessageModel> messages;
  final RateLimitModel? rateLimitStatus;
  final String? sessionId;

  const AskWingAIReady({
    required this.messages,
    this.rateLimitStatus,
    this.sessionId,
  });

  @override
  List<Object?> get props => [messages, rateLimitStatus, sessionId];

  /// Create a copy with updated fields
  AskWingAIReady copyWith({
    List<ChatMessageModel>? messages,
    RateLimitModel? rateLimitStatus,
    String? sessionId,
  }) {
    return AskWingAIReady(
      messages: messages ?? this.messages,
      rateLimitStatus: rateLimitStatus ?? this.rateLimitStatus,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}

/// Question submitting state
class AskWingAIQuestionSubmitting extends AskWingAIState {
  final List<ChatMessageModel> previousMessages;
  final String question;

  const AskWingAIQuestionSubmitting({
    required this.previousMessages,
    required this.question,
  });

  @override
  List<Object?> get props => [previousMessages, question];
}

/// Question success state
class AskWingAIQuestionSuccess extends AskWingAIState {
  final List<ChatMessageModel> messages;
  final RateLimitModel? rateLimitStatus;
  final String? sessionId;

  const AskWingAIQuestionSuccess({
    required this.messages,
    this.rateLimitStatus,
    this.sessionId,
  });

  @override
  List<Object?> get props => [messages, rateLimitStatus, sessionId];
}

/// Rate limit exceeded state
class AskWingAIRateLimitExceeded extends AskWingAIState {
  final String message;
  final RateLimitModel rateLimitStatus;

  const AskWingAIRateLimitExceeded({
    required this.message,
    required this.rateLimitStatus,
  });

  @override
  List<Object?> get props => [message, rateLimitStatus];
}

/// History loading state
class AskWingAIHistoryLoading extends AskWingAIState {
  const AskWingAIHistoryLoading();
}

/// History loaded state
class AskWingAIHistoryLoaded extends AskWingAIState {
  final List<ChatMessageModel> messages;
  final int total;
  final bool hasMore;
  final String? sessionId;

  const AskWingAIHistoryLoaded({
    required this.messages,
    required this.total,
    required this.hasMore,
    this.sessionId,
  });

  @override
  List<Object?> get props => [messages, total, hasMore, sessionId];
}

/// Clearing history state
class AskWingAIClearingHistory extends AskWingAIState {
  const AskWingAIClearingHistory();
}

/// History cleared state
class AskWingAIHistoryCleared extends AskWingAIState {
  const AskWingAIHistoryCleared();
}

/// Error state
class AskWingAIError extends AskWingAIState {
  final String message;
  final List<ChatMessageModel>? previousMessages;

  const AskWingAIError({
    required this.message,
    this.previousMessages,
  });

  @override
  List<Object?> get props => [message, previousMessages];
}
