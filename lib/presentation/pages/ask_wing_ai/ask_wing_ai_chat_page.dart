import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/ask_wing_ai/ask_wing_ai_cubit.dart';
import '../../bloc/ask_wing_ai/ask_wing_ai_state.dart';
import '../../widgets/ask_wing_ai/chat_message_list.dart';
import '../../widgets/ask_wing_ai/response_mode_sheet.dart';
import '../../widgets/ask_wing_ai/chat_input_field.dart';
import '../../widgets/ask_wing_ai/welcome_message.dart';
import '../../../data/models/ask_wing_ai/chat_message_model.dart';
import '../../widgets/ask_wing_ai/ai_consent_dialog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/auth_service.dart';
import '../../../domain/entities/user.dart';
import '../../../core/utils/error_handler.dart';


import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../domain/entities/sermon.dart';
import '../../../data/services/data_service.dart';
import '../audio/audio_player_page.dart';

/// Main chat page for Ask Wing AI
class AskWingAIChatPage extends StatefulWidget {
  const AskWingAIChatPage({super.key});

  @override
  State<AskWingAIChatPage> createState() => _AskWingAIChatPageState();
}

class _AskWingAIChatPageState extends State<AskWingAIChatPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final AuthService _authService = AuthService();
  final DataService _dataService = DataService();
  
  AppUser? _currentUser;
  bool _showScrollDownButton = false;
  bool _showDashboard = true; // Always start on the AI Dashboard

  List<Sermon> _allSermons = [];
  List<Sermon> _matchedSermons = [];
  Timer? _searchDebounce;
  bool _isSearchDismissed = false;

  @override
  void initState() {
    super.initState();
    // Load user data
    _loadUserData();
    // Load sermons for real-time search
    _loadSermons();
    
    // Add text listener for instant sermon search
    _textController.addListener(_onSearchQueryChanged);

    // Add scroll controller listener for scroll down button
    _scrollController.addListener(_scrollListener);
    
    // Initialize if needed
    final cubit = context.read<AskWingAICubit>();
    if (cubit.state is AskWingAIInitial) {
      cubit.initialize();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verifyAIConsent();
    });
  }

  Future<void> _verifyAIConsent() async {
    final hasConsent = await AIConsentDialog.hasConsented();
    if (!hasConsent && mounted) {
      final granted = await AIConsentDialog.showConsentDialog(context);
      if (!granted && mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _loadSermons() async {
    try {
      final sermons = await _dataService.getMessages();
      if (mounted) {
        setState(() {
          _allSermons = sermons;
        });
      }
    } catch (e) {
      debugPrint('Failed to load sermons for search: $e');
    }
  }

  void _onSearchQueryChanged() {
    final query = _textController.text.trim();
    if (_isSearchDismissed && query.isEmpty) {
      _isSearchDismissed = false;
    }

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      _performSermonSearch(query);
    });
  }

  void _performSermonSearch(String query) {
    if (query.length < 2 || _isSearchDismissed) {
      if (_matchedSermons.isNotEmpty) {
        setState(() {
          _matchedSermons = [];
        });
      }
      return;
    }

    final lower = query.toLowerCase();
    final tokens = lower.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    if (tokens.isEmpty) {
      if (_matchedSermons.isNotEmpty) {
        setState(() {
          _matchedSermons = [];
        });
      }
      return;
    }

    final matches = _allSermons.where((s) {
      final title = s.title.toLowerCase();
      final speaker = (s.speaker ?? '').toLowerCase();
      final category = (s.categoryName.isNotEmpty ? s.categoryName : s.category).toLowerCase();
      final description = s.description.toLowerCase();

      // All tokens must match somewhere in title, speaker, category, or description
      return tokens.every((token) =>
          title.contains(token) ||
          speaker.contains(token) ||
          category.contains(token) ||
          description.contains(token));
    }).toList();

    // Sort: Title starts with query first, then title contains, then recent date
    matches.sort((a, b) {
      final aTitleLower = a.title.toLowerCase();
      final bTitleLower = b.title.toLowerCase();

      final aExactTitle = aTitleLower.startsWith(lower);
      final bExactTitle = bTitleLower.startsWith(lower);
      if (aExactTitle && !bExactTitle) return -1;
      if (!aExactTitle && bExactTitle) return 1;

      final aHasTitle = tokens.every((t) => aTitleLower.contains(t));
      final bHasTitle = tokens.every((t) => bTitleLower.contains(t));
      if (aHasTitle && !bHasTitle) return -1;
      if (!aHasTitle && bHasTitle) return 1;

      return b.date.compareTo(a.date);
    });

    setState(() {
      _matchedSermons = matches.take(15).toList();
    });
  }

  void _playSermon(Sermon sermon) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AudioPlayerPage(sermon: sermon),
      ),
    );
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
      debugPrint('Failed to load user profile: $e');
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _textController.removeListener(_onSearchQueryChanged);
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubitState = context.watch<AskWingAICubit>().state;
    final currentMessages = _getMessages(cubitState);
    final hasMessages = currentMessages.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFD54F),
                    AppColors.primaryGold,
                    Color(0xFFB8860B),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGold.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Wing AI',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  'Spiritual Guidance',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_showDashboard && hasMessages)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showDashboard = false;
                });
                _scrollToBottom();
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.primaryGold),
              label: const Text(
                'Previous Chat',
                style: TextStyle(
                  color: AppColors.primaryGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (!_showDashboard)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showDashboard = true;
                });
              },
              icon: const Icon(Icons.dashboard_outlined, size: 16, color: AppColors.primaryGold),
              label: const Text(
                'Dashboard',
                style: TextStyle(
                  color: AppColors.primaryGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.privacy_tip_outlined, color: AppColors.primaryGold),
            tooltip: 'AI Privacy & Data Notice',
            onPressed: () => AIConsentDialog.showConsentDialog(context, isInformationalOnly: true),
          ),
          // More menu
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(value, context),
            itemBuilder: (context) => [
              if (!_showDashboard)
                const PopupMenuItem(
                  value: 'dashboard',
                  child: Row(
                    children: [
                      Icon(Icons.dashboard_outlined),
                      SizedBox(width: 8),
                      Text('Return to Dashboard'),
                    ],
                  ),
                ),
              if (_showDashboard && hasMessages)
                const PopupMenuItem(
                  value: 'continue_chat',
                  child: Row(
                    children: [
                      Icon(Icons.chat_outlined),
                      SizedBox(width: 8),
                      Text('Continue Previous Chat'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'privacy',
                child: Row(
                  children: [
                    Icon(Icons.privacy_tip_outlined, color: AppColors.primaryGold),
                    SizedBox(width: 8),
                    Text('AI Privacy & Data Notice'),
                  ],
                ),
              ),
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

          // Rate limit removed - no dialog

          // Handle feature disabled
          if (state is AskWingAIFeatureDisabled) {
            _showFeatureDisabledDialog(context, state.message);
          }

          // Handle history cleared
          if (state is AskWingAIHistoryCleared) {
            setState(() {
              _matchedSermons = [];
            });
            _textController.clear();
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
              // Matched sermons overlay above input field
              if (_matchedSermons.isNotEmpty) _buildMatchedSermonsWidget(),
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

  Widget _buildMatchedSermonsWidget() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5A93C).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: Color(0xFFE5A93C),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Wing AI Found ${_matchedSermons.length} ${_matchedSermons.length == 1 ? "Message" : "Messages"}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Text(
                  'Tap to play',
                  style: TextStyle(
                    fontSize: 11,
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    setState(() {
                      _isSearchDismissed = true;
                      _matchedSermons = [];
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          // Scrollable messages list
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _matchedSermons.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                thickness: 0.5,
                indent: 64,
                color: isDark ? Colors.grey[800] : Colors.grey[200],
              ),
              itemBuilder: (context, index) {
                final sermon = _matchedSermons[index];
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: (sermon.imageUrl != null && sermon.imageUrl!.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: sermon.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: primaryColor.withValues(alpha: 0.1),
                                child: Icon(Icons.music_note, color: primaryColor, size: 20),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: primaryColor.withValues(alpha: 0.1),
                                child: Icon(Icons.music_note, color: primaryColor, size: 20),
                              ),
                            )
                          : Container(
                              color: primaryColor.withValues(alpha: 0.1),
                              child: Icon(Icons.music_note, color: primaryColor, size: 20),
                            ),
                    ),
                  ),
                  title: Text(
                    sermon.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      if (sermon.speaker != null && sermon.speaker!.isNotEmpty) ...[
                        Flexible(
                          child: Text(
                            sermon.speaker!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '•',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[500] : Colors.grey[400],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        sermon.categoryName.isNotEmpty ? sermon.categoryName : sermon.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFFE5A93C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  trailing: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5A93C),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE5A93C).withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  onTap: () => _playSermon(sermon),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(AskWingAIState state) {
    // Get messages from state
    final messages = _getMessages(state);

    if (_showDashboard || messages.isEmpty) {
      // Find the last user question if any
      String? lastQuestion;
      for (int i = messages.length - 1; i >= 0; i--) {
        if (messages[i].isUserMessage) {
          lastQuestion = messages[i].content;
          break;
        }
      }

      return WelcomeMessage(
        onQuestionTap: (question) => _submitQuestion(question, state),
        userName: _currentUser?.firstName,
        hasPreviousChat: messages.isNotEmpty,
        lastQuestion: lastQuestion,
        messageCount: messages.length,
        onContinuePreviousChat: () {
          setState(() {
            _showDashboard = false;
          });
          _scrollToBottom();
        },
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
    if (state is AskWingAIClearingHistory || state is AskWingAIHistoryCleared) {
      return const [];
    }
    if (state is AskWingAIReady) return state.messages;
    if (state is AskWingAIQuestionSubmitting) return state.previousMessages;
    if (state is AskWingAIQuestionSuccess) return state.messages;
    if (state is AskWingAIHistoryLoaded) return state.messages;
    if (state is AskWingAIError && state.previousMessages != null) {
      return state.previousMessages!;
    }
    return const [];
  }

  bool _canSubmitQuestion(AskWingAIState state) {
    if (state is AskWingAIQuestionSubmitting) return false;
    if (state is AskWingAIFeatureDisabled) return false;
    return true;
  }

  void _submitQuestion(String question, AskWingAIState state) async {
    final hasConsent = await AIConsentDialog.hasConsented();
    if (!hasConsent && mounted) {
      final granted = await AIConsentDialog.showConsentDialog(context);
      if (!granted) return;
    }
    if (question.trim().isEmpty) return;
    if (!mounted) return;

    final selectedMode = await ResponseModeSheet.show(context, question: question);
    if (selectedMode == null || !mounted) return;

    setState(() {
      _showDashboard = false; // Transition directly to active chat
      _matchedSermons = [];
    });

    context.read<AskWingAICubit>().submitQuestion(question, responseStyle: selectedMode.id);
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
      case 'dashboard':
        setState(() {
          _showDashboard = true;
        });
        break;
      case 'continue_chat':
        setState(() {
          _showDashboard = false;
        });
        _scrollToBottom();
        break;
      case 'privacy':
        AIConsentDialog.showConsentDialog(context, isInformationalOnly: true);
        break;
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
              setState(() {
                _matchedSermons = [];
                _showDashboard = true;
              });
              _textController.clear();
              context.read<AskWingAICubit>().clearHistory();
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chat history cleared'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
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
