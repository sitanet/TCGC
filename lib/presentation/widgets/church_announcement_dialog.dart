import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/church_announcement_service.dart';

class ChurchAnnouncementDialog extends StatelessWidget {
  final ChurchAnnouncement announcement;

  const ChurchAnnouncementDialog({
    super.key,
    required this.announcement,
  });

  /// Static helper to display the announcement popup
  static Future<void> show(
    BuildContext context,
    ChurchAnnouncement announcement,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ChurchAnnouncementDialog(
        announcement: announcement,
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching announcement url: $e');
    }
  }

  void _dismissPermanently(BuildContext context) {
    ChurchAnnouncementService().dismissAnnouncement(announcement.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage = announcement.imageUrl != null &&
        announcement.imageUrl!.trim().isNotEmpty;
    final hasAction = announcement.linkUrl != null &&
        announcement.linkUrl!.trim().isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E222A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar with Church Badge and Close Button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFD54F),
                            AppColors.primaryGold,
                            Color(0xFFB8860B),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryGold.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'THE CITYGATE CHURCH',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: AppColors.primaryGold,
                            ),
                          ),
                          Text(
                            'Official Announcement',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),

              // Image / Flyer (if available)
              if (hasImage)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      color: isDark ? Colors.grey[900] : Colors.grey[100],
                      child: CachedNetworkImage(
                        imageUrl: announcement.imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          height: 160,
                          color: isDark ? Colors.grey[850] : Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryGold,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),

              // Title and Message Content
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcement.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (announcement.message.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        announcement.message,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    // Action Link button if link is present
                    if (hasAction) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _handleAction(context, announcement.linkUrl!),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGold,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: Text(
                            announcement.buttonText ?? 'View Details',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Dismiss Actions
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text('Remind Later'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () => _dismissPermanently(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasAction
                                  ? (isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[200])
                                  : AppColors.primaryGold,
                              foregroundColor: hasAction
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              elevation: hasAction ? 0 : 2,
                            ),
                            child: const Text(
                              'Got It',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
