import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import '../../domain/entities/app_notification.dart';
import 'api_service.dart';

// Check if Firebase Messaging is supported on this platform
bool get _isFirebaseMessagingSupported =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

class _NotificationChannelConfig {
  final String channelId;
  final String channelName;
  final String description;
  final Color color;
  final String summaryText;

  _NotificationChannelConfig({
    required this.channelId,
    required this.channelName,
    required this.description,
    required this.color,
    required this.summaryText,
  });
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ApiService _apiService = ApiService();

  FirebaseMessaging? get _messaging {
    if (!_isFirebaseMessagingSupported) return null;
    _firebaseMessaging ??= FirebaseMessaging.instance;
    return _firebaseMessaging;
  }

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  static const String _prefsKeyPush = 'notification_push_enabled';
  static const String _prefsKeyEmail = 'notification_email_enabled';
  static const String _prefsKeyEvents = 'notification_events_enabled';
  static const String _prefsKeyMessages = 'notification_messages_enabled';
  static const String _prefsKeyWallet = 'notification_wallet_enabled';
  static const String _prefsKeyTeens = 'notification_teens_enabled';
  static const String _prefsKeyAnnouncements =
      'notification_announcements_enabled';
  static const String _prefsKeyPromotions = 'notification_promotions_enabled';

  bool _fcmInitialized = false;

  Future<void> initialize() async {
    try {
      // Local notifications work on all platforms - initialize first
      await _initLocalNotifications();

      // Defer FCM initialization to avoid creating background engine at startup
      // This will be done when actually needed or after a delay
      Future.delayed(const Duration(seconds: 5), () => _initializeFCM());
    } catch (e) {
      debugPrint('Notification service initialization error: $e');
    }
  }

  Future<void> _initializeFCM() async {
    if (_fcmInitialized || !_isFirebaseMessagingSupported) return;
    _fcmInitialized = true;

    try {
      // Ensure Firebase is initialized
      try {
        await Firebase.initializeApp();
      } catch (_) {}

      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      await _requestPermission();
      await _configureFCM();
      await _getToken();
    } catch (e) {
      debugPrint('FCM initialization error: $e');
      _fcmInitialized = false;
    }
  }

