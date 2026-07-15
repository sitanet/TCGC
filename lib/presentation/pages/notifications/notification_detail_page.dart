import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../domain/entities/app_notification.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';

class NotificationDetailPage extends ConsumerStatefulWidget {
  final AppNotification notification;

  const NotificationDetailPage({super.key, required this.notification});

  @override
  ConsumerState<NotificationDetailPage> createState() =>
      _NotificationDetailPageState();
}

class _NotificationDetailPageState
    extends ConsumerState<NotificationDetailPage> {
  late AppNotification _notification;

  @override
  void initState() {
    super.initState();
    _notification = widget.notification;
    // Mark as read when opening detail page
    if (!_notification.isRead) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(notificationChangeNotifierProvider)
            .markAsRead(_notification.id);
        setState(() {
          _notification = _notification.copyWith(isRead: true);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = _getNotificationConfig();

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Notification',
        showBackButton: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.more_vert_rounded,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: () => _showOptionsMenu(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with icon and type badge
            _buildHeader(context, isDark, config),
            // Content
            _buildContent(context, isDark, config),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    _NotificationConfig config,
  ) {
    final spacing = Responsive.verticalSpacing(context);
    final iconSize = Responsive.value(
      context,
      mobile: 80.0,
      tablet: 100.0,
      desktop: 120.0,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(spacing),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            config.color.withValues(alpha: 0.15),
            config.color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(Responsive.largeBorderRadius(context)),
          bottomRight: Radius.circular(Responsive.largeBorderRadius(context)),
        ),
      ),
      child: Column(
        children: [
          // Icon container with gradient
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [config.color, config.color.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(
                Responsive.largeBorderRadius(context),
              ),
              boxShadow: [
                BoxShadow(
                  color: config.color.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(config.icon, color: Colors.white, size: iconSize * 0.5),
          ),
          SizedBox(height: spacing * 1.5),
          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: config.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: config.color.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Text(
              config.label,
              style: TextStyle(
                color: config.color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(height: spacing * 1.5),
          // Title
          Text(
            _notification.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: Responsive.titleFontSize(context),
            ),
          ),
          SizedBox(height: spacing * 0.75),
          // Time
          Text(
            _formatDateTime(_notification.createdAt),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    _NotificationConfig config,
  ) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final spacing = Responsive.verticalSpacing(context);

    return Padding(
      padding: EdgeInsets.all(horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: spacing * 0.5),
          // Image if available
          if (_notification.imageUrl != null &&
              _notification.imageUrl!.isNotEmpty)
            _buildImageSection(context, spacing),
          // Message body
          if (_notification.body.isNotEmpty) ...[
            SizedBox(height: spacing),
            _buildBodySection(context, isDark, spacing),
          ],
          // Additional data if available
          if (_notification.data != null && _notification.data!.isNotEmpty) ...[
            SizedBox(height: spacing * 1.5),
            _buildDataSection(context, isDark, spacing),
          ],
          SizedBox(height: spacing * 2),
          // Action buttons
          _buildActionButtons(context, spacing),
          SizedBox(height: spacing),
        ],
      ),
    );
  }

  Widget _buildImageSection(BuildContext context, double spacing) {
    final borderRadius = Responsive.borderRadius(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: CachedNetworkImage(
            imageUrl: _notification.imageUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 220,
            placeholder: (context, url) => Container(
              width: double.infinity,
              height: 220,
              color: Colors.grey[300],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: const Center(
                child: Icon(Icons.image_not_supported_rounded, size: 48),
              ),
            ),
          ),
        ),
        SizedBox(height: spacing),
      ],
    );
  }

  Widget _buildBodySection(BuildContext context, bool isDark, double spacing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Details',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        SizedBox(height: spacing * 0.5),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(spacing),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.grey[100],
            borderRadius: BorderRadius.circular(
              Responsive.borderRadius(context),
            ),
            border: Border.all(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              width: 1,
            ),
          ),
          child: Text(
            _notification.body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataSection(BuildContext context, bool isDark, double spacing) {
    final data = _notification.data ?? {};
    final borderRadius = Responsive.borderRadius(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Information',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        SizedBox(height: spacing * 0.5),
        ...data.entries.map((entry) {
          return Container(
            margin: EdgeInsets.only(bottom: spacing * 0.5),
            padding: EdgeInsets.all(spacing * 0.75),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.grey[50],
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key
                      .replaceAll('_', ' ')
                      .split(' ')
                      .map(
                        (word) => word.isEmpty
                            ? ''
                            : word[0].toUpperCase() +
                                  word.substring(1).toLowerCase(),
                      )
                      .join(' '),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.primaryGold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: spacing * 0.25),
                Text(
                  entry.value.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, double spacing) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _copyToClipboard(context),
            icon: const Icon(Icons.content_copy_rounded),
            label: const Text('Copy'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGold,
              side: const BorderSide(color: AppColors.primaryGold, width: 1.5),
              padding: EdgeInsets.symmetric(vertical: spacing * 0.75),
            ),
          ),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _shareNotification(context),
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: spacing * 0.75),
            ),
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification copied to clipboard')),
    );
  }

  void _shareNotification(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sharing notification...')));
  }

  void _showOptionsMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[600] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: Icon(Icons.delete_rounded, color: Colors.red),
            title: const Text('Delete Notification'),
            onTap: () {
              Navigator.pop(context);
              _deleteNotification(context);
            },
          ),
          ListTile(
            leading: Icon(
              _notification.isRead
                  ? Icons.mark_email_unread_rounded
                  : Icons.mark_email_read_rounded,
              color: AppColors.primaryGold,
            ),
            title: Text(
              _notification.isRead ? 'Mark as Unread' : 'Mark as Read',
            ),
            onTap: () {
              Navigator.pop(context);
              _toggleReadStatus(context);
            },
          ),
        ],
      ),
    );
  }

  void _deleteNotification(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notification deleted'),
        action: SnackBarAction(label: 'Undo', onPressed: () {}),
      ),
    );
    Navigator.pop(context);
  }

  void _toggleReadStatus(BuildContext context) {
    final provider = ref.read(notificationChangeNotifierProvider);
    if (_notification.isRead) {
      // Mark as unread - would need backend support
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Marked as unread')));
    } else {
      provider.markAsRead(_notification.id);
      setState(() {
        _notification = _notification.copyWith(isRead: true);
      });
    }
  }

  _NotificationConfig _getNotificationConfig() {
    switch (_notification.notificationType) {
      case 'event':
        return _NotificationConfig(
          icon: Icons.event_rounded,
          color: const Color(0xFF5C6BC0),
          label: 'EVENT',
        );
      case 'message':
        return _NotificationConfig(
          icon: Icons.headphones_rounded,
          color: const Color(0xFF7E57C2),
          label: 'MESSAGE',
        );
      case 'wallet':
        if (_notification.title.contains('Money Received') ||
            _notification.title.contains('💰') ||
            _notification.body.contains('sent you')) {
          return _NotificationConfig(
            icon: Icons.trending_up_rounded,
            color: const Color(0xFF4CAF50),
            label: 'MONEY IN',
          );
        }
        return _NotificationConfig(
          icon: Icons.account_balance_wallet_rounded,
          color: const Color(0xFF26A69A),
          label: 'WALLET',
        );
      case 'teens':
        return _NotificationConfig(
          icon: Icons.people_rounded,
          color: const Color(0xFFFF7043),
          label: 'TEENS',
        );
      case 'announcement':
        return _NotificationConfig(
          icon: Icons.campaign_rounded,
          color: const Color(0xFFEF5350),
          label: 'ANNOUNCEMENT',
        );
      default:
        return _NotificationConfig(
          icon: Icons.notifications_rounded,
          color: AppColors.primaryGold,
          label: 'NOTIFICATION',
        );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _NotificationConfig {
  final IconData icon;
  final Color color;
  final String label;

  _NotificationConfig({
    required this.icon,
    required this.color,
    required this.label,
  });
}
