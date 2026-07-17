import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/ask_wing_ai_repository.dart';
import '../../../data/models/ask_wing_ai/chat_message_model.dart';
import '../../../core/utils/failure.dart';
import 'ask_wing_ai_event.dart';
import 'ask_wing_ai_state.dart';

/// Business Logic Component for Ask Wing AI chat interface
class AskWingAIBloc extends Bloc<AskWingAIEvent, AskWingAIState> {
  final AskWingAIRepository repository;

  // Session-based chat history (cleared when closed)
  List<ChatMessageModel> _sessionMessages = [];
  int _dailyQuestionsRemaining = 0;
  int _dailyQuestionsLimit = 50;

  AskWingAIBloc({required this.repository})
      : super(const AskWingAIInitial()) {
    // Register event handlers
    on<InitializeAskWingAI>(_onInitialize);
    on<SubmitQuestion>(_onSubmitQuestion);
    on<LoadChatHistory>(_onLoadChatHistory);
    on<ClearChatHistory>(_onClearChatHistory);
    on<CheckRateLimit>(_onCheckRateLimit);
    on<RetryQuestion>(_onRetryQuestion);
    on<OpenChatInterface>(_onOpenChatInterface);
    on<CloseChatInterface>(_onCloseChatInterface);
    on<HandleAuthenticationRequired>(_onAuthenticationRequired);
    on<ResetErrorState>(_onResetErrorState);
    on<UpdateQuestionCount>(_onUpdateQuestionCount);
  }

  /// Initialize the chat interface and load initial data
  Future<void> _onInitialize(
    InitializeAskWingAI event,
    Emitter<AskWingAIState> emit,
  ) async {
    // Check rate limit first
    final rateLimitResult = await repository.getRateLimitStatus();

    rateLimitResult.fold(
      (failure) {
        if (failure is AuthenticationFailure) {
          emit(const AskWingAIAuthenticationRequired());
        } else {
          emit(
            AskWingAIError(
              message: failure.toString(),
              previousMessages: _sessionMessages,
              isNetworkError: failure is NetworkFailure,
            ),
          );
        }
      },
      (rateLimit) {
        _dailyQuestionsRemaining = rateLimit.dailyRemaining;
        _dailyQuestionsLimit = rateLimit.dailyLimit;

        if (_dailyQuestionsRemaining <= 0) {
          emit(
            AskWingAIRateLimited(
              message: 'Daily question limit exceeded. Please try again tomorrow.',
              messages: _sessionMessages,
              dailyLimit: _dailyQuestionsLimit,
              resetTime: rateLimit.resetTime,
            ),
          );
        } else {
          emit(
            AskWingAISuccess(
              messages: _sessionMessages,
              dailyQuestionsRemaining: _dailyQuestionsRemaining,
              dailyQuestionsLimit: _dailyQuestionsLimit,
            ),
          );
        }
      },
    );
  }

  /// Submit a question to Ask Wing AI
  Future<void> _onSubmitQuestion(
    SubmitQuestion event,
    Emitter<AskWingAIState> emit,
  ) async {
    // Validate question
    if (event.question.trim().isEmpty) {
      emit(
        AskWingAIError(
          message: 'Question cannot be empty',
          previousMessages: _sessionMessages,
        ),
      );
      return;
    }

    // Check rate limit before submitting
    if (_dailyQuestionsRemaining <= 0) {
      emit(
        AskWingAIRateLimited(
          message: 'Daily question limit exceeded. Please try again tomorrow.',
          messages: _sessionMessages,
          dailyLimit: _dailyQuestionsLimit,
          resetTime: DateTime.now().add(const Duration(days: 1)),
        ),
      );
      return;
    }

    // Add user message to history
    final userMessage = ChatMessageModel(
      id: DateTime.now().millisecondsSinceEpoch,
      sessionId: '',
      content: event.question,
      messageType: MessageType.user,
      createdAt: DateTime.now(),
    );

    _sessionMessages.add(userMessage);

    // Show loading state
    emit(
      AskWingAILoading(
        messages: List.from(_sessionMessages),
        currentQuestion: event.question,
      ),
    );

    // Submit question to backend
    final result = await repository.submitQuestion(
      event.question,
      previousMessageIds: event.previousMessageIds,
    );

    result.fold(
      (failure) {
        // Remove the user message on failure
        _sessionMessages.removeLast();

        if (failure is RateLimitFailure) {
          emit(
            AskWingAIRateLimited(
              message: failure.message,
              messages: List.from(_sessionMessages),
              dailyLimit: _dailyQuestionsLimit,
              resetTime: DateTime.now().add(const Duration(days: 1)),
            ),
          );
        } else if (failure is AuthenticationFailure) {
          emit(const AskWingAIAuthenticationRequired());
        } else {
          emit(
            AskWingAIError(
              message: failure.message,
              previousMessages: List.from(_sessionMessages),
              isNetworkError: failure is NetworkFailure,
              isAuthenticationError: failure is AuthenticationFailure,
            ),
          );
        }
      },
      (response) {
        // Add AI response to history
        final aiMessage = ChatMessageModel(
          id: int.tryParse(response.messageId) ?? DateTime.now().millisecondsSinceEpoch,
          sessionId: '',
          content: response.response,
          messageType: MessageType.ai,
          createdAt: response.timestamp,
          citations: response.citations,
          processingTimeMs: response.processingTimeMs,
        );

        _sessionMessages.add(aiMessage);

        // Update rate limit
        _dailyQuestionsRemaining = max(0, _dailyQuestionsRemaining - 1);

        emit(
          AskWingAISuccess(
            messages: List.from(_sessionMessages),
            dailyQuestionsRemaining: _dailyQuestionsRemaining,
            dailyQuestionsLimit: _dailyQuestionsLimit,
          ),
        );
      },
    );
  }

