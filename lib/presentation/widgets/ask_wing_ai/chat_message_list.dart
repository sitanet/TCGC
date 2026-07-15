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
    return ListView.builder(
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
        return ChatMessageBubble(
          key: ValueKey(message.id),
          message: message,
        );
      },
    );
  }
}
