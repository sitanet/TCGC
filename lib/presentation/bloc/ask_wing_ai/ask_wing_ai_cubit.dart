import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/services/ask_wing_ai_service.dart';
import '../../../data/models/ask_wing_ai/chat_message_model.dart';
import '../../../data/models/ask_wing_ai/ask_wing_ai_response_model.dart';
import '../../../core/utils/error_handler.dart';
import 'ask_wing_ai_state.dart';

class AskWingAICubit extends Cubit<AskWingAIState> {
  final AskWingAIService _service;

  AskWingAICubit({required AskWingAIService service})
      : _service = service,
        super(AskWingAIInitial());

  String? _currentSessionId;
  List<ChatMessageModel> _messages = [];
  RateLimitModel? _rateLimitStatus;

  /// Initialize - Check if feature is enabled
  Future<void> initialize() async {
    try {
      emit(AskWingAIFeatureCheckLoading());

      // Check feature status
      final featureStatus = await _service.checkFeatureStatus();

      if (!featureStatus.isEnabled) {
        emit(AskWingAIFeatureDisabled(
          featureStatus.message ?? 'Ask Wing AI is currently unavailable.',
        ));
        return;
      }

      // Load rate limit status
      try {
        _rateLimitStatus = await _service.getRateLimitStatus();
      } catch (e) {
        // Continue even if rate limit fetch fails
        print('Failed to load rate limit: $e');
      }

      // Load chat history
      await _loadChatHistory();

      emit(AskWingAIReady(
        messages: _messages,
        rateLimitStatus: _rateLimitStatus,
        sessionId: _currentSessionId,
      ));
    } catch (e) {
      emit(AskWingAIError(message: ErrorHandler.getErrorMessage(e)));
    }
  }

  /// Submit a question
  Future<void> submitQuestion(String question) async {
    if (question.trim().isEmpty) {
      emit(const AskWingAIError(message: 'Please enter a question'));
      return;
    }

    try {
      // Add user message to local list immediately
      final userMessage = ChatMessageModel(
        id: DateTime.now().millisecondsSinceEpoch, // Temporary ID
        sessionId: _currentSessionId ?? '',
        messageType: MessageType.user,
        content: question,
        createdAt: DateTime.now(),
      );

      _messages.add(userMessage);

      // Show loading state with updated messages list
      emit(AskWingAIQuestionSubmitting(
        previousMessages: List.from(_messages),
        question: question,
      ));

      // Get previous messages (excluding the one we just added)
      final previousMessages = _messages.sublist(0, _messages.length - 1);
      // Limit to the last 5 messages for context and filter out temporary timestamp IDs
      final recentIds = previousMessages.length > 5
          ? previousMessages.sublist(previousMessages.length - 5).map((m) => m.id).where((id) => id <= 2147483647).toList()
          : previousMessages.map((m) => m.id).where((id) => id <= 2147483647).toList();

      // Submit to backend
      final response = await _service.submitQuestion(
        question: question,
        sessionId: _currentSessionId,
        previousMessageIds: recentIds.isNotEmpty ? recentIds : null,
      );

      // Update session ID
      if (response.sessionId != null) {
        _currentSessionId = response.sessionId;
      }

      // Update rate limit
      if (response.rateLimit != null) {
        _rateLimitStatus = response.rateLimit;
      }

      // Create AI message from response
      final aiMessage = ChatMessageModel(
        id: int.tryParse(response.messageId) ?? DateTime.now().millisecondsSinceEpoch,
        sessionId: _currentSessionId ?? '',
        messageType: MessageType.ai,
        content: response.response,
        citations: response.citations,
        processingTimeMs: response.processingTimeMs,
        createdAt: response.timestamp,
      );

      // Add AI message to list
      _messages.add(aiMessage);

      emit(AskWingAIQuestionSuccess(
        messages: List.from(_messages),
        rateLimitStatus: _rateLimitStatus,
        sessionId: _currentSessionId,
      ));
    } on RateLimitException catch (e) {
      // Rate limit exceeded
      _messages.removeLast(); // Remove the user message we added
      
      emit(AskWingAIRateLimitExceeded(
        message: e.toString(),
        rateLimitStatus: _rateLimitStatus ?? RateLimitModel(
          dailyLimit: 50,
          dailyUsed: 50,
          dailyRemaining: 0,
          resetTime: DateTime.now().add(const Duration(days: 1)),
        ),
      ));
    } on FeatureDisabledException catch (e) {
      _messages.removeLast(); // Remove the user message we added
      emit(AskWingAIFeatureDisabled(e.toString()));
    } catch (e) {
      _messages.removeLast(); // Remove the user message we added
      emit(AskWingAIError(
        message: ErrorHandler.getErrorMessage(e),
        previousMessages: _messages,
      ));
    }
  }

  /// Load chat history
  Future<void> _loadChatHistory() async {
    try {
      final response = await _service.getChatHistory(
        limit: 50,
        sessionId: _currentSessionId,
      );

      _messages = response.messages;
      _currentSessionId = response.sessionId;
    } catch (e) {
      print('Failed to load chat history: $e');
      // Continue with empty messages - not critical
    }
  }

  /// Reload chat history (pull to refresh)
  Future<void> reloadHistory() async {
    try {
      emit(AskWingAIHistoryLoading());

      final response = await _service.getChatHistory(
        limit: 50,
        sessionId: _currentSessionId,
      );

      _messages = response.messages;

      emit(AskWingAIHistoryLoaded(
        messages: _messages,
        total: response.total,
        hasMore: response.hasMore,
        sessionId: response.sessionId,
      ));
    } catch (e) {
      emit(AskWingAIError(
        message: ErrorHandler.getErrorMessage(e),
        previousMessages: _messages,
      ));
    }
  }

  /// Clear chat history
  Future<void> clearHistory() async {
    try {
      emit(AskWingAIClearingHistory());

      await _service.clearChatHistory(sessionId: _currentSessionId);

      _messages.clear();
      _currentSessionId = null;

      emit(AskWingAIHistoryCleared());

      // Return to ready state
      emit(AskWingAIReady(
        messages: [],
        rateLimitStatus: _rateLimitStatus,
      ));
    } catch (e) {
      emit(AskWingAIError(
        message: ErrorHandler.getErrorMessage(e),
        previousMessages: _messages,
      ));
    }
  }

  /// Refresh rate limit status
  Future<void> refreshRateLimit() async {
    try {
      _rateLimitStatus = await _service.getRateLimitStatus();

      if (state is AskWingAIReady) {
        emit((state as AskWingAIReady).copyWith(
          rateLimitStatus: _rateLimitStatus,
        ));
      }
    } catch (e) {
      print('Failed to refresh rate limit: $e');
    }
  }

  /// Reset to initial state
  void reset() {
    _messages.clear();
    _currentSessionId = null;
    _rateLimitStatus = null;
    emit(AskWingAIInitial());
  }
}