  /// Load chat history from backend
  Future<void> _onLoadChatHistory(
    LoadChatHistory event,
    Emitter<AskWingAIState> emit,
  ) async {
    emit(
      AskWingAILoading(
        messages: List.from(_sessionMessages),
        currentQuestion: '',
      ),
    );

    final result = await repository.getChatHistory(
      limit: event.limit,
      offset: event.offset,
    );

    result.fold(
      (failure) {
        emit(
          AskWingAIError(
            message: 'Failed to load chat history: ${failure.message}',
            previousMessages: List.from(_sessionMessages),
            isNetworkError: failure is NetworkFailure,
          ),
        );
      },
      (history) {
        _sessionMessages = history.messages;
        emit(
          AskWingAISuccess(
            messages: List.from(_sessionMessages),
            dailyQuestionsRemaining: _dailyQuestionsRemaining,
            dailyQuestionsLimit: _dailyQuestionsLimit,
          ),
        );
      },
    );
  }

  /// Clear chat history (session-based)
  Future<void> _onClearChatHistory(
    ClearChatHistory event,
    Emitter<AskWingAIState> emit,
  ) async {
    emit(AskWingAILoading(messages: const [], currentQuestion: ''));

    final result = await repository.clearChatHistory();

    result.fold(
      (failure) {
        emit(
          AskWingAIError(
            message: 'Failed to clear chat history: ${failure.message}',
            previousMessages: List.from(_sessionMessages),
          ),
        );
      },
      (_) {
        _sessionMessages = [];
        emit(
          const AskWingAIHistoryCleared(),
        );
      },
    );
  }

  /// Check rate limit status
  Future<void> _onCheckRateLimit(
    CheckRateLimit event,
    Emitter<AskWingAIState> emit,
  ) async {
    final result = await repository.getRateLimitStatus();

    result.fold(
      (failure) {
        // Log error but don't change state
        print('Rate limit check failed: ${failure.message}');
      },
      (rateLimit) {
        _dailyQuestionsRemaining = rateLimit.dailyRemaining;
        _dailyQuestionsLimit = rateLimit.dailyLimit;

        if (state is AskWingAISuccess) {
          emit(
            (state as AskWingAISuccess).copyWith(
              dailyQuestionsRemaining: _dailyQuestionsRemaining,
              dailyQuestionsLimit: _dailyQuestionsLimit,
            ),
          );
        }
      },
    );
  }

  /// Retry the last failed question
  Future<void> _onRetryQuestion(
    RetryQuestion event,
    Emitter<AskWingAIState> emit,
  ) async {
    // Retry as a normal question submission
    add(SubmitQuestion(question: event.question));
  }

  /// Handle opening the chat interface
  Future<void> _onOpenChatInterface(
    OpenChatInterface event,
    Emitter<AskWingAIState> emit,
  ) async {
    // Initialize the chat interface
    add(const InitializeAskWingAI());
  }

  /// Handle closing the chat interface
  Future<void> _onCloseChatInterface(
    CloseChatInterface event,
    Emitter<AskWingAIState> emit,
  ) async {
    // Reset to initial state and clear session messages
    _sessionMessages = [];
    emit(const AskWingAIInitial());
  }

  /// Handle authentication required
  Future<void> _onAuthenticationRequired(
    HandleAuthenticationRequired event,
    Emitter<AskWingAIState> emit,
  ) async {
    emit(
      AskWingAIAuthenticationRequired(
        message: event.message ?? 'Please log in to use Ask Wing AI',
      ),
    );
  }

  /// Reset error state to initial state
  Future<void> _onResetErrorState(
    ResetErrorState event,
    Emitter<AskWingAIState> emit,
  ) async {
    emit(
      AskWingAISuccess(
        messages: List.from(_sessionMessages),
        dailyQuestionsRemaining: _dailyQuestionsRemaining,
        dailyQuestionsLimit: _dailyQuestionsLimit,
      ),
    );
  }

  /// Update question count
  Future<void> _onUpdateQuestionCount(
    UpdateQuestionCount event,
    Emitter<AskWingAIState> emit,
  ) async {
    _dailyQuestionsRemaining = event.remaining;
    _dailyQuestionsLimit = event.limit;

    if (state is AskWingAISuccess) {
      emit(
        (state as AskWingAISuccess).copyWith(
          dailyQuestionsRemaining: event.remaining,
          dailyQuestionsLimit: event.limit,
        ),
      );
    }
  }
}

/// Helper function to get max of two numbers
int max(int a, int b) => a > b ? a : b;
