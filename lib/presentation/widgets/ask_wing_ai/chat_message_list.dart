import 'package:flutter/material.dart';
import '../../../data/models/ask_wing_ai/chat_message_model.dart';
import 'chat_message_bubble.dart';
import 'loading_indicator.dart';

/// Scrollable list of chat messages
class ChatMessageList extends StatelessWidget {
  final List<ChatMessageModel> messages;
  final ScrollController scrollController;
  final bool isLoading;

  const ChatMessageList({
    Key? key,
    required this.messages,
    required this.scrollController,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: scrollController,
      thumbVisibility: true,
      thickness: 6.0,
      radius: const Radius.circular(3),
      interactive: true,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: messages.length + (isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          // Show loading indicator at the end
          if (isLoading && index == messages.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: LoadingIndicator(),
            );
          }

          final message = messages[index];
          final showDateHeader = index == 0 ||
              !_isSameDay(messages[index - 1].createdAt, message.createdAt);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showDateHeader) _buildDateHeader(context, message.createdAt),
              ChatMessageBubble(
                key: ValueKey(message.id),
                message: message,
              ),
            ],
          );
        },
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDateHeader(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    String label;
    if (msgDate == today) {
      label = 'Today';
    } else if (msgDate == yesterday) {
      label = 'Yesterday';
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      label = '${months[date.month - 1]} ${date.day}, ${date.year}';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
