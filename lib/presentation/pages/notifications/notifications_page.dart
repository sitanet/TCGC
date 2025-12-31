import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/app_notification.dart';
import '../../widgets/custom_app_bar.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Notifications',
        showBackButton: true,
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              if (provider.unreadCount > 0) {
                return TextButton(
                  onPressed: () => provider.markAllAsRead(),
                  child: Text(
                    'Mark all read',
                    style: TextStyle(
                      color: AppColors.primaryGold,
                      fontSize: 14,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    provider.error!,
                    style: TextStyle(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadNotifications(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll see your notifications here',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadNotifications(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: provider.notifications.length,
              itemBuilder: (context, index) {
                final notification = provider.notifications[index];
                return _NotificationTile(
                  notification: notification,
                  onTap: () => _onNotificationTap(notification, provider),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _onNotificationTap(AppNotification notification, NotificationProvider provider) {
    if (!notification.isRead) {
      provider.markAsRead(notification.id);
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Colors.transparent
              : (isDark ? AppColors.primaryGold.withValues(alpha: 0.1) : AppColors.primaryGold.withValues(alpha: 0.05)),
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white10 : Colors.black12,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getIconBackgroundColor(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getNotificationIcon(),
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.primaryGold,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(notification.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          fontSize: 12,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getNotificationIcon() {
    switch (notification.type) {
      case 'event':
        return Icons.event;
      case 'sermon':
        return Icons.headphones;
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'live':
        return Icons.live_tv;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconBackgroundColor() {
    switch (notification.type) {
      case 'event':
        return Colors.blue;
      case 'sermon':
        return Colors.purple;
      case 'wallet':
        return Colors.green;
      case 'live':
        return Colors.red;
      default:
        return AppColors.primaryGold;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
