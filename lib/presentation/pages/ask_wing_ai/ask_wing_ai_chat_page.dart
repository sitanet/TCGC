import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/ask_wing_ai/ask_wing_ai_cubit.dart';
import '../../bloc/ask_wing_ai/ask_wing_ai_state.dart';
import '../../widgets/ask_wing_ai/chat_message_list.dart';
import '../../widgets/ask_wing_ai/chat_input_field.dart';
import '../../widgets/ask_wing_ai/welcome_message.dart';
import '../../widgets/ask_wing_ai/rate_limit_indicator.dart';
import '../../../data/models/ask_wing_ai/chat_message_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../domain/entities/user.dart';
import '../../../core/utils/error_handler.dart';

/// Main chat page for Ask Wing AI
class AskWingAIChatPage extends StatefulWidget {
  const AskWingAIChatPage({Key? key}) : super(key: key);

  @override
  State<AskWingAIChatPage> createState() => _AskWingAIChatPageState();
}

class _AskWingAIChatPageState extends State<AskWingAIChatPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final AuthService _authService = AuthService();
  
  AppUser? _currentUser;
  bool _showScrollDownButton = false;

  @override
  void initState() {
    super.initState();
    // Load user data
    _loadUserData();
    
    // Add scroll controller listener for scroll down button
    _scrollController.addListener(_scrollListener);
    
    // Initialize if needed
    final cubit = context.read<AskWingAICubit>();
    if (cubit.state is AskWingAIInitial) {
      cubit.initialize();
    }
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      // Show button if user scrolls up more than 200 logical pixels from the bottom
      final show = maxScroll - currentScroll > 200;
      if (show != _showScrollDownButton) {
        setState(() {
          _showScrollDownButton = show;
        });
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getProfile();
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (e) {
      // Continue without user data if fetch fails
      print('Failed to load user profile: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFE5A93C),
                    Theme.of(context).primaryColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.flutter_dash,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Wing AI',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          // Rate limit indicator
          BlocBuilder<AskWingAICubit, AskWingAIState>(
            builder: (context, state) {
              if (state is AskWingAIReady && state.rateLimitStatus != null) {
                return RateLimitIndicator(
                  status: state.rateLimitStatus!,
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // More menu
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(value, context),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline),
                    SizedBox(width: 8),
                    Text('Clear History'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'help',
                child: Row(
                  children: [
                    Icon(Icons.help_outline),
                    SizedBox(width: 8),
                    Text('Help'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: BlocConsumer<AskWingAICubit, AskWingAIState>(
        listener: (context, state) {
          // Handle errors
          if (state is AskWingAIError) {
            ErrorHandler.showError(context, state.message);
          }

          // Handle rate limit exceeded
          if (state is AskWingAIRateLimitExceeded) {
            _showRateLimitDialog(context, state);
          }

          // Handle feature disabled
          if (state is AskWingAIFeatureDisabled) {
            _showFeatureDisabledDialog(context, state.message);
          }

          // Scroll to bottom on load, question submission, or response success
          if (state is AskWingAIQuestionSuccess || 
              state is AskWingAIQuestionSubmitting || 
              state is AskWingAIHistoryLoaded || 
              state is AskWingAIReady) {
            _scrollToBottom();
          }
        },
        builder: (context, state) {
          // Loading state
          if (state is AskWingAIFeatureCheckLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Feature disabled
          if (state is AskWingAIFeatureDisabled) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 64,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Feature Unavailable',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // Main chat interface
          return Column(
            children: [
              // Messages list
              Expanded(
                child: Stack(
                  children: [
                    _buildMessagesList(state),
                    if (_showScrollDownButton)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton(
                          mini: true,
                          elevation: 3,
                          backgroundColor: Theme.of(context).primaryColor,
                          onPressed: _scrollToBottom,
                          child: const Icon(
                            Icons.arrow_downward_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Input field
              ChatInputField(
                controller: _textController,
                onSubmit: (question) => _submitQuestion(question, state),
                enabled: _canSubmitQuestion(state),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessagesList(AskWingAIState state) {
    // Get messages from state
    final messages = _getMessages(state);

    if (messages.isEmpty) {
      // Extract rate limit data for the welcome page prompt counter
      int? remaining;
      int? limit;
      if (state is AskWingAIReady && state.rateLimitStatus != null) {
        remaining = state.rateLimitStatus!.dailyRemaining;
        limit = state.rateLimitStatus!.dailyLimit;
      }

      return WelcomeMessage(
        onQuestionTap: (question) => _submitQuestion(question, state),
        userName: _currentUser?.firstName,
        dailyRemaining: remaining,
        dailyLimit: limit,
      );
    }

    // Show messages
    return ChatMessageList(
      messages: messages,
      scrollController: _scrollController,
      isLoading: state is AskWingAIQuestionSubmitting,
    );
  }

  List<ChatMessageModel> _getMessages(AskWingAIState state) {
    if (state is AskWingAIReady) return state.messages;
    if (state is AskWingAIQuestionSubmitting) return state.previousMessages;
    if (state is AskWingAIQuestionSuccess) return state.messages;
    if (state is AskWingAIHistoryLoaded) return state.messages;
    if (state is AskWingAIError && state.previousMessages != null) {
      return state.previousMessages!;
    }
    return [];
  }

  bool _canSubmitQuestion(AskWingAIState state) {
    if (state is AskWingAIQuestionSubmitting) return false;
    if (state is AskWingAIFeatureDisabled) return false;
    if (state is AskWingAIRateLimitExceeded) return false;
    if (state is AskWingAIReady && !(state.rateLimitStatus?.canAsk ?? true)) {
      return false;
    }
    return true;
  }

  void _submitQuestion(String question, AskWingAIState state) {
    if (question.trim().isEmpty) return;

    context.read<AskWingAICubit>().submitQuestion(question);
    _textController.clear();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleMenuAction(String action, BuildContext context) {
    switch (action) {
      case 'clear':
        _showClearHistoryDialog(context);
        break;
      case 'help':
        _showHelpDialog(context);
        break;
    }
  }

  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History?'),
        content: const Text(
          'This will delete all your messages with Ask Wing AI. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AskWingAICubit>().clearHistory();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showRateLimitDialog(BuildContext context, AskWingAIRateLimitExceeded state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E222A) : Colors.white,
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_empty_rounded,
                color: Color(0xFFE53935),
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Daily Limit Reached',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You\'ve used all 15 prompts for today. Please wait until tomorrow (resets at midnight) to ask more questions.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : const Color(0xFFFFF9EE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE5A93C).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 18, color: Color(0xFFE5A93C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Come back tomorrow with 20 fresh prompts!',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Got it'),
            ),
          ),
        ],
      ),
    );
  }

  void _showFeatureDisabledDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Feature Unavailable'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Also pop the chat page
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Use Ask Wing AI'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ask Wing AI helps you find answers from our sermon content.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('Example Questions:'),
              SizedBox(height: 8),
              Text('• What does the Bible say about faith?'),
              Text('• How can I strengthen my prayer life?'),
              Text('• What are the fruits of the Spirit?'),
              SizedBox(height: 16),
              Text(
                'Each response includes citations from specific sermons with timestamps.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
