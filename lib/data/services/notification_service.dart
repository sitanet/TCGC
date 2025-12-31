import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import '../../domain/entities/app_notification.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final ApiService _apiService = ApiService();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  static const String _prefsKeyPush = 'notification_push';
  static const String _prefsKeyEmail = 'notification_email';
  static const String _prefsKeySms = 'notification_sms';
  static const String _prefsKeyEvents = 'notification_events';
  static const String _prefsKeySermons = 'notification_sermons';
  static const String _prefsKeyWallet = 'notification_wallet';

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _requestPermission();
    await _initLocalNotifications();
    await _configureFCM();
    await _getToken();
  }

  Future<void> _requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('Notification permission status: ${settings.authorizationStatus}');
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          description: 'This channel is used for important notifications.',
          importance: Importance.high,
        ),
      );
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  Future<void> _configureFCM() async {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message received: ${message.notification?.title}');

    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'This channel is used for important notifications.',
            importance: Importance.high,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('Message opened app: ${message.data}');
  }

  Future<void> _getToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('FCM Token: $_fcmToken');

      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _registerDeviceToken();
      });
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  Future<void> _registerDeviceToken() async {
    if (_fcmToken == null || !_apiService.isAuthenticated) return;

    try {
      await _apiService.post(ApiConstants.deviceRegister, {
        'token': _fcmToken,
        'platform': Platform.isAndroid ? 'android' : 'ios',
      });
      debugPrint('Device token registered');
    } catch (e) {
      debugPrint('Error registering device token: $e');
    }
  }

  Future<void> registerDevice() async {
    await _registerDeviceToken();
  }

  Future<void> unregisterDevice() async {
    if (_fcmToken == null) return;

    try {
      await _apiService.post(ApiConstants.deviceUnregister, {
        'token': _fcmToken,
      });
      debugPrint('Device token unregistered');
    } catch (e) {
      debugPrint('Error unregistering device token: $e');
    }
  }

  Future<List<AppNotification>> getNotifications() async {
    try {
      final response = await _apiService.get(ApiConstants.notifications);
      if (response.isSuccess) {
        final List<dynamic> data = response.dataList;
        return data.map((json) => AppNotification.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    }
    return [];
  }

  Future<bool> markAsRead(int notificationId) async {
    try {
      final response = await _apiService.post(
        '${ApiConstants.notificationRead}$notificationId/',
        {},
      );
      return response.isSuccess;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
    return false;
  }

  Future<bool> markAllAsRead() async {
    try {
      final response = await _apiService.post(ApiConstants.notificationReadAll, {});
      return response.isSuccess;
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
    return false;
  }

  Future<NotificationPreferences> getPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPreferences(
      pushEnabled: prefs.getBool(_prefsKeyPush) ?? true,
      emailEnabled: prefs.getBool(_prefsKeyEmail) ?? true,
      smsEnabled: prefs.getBool(_prefsKeySms) ?? false,
      eventsEnabled: prefs.getBool(_prefsKeyEvents) ?? true,
      sermonsEnabled: prefs.getBool(_prefsKeySermons) ?? true,
      walletEnabled: prefs.getBool(_prefsKeyWallet) ?? true,
    );
  }

  Future<void> savePreferences(NotificationPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyPush, preferences.pushEnabled);
    await prefs.setBool(_prefsKeyEmail, preferences.emailEnabled);
    await prefs.setBool(_prefsKeySms, preferences.smsEnabled);
    await prefs.setBool(_prefsKeyEvents, preferences.eventsEnabled);
    await prefs.setBool(_prefsKeySermons, preferences.sermonsEnabled);
    await prefs.setBool(_prefsKeyWallet, preferences.walletEnabled);

    if (_apiService.isAuthenticated) {
      try {
        await _apiService.patch(
          ApiConstants.notificationPreferences,
          preferences.toJson(),
        );
      } catch (e) {
        debugPrint('Error syncing preferences to backend: $e');
      }
    }
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'This channel is used for important notifications.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }
}
