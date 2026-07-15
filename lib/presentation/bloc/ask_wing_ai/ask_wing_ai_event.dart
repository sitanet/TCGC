import 'package:equatable/equatable.dart';

/// Base event for Ask Wing AI
abstract class AskWingAIEvent extends Equatable {
  const AskWingAIEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize the chat interface
class InitializeAskWingAI extends AskWingAIEvent {
  const InitializeAskWingAI();
}

/// Submit a question to Ask Wing AI
class SubmitQuestion extends AskWingAIEvent {
  final String question;
  final List<String>? previousMessageIds;

  const SubmitQuestion({
    required this.question,
    this.previousMessageIds,
  });

  @override
  List<Object?> get props => [question, previousMessageIds];
}

/// Load chat history from backend
class LoadChatHistory extends AskWingAIEvent {
  final int limit;
  final int offset;

  const LoadChatHistory({
    this.limit = 50,
    this.offset = 0,
  });

  @override
  List<Object?> get props => [limit, offset];
}

/// Clear all chat history
class ClearChatHistory extends AskWingAIEvent {
  const ClearChatHistory();
}

/// Check rate limit status
class CheckRateLimit extends AskWingAIEvent {
  const CheckRateLimit();
}

/// Retry the last failed question
class RetryQuestion extends AskWingAIEvent {
  final String question;

  const RetryQuestion({required this.question});

  @override
  List<Object?> get props => [question];
}

/// Open the chat interface
class OpenChatInterface extends AskWingAIEvent {
  const OpenChatInterface();
}

/// Close the chat interface
class CloseChatInterface extends AskWingAIEvent {
  const CloseChatInterface();
}

/// Handle authentication required
class HandleAuthenticationRequired extends AskWingAIEvent {
  final String? message;

  const HandleAuthenticationRequired({this.message});

  @override
  List<Object?> get props => [message];
}

/// Reset error state
class ResetErrorState extends AskWingAIEvent {
  const ResetErrorState();
}

/// Update daily question count
class UpdateQuestionCount extends AskWingAIEvent {
  final int remaining;
  final int limit;

  const UpdateQuestionCount({
    required this.remaining,
    required this.limit,
  });

  @override
  List<Object?> get props => [remaining, limit];
}
