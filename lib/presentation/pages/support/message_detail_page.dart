import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/contact_message.dart';
import '../../widgets/custom_app_bar.dart';

class MessageDetailPage extends StatelessWidget {
  final ContactMessage message;

  const MessageDetailPage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        title: message.subject,
        showBackButton: true,
      ),
      body: Column(
        children: [
          // Status banner
          _buildStatusBanner(isDark),
          // Chat messages
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // User's original message
                _buildUserMessage(isDark),
                const SizedBox(height: 16),
                // Admin reply if exists
                if (message.hasReply) ...[
                  _buildAdminReply(isDark),
                  const SizedBox(height: 16),
                ],
                // Waiting message if no reply
                if (!message.hasReply) _buildWaitingMessage(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: message.hasReply
          ? AppColors.success.withOpacity(0.1)
          : Colors.orange.withOpacity(0.1),
      child: Row(
        children: [
          Icon(
            message.hasReply ? Icons.check_circle : Icons.hourglass_empty,
            size: 18,
            color: message.hasReply ? AppColors.success : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.hasReply
                  ? 'This conversation has been resolved'
                  : 'Awaiting response from support team',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: message.hasReply ? AppColors.success : Colors.orange,
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
              message.categoryDisplay,
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

  Widget _buildUserMessage(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sender info
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryGold.withOpacity(0.2),
              child: Text(
                (message.name?.isNotEmpty == true ? message.name![0] : 'U').toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primaryGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              message.name ?? 'You',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Text(
              _formatDateTime(message.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Message bubble
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.grey[100],
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Text(
            message.message,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminReply(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Admin info
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              _formatDateTime(message.repliedAt!),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              message.repliedByName ?? 'Support Team',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
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
        ),
        const SizedBox(height: 8),
        // Reply bubble
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryGold,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Text(
            message.adminReply!,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Colors.white,
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
            'Our support team will respond to your message shortly. You\'ll receive a notification when they reply.',
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

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    String time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (difference.inDays == 0) {
      return 'Today at $time';
    } else if (difference.inDays == 1) {
      return 'Yesterday at $time';
    } else {
      return '${date.day}/${date.month}/${date.year} at $time';
    }
  }
}
