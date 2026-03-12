import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/contact_message.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/custom_app_bar.dart';

class MessageDetailPage extends StatefulWidget {
  final ContactMessage message;

  const MessageDetailPage({super.key, required this.message});

  @override
  State<MessageDetailPage> createState() => _MessageDetailPageState();
}

class _MessageDetailPageState extends State<MessageDetailPage> {
  final AuthService _authService = AuthService();
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late ContactMessage _message;
  bool _isLoading = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _message = widget.message;
    _loadMessageDetails();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessageDetails() async {
    setState(() => _isLoading = true);
    try {
      final updatedMessage = await _authService.getContactMessageDetail(_message.id);
      if (mounted && updatedMessage != null) {
        setState(() {
          _message = updatedMessage;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendReply() async {
    final replyText = _replyController.text.trim();
    if (replyText.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final success = await _authService.replyToContactMessage(_message.id, replyText);
      if (mounted && success) {
        _replyController.clear();
        await _loadMessageDetails();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reply sent successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reply: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        title: _message.subject,
        showBackButton: true,
      ),
      body: Column(
        children: [
          // Status banner
          _buildStatusBanner(isDark),
          // Chat messages
          Expanded(
            child: _isLoading && _message.replies.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
                : RefreshIndicator(
                    onRefresh: _loadMessageDetails,
                    color: AppColors.primaryGold,
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        // User's original message
                        _buildMessageBubble(
                          message: _message.message,
                          senderName: _message.name ?? 'You',
                          time: _message.createdAt,
                          isSupport: false,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        // Conversation thread
                        if (_message.replies.isNotEmpty)
                          ..._message.replies.map((reply) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildMessageBubble(
                              message: reply.message,
                              senderName: reply.senderName ?? (reply.isSupport ? 'Support' : 'You'),
                              time: reply.createdAt,
                              isSupport: reply.isSupport,
                              isDark: isDark,
                            ),
                          )),
                        // Waiting message if no replies and not resolved
                        if (_message.replies.isEmpty && !_message.isResolved)
                          _buildWaitingMessage(isDark),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
          ),
          // Reply input (only if not resolved)
          if (!_message.isResolved) _buildReplyInput(isDark),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _message.isResolved
          ? AppColors.success.withOpacity(0.1)
          : Colors.orange.withOpacity(0.1),
      child: Row(
        children: [
          Icon(
            _message.isResolved ? Icons.check_circle : Icons.chat_bubble_outline,
            size: 18,
            color: _message.isResolved ? AppColors.success : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _message.isResolved
                  ? 'This conversation has been resolved'
                  : 'Conversation in progress',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _message.isResolved ? AppColors.success : Colors.orange,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _message.categoryDisplay,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String message,
    required String senderName,
    required DateTime time,
    required bool isSupport,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: isSupport ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Sender info
        Row(
          mainAxisAlignment: isSupport ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isSupport) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryGold.withOpacity(0.2),
                child: Text(
                  senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: AppColors.primaryGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (isSupport)
              Text(
                _formatDateTime(time),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                ),
              ),
            if (isSupport) const SizedBox(width: 8),
            Text(
              senderName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isSupport ? AppColors.primaryGold : null,
              ),
            ),
            if (!isSupport) const SizedBox(width: 8),
            if (!isSupport)
              Text(
                _formatDateTime(time),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                ),
              ),
            if (isSupport) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryGold,
                child: const Icon(
                  Icons.support_agent,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // Message bubble
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSupport
                ? AppColors.primaryGold
                : (isDark ? AppColors.cardDark : Colors.grey[100]),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isSupport ? 16 : 4),
              topRight: Radius.circular(isSupport ? 4 : 16),
              bottomLeft: const Radius.circular(16),
              bottomRight: const Radius.circular(16),
            ),
          ),
          child: Text(
            message,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: isSupport ? Colors.white : (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingMessage(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.schedule,
            size: 40,
            color: isDark ? Colors.grey[500] : Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'Awaiting Response',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Our support team will respond shortly. You\'ll receive a notification when they reply.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyInput(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 100),
                child: TextField(
                  controller: _replyController,
                  maxLines: null,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Type your reply...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: isDark ? AppColors.cardDark : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.primaryGold, width: 2),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.primaryGold,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isSending ? null : _sendReply,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    String time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (difference.inDays == 0) {
      return 'Today $time';
    } else if (difference.inDays == 1) {
      return 'Yesterday $time';
    } else {
      return '${date.day}/${date.month}/${date.year} $time';
    }
  }
}
