import 'package:flutter/foundation.dart';
import '../../data/services/notification_service.dart';
import '../../domain/entities/app_notification.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();

  List<AppNotification> _notifications = [];
  NotificationPreferences _preferences = NotificationPreferences();
  bool _isLoading = false;
  String? _error;

  List<AppNotification> get notifications => _notifications;
  List<AppNotification> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();
  int get unreadCount => unreadNotifications.length;
  NotificationPreferences get preferences => _preferences;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> initialize() async {
    await _notificationService.initialize();
    await loadPreferences();
  }

  Future<void> registerDevice() async {
    await _notificationService.registerDevice();
  }

  Future<void> unregisterDevice() async {
    await _notificationService.unregisterDevice();
  }

  Future<void> loadNotifications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _notifications = await _notificationService.getNotifications();
    } catch (e) {
      _error = 'Failed to load notifications';
      debugPrint('Error loading notifications: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAsRead(int notificationId) async {
    final success = await _notificationService.markAsRead(notificationId);
    if (success) {
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        notifyListeners();
      }
    }
  }

  Future<void> markAllAsRead() async {
    final success = await _notificationService.markAllAsRead();
    if (success) {
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      notifyListeners();
    }
  }

  Future<void> loadPreferences() async {
    try {
      _preferences = await _notificationService.getPreferences();
    } catch (e) {
      debugPrint('Error loading preferences: $e');
      // Use default preferences on error
      _preferences = NotificationPreferences();
    }
    notifyListeners();
  }

  Future<bool> updatePreferences(NotificationPreferences newPreferences) async {
    _preferences = newPreferences;
    notifyListeners();
    return await _notificationService.savePreferences(newPreferences);
  }

  Future<bool> setPushEnabled(bool enabled) async {
    return await updatePreferences(_preferences.copyWith(pushEnabled: enabled));
  }

  Future<bool> setEmailEnabled(bool enabled) async {
    return await updatePreferences(_preferences.copyWith(emailEnabled: enabled));
  }

  Future<bool> setEventsEnabled(bool enabled) async {
    return await updatePreferences(_preferences.copyWith(eventsEnabled: enabled));
  }

  Future<bool> setMessagesEnabled(bool enabled) async {
    return await updatePreferences(_preferences.copyWith(messagesEnabled: enabled));
  }

  Future<bool> setWalletEnabled(bool enabled) async {
    return await updatePreferences(_preferences.copyWith(walletEnabled: enabled));
  }

  Future<bool> setTeensEnabled(bool enabled) async {
    return await updatePreferences(_preferences.copyWith(teensEnabled: enabled));
  }

  Future<bool> setAnnouncementsEnabled(bool enabled) async {
    return await updatePreferences(_preferences.copyWith(announcementsEnabled: enabled));
  }

  void clearNotifications() {
    _notifications = [];
    notifyListeners();
  }
}
