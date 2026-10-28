import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/promotion.dart';
import '../../domain/entities/app_notification.dart';
import 'data_service.dart';
import 'notification_service.dart';

/// Unified Church Announcement model representing messages posted
/// from either the Promotions or Notifications/Announcements backend.
class ChurchAnnouncement {
  final String id;
  final String title;
  final String message;
  final String? imageUrl;
  final String? linkUrl;
  final String? buttonText;
  final DateTime createdAt;
  final bool isFromPromotion;

  ChurchAnnouncement({
    required this.id,
    required this.title,
    required this.message,
    this.imageUrl,
    this.linkUrl,
    this.buttonText,
    required this.createdAt,
    this.isFromPromotion = false,
  });
}

class ChurchAnnouncementService {
  static final ChurchAnnouncementService _instance =
      ChurchAnnouncementService._internal();
  factory ChurchAnnouncementService() => _instance;
  ChurchAnnouncementService._internal();

  final DataService _dataService = DataService();
  final NotificationService _notificationService = NotificationService();

  static const String _dismissedKey = 'dismissed_church_announcements_v1';

  /// Get the latest active church announcement that has not been dismissed
  Future<ChurchAnnouncement?> getLatestAnnouncement() async {
    try {
      ChurchAnnouncement? candidate;

      // 1. Check Promotions (/promotions/active/)
      try {
        final List<Promotion> promotions =
            await _dataService.getActivePromotions();
        if (promotions.isNotEmpty) {
          // Sort by priority desc, then createdAt desc
          final sortedPromos = List<Promotion>.from(promotions)
            ..sort((a, b) {
              final priorityComp = b.priority.compareTo(a.priority);
              if (priorityComp != 0) return priorityComp;
              return b.createdAt.compareTo(a.createdAt);
            });

          final topPromo = sortedPromos.first;
          if (topPromo.isActive) {
            candidate = ChurchAnnouncement(
              id: 'promo_${topPromo.id}',
              title: topPromo.title,
              message: topPromo.description ?? '',
              imageUrl: topPromo.imageUrl.isNotEmpty ? topPromo.imageUrl : null,
              linkUrl: topPromo.linkUrl,
              buttonText: topPromo.linkUrl != null ? 'Learn More' : null,
              createdAt: topPromo.createdAt,
              isFromPromotion: true,
            );
          }
        }
      } catch (e) {
        debugPrint('Error fetching promotions for announcement: $e');
      }

      // 2. Check Notifications/Announcements (/notifications/)
      try {
        final List<AppNotification> notifications =
            await _notificationService.getNotifications();
        if (notifications.isNotEmpty) {
          // Filter for announcements or global broadcast messages
          final announcements = notifications.where((n) =>
              n.notificationType.toLowerCase() == 'announcement' ||
              n.isGlobal == true).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (announcements.isNotEmpty) {
            final topNotif = announcements.first;
            final notifAnnouncement = ChurchAnnouncement(
              id: 'notif_${topNotif.id}',
              title: topNotif.title,
              message: topNotif.body,
              imageUrl: topNotif.imageUrl,
              linkUrl: topNotif.data?['url'] ?? topNotif.data?['link'],
              buttonText: (topNotif.data?['url'] != null ||
                      topNotif.data?['link'] != null)
                  ? 'Open Link'
                  : null,
              createdAt: topNotif.createdAt,
              isFromPromotion: false,
            );

            // If no promotion candidate exists, or this announcement is newer, use it
            if (candidate == null ||
                notifAnnouncement.createdAt.isAfter(candidate.createdAt)) {
              candidate = notifAnnouncement;
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching notifications for announcement: $e');
      }

      if (candidate == null) return null;

      // 3. Verify if user has already dismissed this specific announcement
      final isDismissed = await isAnnouncementDismissed(candidate.id);
      if (isDismissed) {
        return null;
      }

      return candidate;
    } catch (e) {
      debugPrint('Error evaluating latest church announcement: $e');
      return null;
    }
  }

  /// Check whether an announcement was dismissed
  Future<bool> isAnnouncementDismissed(String announcementId) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissedList = prefs.getStringList(_dismissedKey) ?? [];
    return dismissedList.contains(announcementId);
  }

  /// Mark announcement as dismissed so it doesn't pop up again
  Future<void> dismissAnnouncement(String announcementId) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissedList = prefs.getStringList(_dismissedKey) ?? [];
    if (!dismissedList.contains(announcementId)) {
      dismissedList.add(announcementId);
      await prefs.setStringList(_dismissedKey, dismissedList);
    }
  }

  /// Reset dismissed announcements (for testing/debugging)
  Future<void> clearDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dismissedKey);
  }
}
