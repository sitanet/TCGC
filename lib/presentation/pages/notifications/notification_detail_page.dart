import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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
    if (!_notification.isRead) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(notificationChangeNotifierProvider)
            .markAsRead(_notification.id);
        if (mounted) {
          setState(() {
            _notification = _notification.copyWith(isRead: true);
          });
        }
      });
    }
  }

  String get _displayBody {
    final body = _notification.body.trim();
    if (body.isNotEmpty) return body;
    final data = _notification.data;
    if (data == null) return '';
    final fallback =
        data['update_message'] ?? data['message'] ?? data['description'];
    return fallback?.toString().trim() ?? '';
  }

  String? get _versionLabel {
    final data = _notification.data;
    if (data == null) return null;
    final ver = data['latest_version'] ?? data['version'];
    final v = ver?.toString().trim();
    if (v == null || v.isEmpty) return null;
    return v.startsWith('v') ? v : 'Version $v';
  }

  String? get _actionUrl {
    final data = _notification.data;
    if (data == null) return null;
    for (final key in ['update_url', 'url', 'link', 'deep_link']) {
      final raw = data[key]?.toString().trim();
      if (raw != null && raw.isNotEmpty) {
        return raw;
      }
    }
    return null;
  }

  String get _actionButtonLabel {
    final type = _notification.notificationType.toLowerCase();
    final url = (_actionUrl ?? '').toLowerCase();
    if (type.contains('update') ||
        url.contains('play.google.com') ||
        url.contains('apps.apple.com') ||
        url.contains('market://')) {
      return 'Update Now';
    }
    if (type == 'live' || url.contains('/app/audio') || url.contains('/app/video')) {
      return 'Open Now';
    }
    return 'View Details';
  }

  Future<void> _openActionUrl() async {
    final raw = _actionUrl;
    if (raw == null || raw.isEmpty) return;

    var formattedUrl = raw;
    if (!kIsWeb &&
        Platform.isAndroid &&
        formattedUrl.contains('play.google.com/store/apps/details')) {
      try {
        final playUri = Uri.parse(formattedUrl);
        final appId = playUri.queryParameters['id'];
        if (appId != null && appId.isNotEmpty) {
          formattedUrl = 'market://details?id=$appId';
        }
      } catch (_) {}
    }

    if (!formattedUrl.startsWith('http://') &&
        !formattedUrl.startsWith('https://') &&
        !formattedUrl.startsWith('market://') &&
        !formattedUrl.startsWith('tcgc://')) {
      formattedUrl = 'https://$formattedUrl';
    }

    try {
      await launchUrl(
        Uri.parse(formattedUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
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
            _buildHeader(context, isDark, config),
            _buildContent(context, isDark),
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
      mobile: 68.0,
      tablet: 84.0,
      desktop: 96.0,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(spacing, spacing, spacing, spacing * 1.25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            config.color.withValues(alpha: 0.14),
            config.color.withValues(alpha: 0.03),
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
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [config.color, config.color.withValues(alpha: 0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(
                Responsive.largeBorderRadius(context),
              ),
              boxShadow: [
                BoxShadow(
                  color: config.color.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(config.icon, color: Colors.white, size: iconSize * 0.48),
          ),
          SizedBox(height: spacing),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: config.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: config.color.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Text(
                  config.label,
                  style: TextStyle(
                    color: config.color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (_versionLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primaryGold.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _versionLabel!,
                    style: const TextStyle(
                      color: AppColors.primaryGold,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: spacing),
          Text(
            _notification.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: Responsive.titleFontSize(context),
                ),
          ),
          SizedBox(height: spacing * 0.5),
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

  Widget _buildContent(BuildContext context, bool isDark) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final spacing = Responsive.verticalSpacing(context);
    final bodyText = _displayBody;
    final actionUrl = _actionUrl;

    return Padding(
      padding: EdgeInsets.all(horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_notification.imageUrl != null &&
              _notification.imageUrl!.isNotEmpty)
            _buildImageSection(context, isDark, spacing),
          if (bodyText.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(spacing * 1.1),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(
                  Responsive.borderRadius(context),
                ),
                border: Border.all(
                  color: isDark
                      ? AppColors.dividerDark
                      : AppColors.dividerLight.withValues(alpha: 0.8),
                  width: 1,
                ),
              ),
              child: Text(
                bodyText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.65,
                      fontSize: 15,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
              ),
            ),
            SizedBox(height: spacing * 1.5),
          ],
          if (actionUrl != null) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _openActionUrl,
                icon: const Icon(Icons.open_in_new_rounded, size: 19),
                label: Text(
                  _actionButtonLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            SizedBox(height: spacing),
          ],
          _buildActionButtons(context, spacing),
          SizedBox(height: spacing),
        ],
      ),
    );
  }

  Widget _buildImageSection(
    BuildContext context,
    bool isDark,
    double spacing,
  ) {
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
            height: 210,
            placeholder: (context, url) => Container(
              width: double.infinity,
              height: 210,
              color: isDark ? AppColors.cardDark : Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => const SizedBox.shrink(),
          ),
        ),
        SizedBox(height: spacing * 1.25),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, double spacing) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _copyToClipboard(context),
            icon: const Icon(Icons.content_copy_rounded, size: 18),
            label: const Text('Copy'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGold,
              side: const BorderSide(color: AppColors.primaryGold, width: 1.5),
              padding: EdgeInsets.symmetric(vertical: spacing * 0.75),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _shareNotification(context),
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Share'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGold,
              side: const BorderSide(color: AppColors.primaryGold, width: 1.5),
              padding: EdgeInsets.symmetric(vertical: spacing * 0.75),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _copyToClipboard(BuildContext context) async {
    final bodyText = _displayBody;
    final text = bodyText.isEmpty
        ? _notification.title
        : '${_notification.title}\n\n$bodyText';
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification copied to clipboard')),
      );
    }
  }

  Future<void> _shareNotification(BuildContext context) async {
    final bodyText = _displayBody;
    final text = bodyText.isEmpty
        ? _notification.title
        : '${_notification.title}\n\n$bodyText';
    await Share.share(text);
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
            leading: const Icon(Icons.delete_rounded, color: Colors.red),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as unread')),
      );
    } else {
      provider.markAsRead(_notification.id);
      setState(() {
        _notification = _notification.copyWith(isRead: true);
      });
    }
  }

  _NotificationConfig _getNotificationConfig() {
    switch (_notification.notificationType.toLowerCase()) {
      case 'live':
        return _NotificationConfig(
          icon: Icons.live_tv_rounded,
          color: AppColors.sardine,
          label: 'LIVE',
        );
      case 'update':
      case 'app_update':
        return _NotificationConfig(
          icon: Icons.system_update_rounded,
          color: AppColors.primaryGold,
          label: 'APP UPDATE',
        );
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
    const months = [
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