  Future<void> _requestPermission() async {
    final messaging = _messaging;
    if (messaging == null) return;

    final settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint(
      'Notification permission status: ${settings.authorizationStatus}',
    );
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
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
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationTapped,
    );

    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      // Create multiple channels for different notification types
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          description: 'This channel is used for important notifications.',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ),
      );

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'messages_channel',
          'New Messages',
          description: 'Notifications for new sermon messages.',
          importance: Importance.high,
          enableVibration: true,
        ),
      );

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'events_channel',
          'Events',
          description: 'Notifications for upcoming events.',
          importance: Importance.high,
          enableVibration: true,
        ),
      );

      // Dedicated wallet channel with gold LED color
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'wallet_channel',
          'Wallet',
          description: 'Wallet credit and transaction notifications.',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
          ledColor: Color(0xFFD4AF37),
        ),
      );
    }
  }

  static Function(Map<String, dynamic> data)? onNotificationTapped;

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    _handleNotificationAction(response);
  }

  void _handleNotificationAction(NotificationResponse response) {
    if (response.payload == null) return;

    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      debugPrint('Notification action: ${response.actionId}, data: $data');

      if (onNotificationTapped != null) {
        onNotificationTapped!(data);
      }
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    debugPrint('Background notification tapped: ${response.payload}');
  }

  Future<void> _configureFCM() async {
    final messaging = _messaging;
    if (messaging == null) return;

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Foreground message received: ${message.notification?.title}');

    final notification = message.notification;
    final data = message.data;
    final notificationType = data['type'] ?? 'announcement';

    // ── Wallet credit — custom OPay-style layout ───────────────────────────
    if (notificationType == 'wallet_credit') {
      _showWalletCreditNotification(data);
      return;
    }

    final imageUrl =
        data['image_url'] ??
        notification?.android?.imageUrl ??
        notification?.apple?.imageUrl;

    if (notification != null) {
      // Get channel and color based on notification type
      final channelConfig = _getChannelConfig(notificationType);

      // Try to download image for large icon
      String? largeIconPath;
      String? bigPicturePath;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          largeIconPath = await _downloadAndSaveImage(imageUrl, 'largeIcon');
          bigPicturePath = await _downloadAndSaveImage(imageUrl, 'bigPicture');
        } catch (e) {
          debugPrint('Error downloading notification image: $e');
        }
      }

      // Build style information based on whether we have an image
      StyleInformation styleInfo;
      if (bigPicturePath != null) {
        styleInfo = BigPictureStyleInformation(
          FilePathAndroidBitmap(bigPicturePath),
          largeIcon: largeIconPath != null
              ? FilePathAndroidBitmap(largeIconPath)
              : null,
          contentTitle: '<b>${notification.title}</b>',
          htmlFormatContentTitle: true,
          summaryText: notification.body,
          htmlFormatSummaryText: true,
        );
      } else {
        styleInfo = BigTextStyleInformation(
          notification.body ?? '',
          contentTitle: '<b>${notification.title}</b>',
          htmlFormatContentTitle: true,
          htmlFormatBigText: true,
          summaryText: channelConfig.summaryText,
          htmlFormatSummaryText: true,
        );
      }

      // Add action buttons for message notifications
      List<AndroidNotificationAction>? actions;
      if (notificationType == 'new_message' || notificationType == 'message') {
        actions = [
          const AndroidNotificationAction(
            'play',
            '▶ Play',
            showsUserInterface: true,
          ),
        ];
      }

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelConfig.channelId,
            channelConfig.channelName,
            channelDescription: channelConfig.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            largeIcon: largeIconPath != null
                ? FilePathAndroidBitmap(largeIconPath)
                : null,
            color: channelConfig.color,
            colorized: true,
            styleInformation: styleInfo,
            enableVibration: true,
            playSound: true,
            ticker: notification.title,
            actions: actions,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            attachments: imageUrl != null
                ? [DarwinNotificationAttachment(imageUrl)]
                : null,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  // ── OPay-style wallet credit notification ──────────────────────────────────
  // Layout (expanded):
  //   ┌─────────────────────────────────────────────────────┐
  //   │  Wallet Balance (NGN)          [sender name bold]   │
  //   │  ₦12,500.00                    Amount  ₦5,000.00    │
  //   └─────────────────────────────────────────────────────┘
  void _showWalletCreditNotification(Map<String, dynamic> data) {
    const goldHex = '#D4AF37';
    const gold = Color(0xFFD4AF37);

    final currency = data['currency'] ?? 'NGN';
    final symbol = currency == 'NGN' ? '₦' : currency;

    final rawAmount = double.tryParse(data['amount'] ?? '0') ?? 0;
    final amountStr = _formatMoney(rawAmount);

    final senderName = (data['sender_name'] ?? '').toString().trim();
    final senderDisplay = senderName.isNotEmpty
        ? senderName
        : 'Transfer Received';

    // InboxStyle — sender name + amount
    final styleInfo = InboxStyleInformation(
      [
        '<b>$senderDisplay</b>',
        'Amount'
            '                    '
            '<font color="$goldHex"><b>$symbol$amountStr</b></font>',
      ],
      htmlFormatLines: true,
      contentTitle: '<font color="$goldHex"><b>Money Received 💰</b></font>',
      htmlFormatContentTitle: true,
      summaryText: '$senderDisplay · $symbol$amountStr',
      htmlFormatSummaryText: false,
    );

    _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      'Money Received 💰',
      '$senderDisplay sent you $symbol$amountStr',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'wallet_channel',
          'Wallet',
          channelDescription: 'Wallet credit and transaction notifications.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: gold,
          colorized: true,
          styleInformation: styleInfo,
          enableVibration: true,
          playSound: true,
          ticker: 'Money Received',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  /// Format a number as money string e.g. 5000.0 → "5,000.00"
  String _formatMoney(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$intPart.${parts[1]}';
  }

  Future<String?> _downloadAndSaveImage(String url, String fileName) async {
    try {
      final response = await HttpClient().getUrl(Uri.parse(url));
      final httpResponse = await response.close();
      final bytes = await consolidateHttpClientResponseBytes(httpResponse);

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName.png';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      return filePath;
    } catch (e) {
      debugPrint('Error downloading image: $e');
      return null;
    }
  }

  _NotificationChannelConfig _getChannelConfig(String type) {
    switch (type) {
      case 'new_message':
      case 'message':
        return _NotificationChannelConfig(
          channelId: 'messages_channel',
          channelName: 'New Messages',
          description: 'New sermon message available',
          color: const Color(0xFF7E57C2), // Purple
          summaryText: '<font color="#7E57C2">New Message</font>',
        );
      case 'new_event':
      case 'event':
        return _NotificationChannelConfig(
          channelId: 'events_channel',
          channelName: 'Events',
          description: 'New event notification',
          color: const Color(0xFF5C6BC0), // Indigo
          summaryText: '<font color="#5C6BC0">New Event</font>',
        );
      case 'new_teens_content':
      case 'teens':
        return _NotificationChannelConfig(
          channelId: 'high_importance_channel',
          channelName: 'Teens Content',
          description: 'New teens content available',
          color: const Color(0xFFFF7043), // Orange
          summaryText: '<font color="#FF7043">Teens Content</font>',
        );
      case 'wallet':
        return _NotificationChannelConfig(
          channelId: 'wallet_channel',
          channelName: 'Wallet',
          description: 'Wallet notification',
          color: const Color(0xFFD4AF37), // Gold
          summaryText: '<font color="#D4AF37">Wallet</font>',
        );
      default:
        return _NotificationChannelConfig(
          channelId: 'high_importance_channel',
          channelName: 'High Importance Notifications',
          description: 'Important notification',
          color: const Color(0xFFD4AF37), // Gold
          summaryText: '<font color="#D4AF37">TCGC</font>',
        );
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('Message opened app: ${message.data}');
  }

  Future<void> _getToken() async {
    final messaging = _messaging;
    if (messaging == null) return;

    try {
      _fcmToken = await messaging.getToken();
      debugPrint('FCM Token: $_fcmToken');

      // Register device in background (don't block initialization)
      _registerDeviceToken();

      messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _registerDeviceToken();
      });
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  Future<void> _registerDeviceToken() async {
    if (_fcmToken == null) return;

    try {
      // Register device even without authentication (for anonymous users to receive notifications)
      final response = await _apiService.post(ApiConstants.deviceRegister, {
        'fcm_token': _fcmToken,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'device_name': Platform.isAndroid ? 'Android Device' : 'iOS Device',
      });
      if (response.isSuccess) {
        debugPrint('Device token registered successfully');
      } else {
        debugPrint('Device registration failed: ${response.errorMessage}');
      }
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
        'fcm_token': _fcmToken,
      });
      debugPrint('Device token unregistered');
    } catch (e) {
      debugPrint('Error unregistering device token: $e');
    }
  }

  Future<List<AppNotification>> getNotifications() async {
    try {
      final response = await _apiService.get(ApiConstants.notifications);
      debugPrint(
        'Notifications response: ${response.statusCode} - ${response.body}',
      );

      if (response.isSuccess) {
        // Handle both paginated and non-paginated responses
        List<dynamic> data;

        try {
          // Try to parse as list first
          data = response.dataList;
        } catch (e) {
          // If it's a map with 'results' key (paginated)
          final decoded = response.data;
          if (decoded.containsKey('results')) {
            data = decoded['results'] as List<dynamic>;
          } else {
            data = [];
          }
        }

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
      final response = await _apiService.post(
        ApiConstants.notificationReadAll,
        {},
      );
      return response.isSuccess;
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
    return false;
  }

  Future<NotificationPreferences> getPreferences() async {
    // Ensure tokens are loaded before checking authentication
    await _apiService.loadTokens();

    // Try to fetch from backend first if authenticated
    if (_apiService.isAuthenticated) {
      try {
        final response = await _apiService.get(
          ApiConstants.notificationPreferences,
        );
        if (response.isSuccess) {
          final prefs = NotificationPreferences.fromJson(response.data);
          // Save to local storage
          await _savePreferencesLocally(prefs);
          return prefs;
        }
      } catch (e) {
        debugPrint('Error fetching preferences from backend: $e');
      }
    }

    // Fall back to local storage
    final prefs = await SharedPreferences.getInstance();
    return NotificationPreferences(
      pushEnabled: prefs.getBool(_prefsKeyPush) ?? true,
      emailEnabled: prefs.getBool(_prefsKeyEmail) ?? true,
      eventsEnabled: prefs.getBool(_prefsKeyEvents) ?? true,
      messagesEnabled: prefs.getBool(_prefsKeyMessages) ?? true,
      walletEnabled: prefs.getBool(_prefsKeyWallet) ?? true,
      teensEnabled: prefs.getBool(_prefsKeyTeens) ?? true,
      announcementsEnabled: prefs.getBool(_prefsKeyAnnouncements) ?? true,
      promotionsEnabled: prefs.getBool(_prefsKeyPromotions) ?? true,
    );
  }

  Future<void> _savePreferencesLocally(
    NotificationPreferences preferences,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyPush, preferences.pushEnabled);
    await prefs.setBool(_prefsKeyEmail, preferences.emailEnabled);
    await prefs.setBool(_prefsKeyEvents, preferences.eventsEnabled);
    await prefs.setBool(_prefsKeyMessages, preferences.messagesEnabled);
    await prefs.setBool(_prefsKeyWallet, preferences.walletEnabled);
    await prefs.setBool(_prefsKeyTeens, preferences.teensEnabled);
    await prefs.setBool(
      _prefsKeyAnnouncements,
      preferences.announcementsEnabled,
    );
    await prefs.setBool(_prefsKeyPromotions, preferences.promotionsEnabled);
  }

  /// Returns true if saved successfully (locally and to backend if authenticated)
  Future<bool> savePreferences(NotificationPreferences preferences) async {
    // Save locally first - this always works
    await _savePreferencesLocally(preferences);

    // Ensure tokens are loaded before checking authentication
    await _apiService.loadTokens();

    // Sync to backend if authenticated
    if (_apiService.isAuthenticated) {
      try {
        final response = await _apiService.patch(
          ApiConstants.notificationPreferences,
          preferences.toJson(),
        );
        if (response.isSuccess) {
          debugPrint('Preferences synced to backend successfully');
          return true;
        } else {
          debugPrint('Failed to sync preferences: ${response.errorMessage}');
          // Still return true since local save worked
          return true;
        }
      } catch (e) {
        debugPrint('Error syncing preferences to backend: $e');
        // Still return true since local save worked
        return true;
      }
    } else {
      debugPrint('User not authenticated - preferences saved locally only');
    }

    // Not authenticated - local save is enough
    return true;
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
          channelDescription:
              'This channel is used for important notifications.',
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
