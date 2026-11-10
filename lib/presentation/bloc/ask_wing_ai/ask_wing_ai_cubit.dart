import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/ask_wing_ai_service.dart';
import '../../../data/models/ask_wing_ai/chat_message_model.dart';
import '../../../data/models/ask_wing_ai/ask_wing_ai_response_model.dart';
import '../../../core/utils/error_handler.dart';
import 'ask_wing_ai_state.dart';

class AskWingAICubit extends Cubit<AskWingAIState> {
  final AskWingAIService _service;
  static const String _prefsSessionKey = 'ask_wing_ai_session_id';

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

      // Restore session ID from preferences if available
      try {
        final prefs = await SharedPreferences.getInstance();
        _currentSessionId ??= prefs.getString(_prefsSessionKey);
      } catch (e) {
        debugPrint('Error restoring Wing AI session: $e');
      }

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
        debugPrint('Failed to load rate limit: $e');
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
  Future<void> submitQuestion(String question, {String? responseStyle}) async {
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
        responseStyle: responseStyle,
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
      
      // Build conversation history (up to last 6 turns: user questions & AI responses)
      final recentTurns = previousMessages.length > 6
          ? previousMessages.sublist(previousMessages.length - 6)
          : previousMessages;

      final historyPayload = recentTurns.map((m) => {
        'type': m.isUser ? 'user' : 'ai',
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.content,
      }).toList();

      final recentIds = previousMessages.length > 5
          ? previousMessages.sublist(previousMessages.length - 5).map((m) => m.id).where((id) => id <= 2147483647).toList()
          : previousMessages.map((m) => m.id).where((id) => id <= 2147483647).toList();

      // Submit to backend with sessionId, history payload, and responseStyle
      final response = await _service.submitQuestion(
        question: question,
        sessionId: _currentSessionId,
        responseStyle: responseStyle,
        previousMessageIds: recentIds.isNotEmpty ? recentIds : null,
        conversationHistory: historyPayload.isNotEmpty ? historyPayload : null,
      );

      // Update and persist session ID
      if (response.sessionId != null && response.sessionId!.isNotEmpty) {
        _currentSessionId = response.sessionId;
        _persistSessionId(_currentSessionId!);
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
        responseStyle: responseStyle,
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

  Future<void> _persistSessionId(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsSessionKey, sessionId);
    } catch (e) {
      debugPrint('Failed to persist session ID: $e');
    }
  }

  /// Load chat history
  Future<void> _loadChatHistory() async {
    try {
      final response = await _service.getChatHistory(
        limit: 50,
        sessionId: _currentSessionId,
      );

      final sortedMessages = List<ChatMessageModel>.from(response.messages)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _messages = sortedMessages;

      if (response.sessionId != null && response.sessionId!.isNotEmpty) {
        _currentSessionId = response.sessionId;
        _persistSessionId(_currentSessionId!);
      }
    } catch (e) {
      debugPrint('Failed to load chat history: $e');
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

      final sortedMessages = List<ChatMessageModel>.from(response.messages)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _messages = sortedMessages;

      if (response.sessionId != null && response.sessionId!.isNotEmpty) {
        _currentSessionId = response.sessionId;
        _persistSessionId(_currentSessionId!);
      }

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
    final previousSessionId = _currentSessionId;

    // Clear local messages immediately so UI is cleared without hesitation
    _messages.clear();
    _currentSessionId = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsSessionKey);
    } catch (e) {
      debugPrint('Failed to clear persisted session ID: $e');
    }

    emit(AskWingAIClearingHistory());

    try {
      await _service.clearChatHistory(sessionId: previousSessionId);
    } catch (e) {
      debugPrint('clearHistory error from backend service: $e');
    }

    emit(AskWingAIHistoryCleared());

    // Return to ready state with clean message list
    emit(AskWingAIReady(
      messages: const [],
      rateLimitStatus: _rateLimitStatus,
    ));
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
      debugPrint('Failed to refresh rate limit: $e');
    }
  }

  /// Reset to initial state
  void reset() {
    _messages.clear();
    _currentSessionId = null;
    _rateLimitStatus = null;
    SharedPreferences.getInstance().then((prefs) => prefs.remove(_prefsSessionKey)).catchError((_) {});
    emit(AskWingAIInitial());
  }
}
