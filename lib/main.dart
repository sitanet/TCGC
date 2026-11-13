import 'dart:async'
    show Future, StreamSubscription, runZonedGuarded;
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/theme_provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/notification_provider.dart';
import 'core/providers/audio_player_provider.dart';
import 'core/providers/wallet_provider.dart';
import 'core/providers/biometric_provider.dart';
import 'core/providers/app_config_provider.dart';
import 'presentation/pages/home/home_page.dart';
import 'presentation/pages/audio/audio_page.dart';
import 'presentation/pages/livestream/livestream_page.dart';
import 'presentation/pages/wallet/wallet_page.dart';
import 'presentation/pages/teens/teens_page.dart';
import 'presentation/pages/community/community_page.dart';
import 'presentation/pages/get_started/get_started_page.dart';
import 'presentation/pages/auth/sign_in_page.dart';
import 'presentation/pages/auth/sign_up_page.dart';
import 'presentation/pages/auth/signup_success_page.dart';
import 'data/services/interests_service.dart';
import 'presentation/widgets/bottom_nav_bar.dart';
import 'presentation/widgets/mini_player.dart';
import 'presentation/widgets/promotion_popup.dart';
import 'presentation/widgets/ready_to_play_popup.dart';
import 'presentation/widgets/app_update_card.dart';
import 'data/services/data_service.dart' show DataService, AppUpdateInfo;
import 'data/services/notification_service.dart';
import 'presentation/pages/audio/audio_player_page.dart';
import 'presentation/pages/audio/transcript_list_page.dart';
import 'domain/entities/transcript.dart';
import 'domain/entities/promotion.dart';
import 'core/widgets/network_aware_widget.dart';
import 'data/services/biometric_service.dart';
import 'core/providers/community_provider.dart';
import 'core/services/image_cache_service.dart';
import 'presentation/bloc/ask_wing_ai/ask_wing_ai_cubit.dart';
import 'data/services/ask_wing_ai_service.dart';
import 'core/services/token_service.dart';
import 'core/utils/error_handler.dart';

final communityChangeNotifierProvider =
    ChangeNotifierProvider<CommunityProvider>((ref) => CommunityProvider());

const String appVersion = '1.0.3';

// Riverpod providers wrapping ChangeNotifier classes
final themeChangeNotifierProvider = ChangeNotifierProvider<ThemeProvider>(
  (ref) => ThemeProvider(),
);
final authChangeNotifierProvider = ChangeNotifierProvider<AuthProvider>(
  (ref) => AuthProvider(),
);
final notificationChangeNotifierProvider =
    ChangeNotifierProvider<NotificationProvider>(
      (ref) => NotificationProvider(),
    );
final walletChangeNotifierProvider = ChangeNotifierProvider<WalletProvider>(
  (ref) => WalletProvider(),
);
final audioPlayerChangeNotifierProvider =
    ChangeNotifierProvider<AudioPlayerProvider>((ref) => AudioPlayerProvider());
final biometricChangeNotifierProvider =
    ChangeNotifierProvider<BiometricProvider>((ref) => BiometricProvider());
final appConfigChangeNotifierProvider =
    ChangeNotifierProvider<AppConfigProvider>((ref) => AppConfigProvider());

// Navigation provider to allow tab pages to navigate to home
final mainTabIndexProvider = StateProvider<int>((ref) => 0);
// Sub-tab navigation provider for LiveStream (0: Audio / Stream Live, 1: Video / Watch Live)
final liveStreamSubTabIndexProvider = StateProvider<int>((ref) => 0);

void main() async {
  // Catch Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Flutter error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  // Run the app with error zone for async errors
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Enable edge-to-edge display so the system navigation bar is transparent
      // and doesn't overlap the app's bottom nav bar on any Android device
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );

      // Initialize image cache with conservative memory limits first
      ImageCacheService.initialize();

      // Fast restore cached session before running app so first frame renders the actual target page
      final initialAuthProvider = AuthProvider();
      try {
        await initialAuthProvider.initialize().timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            debugPrint('Fast auth initialization timed out');
          },
        );
      } catch (e) {
        debugPrint('Fast auth initialization error: $e');
      }

      // Initialize Firebase and background messaging handler early for reliable background/killed push delivery
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        try {
          await Firebase.initializeApp();
          FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
          debugPrint('Firebase & background messaging handler registered early');
        } catch (e) {
          debugPrint('Firebase early init error: $e');
        }
      }

      // Start the app with the pre-restored session
      runApp(
        ProviderScope(
          overrides: [
            authChangeNotifierProvider.overrideWith((ref) => initialAuthProvider),
          ],
          child: const MyApp(),
        ),
      );

      // Initialize AudioService in background with delay to let UI render first
      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          await initAudioService().timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              debugPrint('Audio service initialization timed out');
              throw TimeoutException('Audio service init timeout');
            },
          );
        } catch (e) {
          debugPrint('Audio service initialization error: $e');
        }
      });
    },
    (error, stackTrace) {
      debugPrint('Uncaught async error: $error');
      debugPrint('Stack trace: $stackTrace');
    },
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _showGetStarted = true;
  bool _showSignUp = false;
  String? _prefilledLoginEmail;
  final InterestsService _interestsService = InterestsService();
  final DataService _dataService = DataService();
  AppUpdateInfo? _updateInfo;
  bool _showUpdateDialog = false;

  Future<void> _checkForAppUpdate() async {
    try {
      String platform = 'all';
      if (!kIsWeb) {
        if (Platform.isAndroid) {
          platform = 'android';
        } else if (Platform.isIOS) {
          platform = 'ios';
        }
      }

      // Dynamically load exact version name & build number from app package
      String currentVersion = appVersion; // fallback
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        currentVersion = '${packageInfo.version}.${packageInfo.buildNumber}';
        debugPrint('Dynamic app version detected: $currentVersion');
      } catch (e) {
        debugPrint('Error getting package info: $e');
      }

      final updateInfo = await _dataService.checkForAppUpdate(
        currentVersion,
        platform,
      );
      if (updateInfo != null && updateInfo.updateAvailable && mounted) {
        setState(() {
          _updateInfo = updateInfo;
          _showUpdateDialog = true;
        });
      }
    } catch (e) {
      debugPrint('Update check error: $e');
    }
  }

  void _closeUpdateDialog() {
    if (_updateInfo?.forceUpdate == true) {
      return;
    }
    setState(() {
      _showUpdateDialog = false;
    });
  }

  Future<void> _openUpdateUrl() async {
    debugPrint('Update Now button clicked');

    String? url = _updateInfo?.updateUrl;
    if (url == null || url.trim().isEmpty) {
      if (!kIsWeb) {
        if (Platform.isAndroid) {
          url = 'https://play.google.com/store/apps/details?id=com.tcgc.tcgc';
        } else if (Platform.isIOS) {
          url = 'https://apps.apple.com/us/app/citygate-mobile/id6821748352';
        }
      }
    }
    
    if (url != null && url.isNotEmpty) {
      String formattedUrl = url.trim();
      
      // Convert Play Store https links to native market:// scheme on Android
      // to bypass browser-hijacking apps (like OPay) that throw SecurityExceptions
      if (!kIsWeb && Platform.isAndroid && formattedUrl.contains('play.google.com/store/apps/details')) {
        try {
          final playStoreUri = Uri.parse(formattedUrl);
          final appId = playStoreUri.queryParameters['id'];
          if (appId != null && appId.isNotEmpty) {
            formattedUrl = 'market://details?id=$appId';
          }
        } catch (e) {
          debugPrint('Error parsing Play Store URL: $e');
        }
      }
      
      // Ensure the URL has a valid scheme for other cases
      if (!formattedUrl.startsWith('http://') && 
          !formattedUrl.startsWith('https://') && 
          !formattedUrl.startsWith('market://')) {
        formattedUrl = 'https://$formattedUrl';
      }
      
      final uri = Uri.parse(formattedUrl);
      debugPrint('Attempting to launch: $formattedUrl');
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Could not launch update URL: $e');
        // Secondary fallback - try opening play store directly using native market scheme
        if (!kIsWeb && Platform.isAndroid) {
          try {
            await launchUrl(
              Uri.parse('market://details?id=com.tcgc.tcgc'),
              mode: LaunchMode.externalApplication,
            );
          } catch (fallbackError) {
            debugPrint('Fallback launch also failed: $fallbackError');
          }
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    try {
      final authProvider = ref.read(authChangeNotifierProvider);

      // Restore session from local storage cache (< 5ms, non-network)
      await authProvider.initialize().timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('Auth initialization timed out');
        },
      );

      if (authProvider.isAuthenticated) {
        _showGetStarted = false;
      }
    } catch (e) {
      debugPrint('Auth initialization error: $e');
    } finally {
      if (mounted) {
        _checkForAppUpdate();
      }
    }

    // Initialize non-critical services in background
    Future.microtask(() async {
      try {
        await _interestsService.initialize().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint('Interests initialization timed out');
          },
        );

        _initializeNotifications();
      } catch (e) {
        debugPrint('Background initialization error: $e');
      }
    });
  }

  Future<void> _initializeNotifications() async {
    // Delay notification init to let UI render first
    Future.delayed(const Duration(seconds: 1), () async {
      try {
        await ref.read(notificationChangeNotifierProvider).initialize();
      } catch (e) {
        debugPrint('Notification initialization error: $e');
      }
    });
  }

  void _onAuthenticated() {
    setState(() {
      _prefilledLoginEmail = null;
      _showGetStarted = false;
      _showSignUp = false;
    });
    // Link device token with the authenticated user for push notifications
    NotificationService().registerDevice();
    // Start pre-buffering all messages in background after login
    _startBackgroundPreBuffering();
  }

  Future<void> _startBackgroundPreBuffering() async {
    // Disabled heavy background caching to prevent ANR issues
    // Data will be fetched on demand from screens
    debugPrint('Background pre-buffering disabled to prevent ANR');
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ref.watch(themeChangeNotifierProvider);
    final authProvider = ref.watch(authChangeNotifierProvider);


    if (_showUpdateDialog && _updateInfo != null) {
      return MaterialApp(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        title: 'TCGC',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeProvider.themeMode,
        home: AppUpdateScreen(
          updateInfo: _updateInfo!,
          onUpdateNow: _openUpdateUrl,
          onClose: _closeUpdateDialog,
        ),
      );
    }

    Widget homeWidget;

    // 1. If authenticated, show main app
    if (authProvider.isAuthenticated) {
      homeWidget = const NetworkAwareWidget(child: MainScreen());
    }
    // 2. If user registered or attempted login but email is unverified,
    // persist state and open confirmation/resend page directly (even after app close & restart)
    else if (authProvider.pendingVerificationEmail != null &&
        authProvider.pendingVerificationEmail!.isNotEmpty) {
      homeWidget = SignupSuccessPage(
        email: authProvider.pendingVerificationEmail!,
        onGoToLogin: () {
          final email = authProvider.pendingVerificationEmail;
          authProvider.clearPendingVerificationEmail();
          setState(() {
            _prefilledLoginEmail = email;
            _showGetStarted = false;
            _showSignUp = false;
          });
        },
        onResendEmail: () async {
          return await authProvider.resendConfirmationEmail(
            authProvider.pendingVerificationEmail!,
          );
        },
        onCheckVerification: () async {
          return await authProvider.checkEmailVerification(
            authProvider.pendingVerificationEmail!,
          );
        },
        onChangeEmail: () {
          authProvider.clearPendingVerificationEmail();
          setState(() {
            _prefilledLoginEmail = null;
            _showGetStarted = false;
            _showSignUp = true;
          });
        },
      );
    } else if (_showGetStarted) {
      homeWidget = GetStartedPage(
        onSignIn: () {
          setState(() {
            _showGetStarted = false;
            _showSignUp = false;
          });
        },
        onSignUp: () {
          setState(() {
            _showGetStarted = false;
            _showSignUp = true;
          });
        },
      );
    } else if (_showSignUp) {
      homeWidget = SignUpPage(
        onSignUp: _onAuthenticated,
        onBack: () {
          setState(() {
            _showGetStarted = true;
          });
        },
        onGoToSignIn: () {
          setState(() {
            _showSignUp = false;
          });
        },
      );
    } else {
      homeWidget = SignInPage(
        initialEmail: _prefilledLoginEmail,
        onSignIn: _onAuthenticated,
        onBack: () {
          setState(() {
            _showGetStarted = true;
          });
        },
        onGoToSignUp: () {
          setState(() {
            _showSignUp = true;
          });
        },
      );
    }

    return MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'TCGC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: homeWidget,
    );
  }
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver {
  bool _showPromotion = false;
  bool _showReadyToPlayPopup = false;
  bool _walletAuthenticated = false;
  List<Promotion> _activePromotions = [];
  final DataService _dataService = DataService();
  StreamSubscription? _deepLinkSub;
  late AskWingAICubit _askWingAICubit;

  static const String _lastTabKey = 'last_tab_index';

  // Pages are built lazily to prevent ANR from heavy pages like LiveStreamPage
  Widget _buildPage(int index, bool showWallet) {
    if (!showWallet) {
      switch (index) {
        case 0:
          return const HomePage();
        case 1:
          return const AudioPage();
        case 2:
          return const LiveStreamPage();
        case 3:
          return const TeensPage();
        case 4:
          return const CommunityPage();
        default:
          return const HomePage();
      }
    }

    switch (index) {
      case 0:
        return const HomePage();
      case 1:
        return const AudioPage();
      case 2:
        return const LiveStreamPage();
      case 3:
        return const WalletPage();
      case 4:
        return const TeensPage();
      case 5:
        return const CommunityPage();
      default:
        return const HomePage();
    }
  }

  int get _currentIndex => ref.watch(mainTabIndexProvider);

  void _setCurrentIndex(int index) {
    ref.read(mainTabIndexProvider.notifier).state = index;
    _saveCurrentTab();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupNotificationHandler();
    _restoreLastTab();
    _initDeepLinks();
    _initializeAskWingAICubit();

    // Delay non-critical operations to let UI render first
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _initializeWallet();
      if (mounted) _fetchAppConfig();
    });
    // App update check is now handled at root app initialization stage
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _checkForPromotion();
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _checkForReadyToPlayPopup();
    });
  }

  void _initializeAskWingAICubit() {
    try {
      // Initialize AskWingAIService with TokenService
      final tokenService = TokenService();
      _askWingAICubit = AskWingAICubit(
        service: AskWingAIService(
          tokenService: tokenService,
        ),
      );
      debugPrint('AskWingAICubit initialized successfully');
    } catch (e) {
      debugPrint('Error initializing AskWingAICubit: $e');
      // Create with a fallback service to avoid crashes
      try {
        final tokenService = TokenService();
        _askWingAICubit = AskWingAICubit(
          service: AskWingAIService(
            tokenService: tokenService,
          ),
        );
      } catch (fallbackError) {
        debugPrint('Failed to create fallback AskWingAICubit: $fallbackError');
        rethrow;
      }
    }
  }

  Future<void> _checkForReadyToPlayPopup() async {
    final shouldShow = await ReadyToPlayPopup.shouldShow();
    if (shouldShow && mounted) {
      setState(() {
        _showReadyToPlayPopup = true;
      });
    }
  }

  void _closeReadyToPlayPopup() async {
    await ReadyToPlayPopup.markAsShown();
    if (mounted) {
      setState(() {
        _showReadyToPlayPopup = false;
      });
    }
  }

  void _setupNotificationHandler() {
    NotificationService.onNotificationTapped = (data) {
      _handleNotificationNavigation(data);
    };
    if (NotificationService.pendingNotificationData != null) {
      final pending = NotificationService.pendingNotificationData!;
      NotificationService.pendingNotificationData = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationNavigation(pending);
      });
    }
  }

  void _initDeepLinks() async {
    final appLinks = AppLinks();

    // Handle link that launched the app from terminated state
    try {
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Deep link initial error: $e');
    }

    // Handle links while app is running
    _deepLinkSub = appLinks.uriLinkStream.listen(
      (uri) => _handleDeepLink(uri),
      onError: (e) => debugPrint('Deep link stream error: $e'),
    );
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Deep link received: $uri');
    // tcgc://app or https://tcgc.thecitygatechurch.org/app
    final path = uri.path;
    final host = uri.host;

    // Check for message deep link: /app/message/<id> or tcgc://message/<id>
    final messageMatch = RegExp(r'message[/\\]?(\d+)').firstMatch(path);
    if (messageMatch != null) {
      _navigateToMessage(messageMatch.group(1)!);
      return;
    }
    // Also handle tcgc://message/<id> where host is "message"
    if (host == 'message' && uri.pathSegments.isNotEmpty) {
      _navigateToMessage(uri.pathSegments.first);
      return;
    }

    // Check for transcript deep link: /app/transcript/<id> or tcgc://transcript/<id>
    final transcriptMatch = RegExp(r'transcript[/\\]?(\d+)').firstMatch(path);
    if (transcriptMatch != null) {
      _navigateToTranscript(transcriptMatch.group(1)!);
      return;
    }
    if (host == 'transcript' && uri.pathSegments.isNotEmpty) {
      _navigateToTranscript(uri.pathSegments.first);
      return;
    }

    // Check for audio live stream: http(s)://.../app/audio, tcgc://audio, or tcgc://app/audio
    final isAudioLiveStream = host == 'audio' ||
        path.endsWith('/audio') ||
        path.endsWith('/audio/') ||
        uri.pathSegments.contains('audio');

    // Check for video live stream: http(s)://.../app/video, tcgc://video, or tcgc://app/video
    final isVideoLiveStream = host == 'video' ||
        path.endsWith('/video') ||
        path.endsWith('/video/') ||
        uri.pathSegments.contains('video');

    final simplePath = path.replaceAll('/', '');

    if (isAudioLiveStream) {
      ref.read(liveStreamSubTabIndexProvider.notifier).state = 0; // Audio live stream
      ref.read(mainTabIndexProvider.notifier).state = 2; // LiveStream page
    } else if (isVideoLiveStream) {
      ref.read(liveStreamSubTabIndexProvider.notifier).state = 1; // Video live stream
      ref.read(mainTabIndexProvider.notifier).state = 2; // LiveStream page
    } else if (host == 'wallet' || simplePath == 'wallet') {
      ref.read(mainTabIndexProvider.notifier).state = 3;
    } else if (host == 'messages' || simplePath == 'messages' || host == 'sermons' || simplePath == 'sermons') {
      ref.read(mainTabIndexProvider.notifier).state = 1;
    } else if (host == 'teens' || simplePath == 'teens') {
      ref.read(mainTabIndexProvider.notifier).state = 4;
    } else {
      // Default — open home
      ref.read(mainTabIndexProvider.notifier).state = 0;
    }
  }

  Future<void> _navigateToMessage(String messageId) async {
    debugPrint('Navigating to message: $messageId');
    try {
      final sermon = await _dataService.getMessageById(messageId);
      if (sermon != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AudioPlayerPage(sermon: sermon),
          ),
        );
      } else {
        debugPrint('Message not found: $messageId');
        // Fall back to audio tab
        ref.read(mainTabIndexProvider.notifier).state = 1;
      }
    } catch (e) {
      debugPrint('Error navigating to message: $e');
      ref.read(mainTabIndexProvider.notifier).state = 1;
    }
  }

  Future<void> _navigateToTranscript(String transcriptId) async {
    debugPrint('Navigating to transcript: $transcriptId');
    try {
      final transcripts = await _dataService.getTranscripts();
      Transcript? targetTranscript;
      for (var t in transcripts) {
        if (t.id.toString() == transcriptId.toString()) {
          targetTranscript = t;
          break;
        }
      }

      if (targetTranscript != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TranscriptViewPage(transcript: targetTranscript),
          ),
        );
      } else {
        debugPrint('Transcript not found: $transcriptId');
        ref.read(mainTabIndexProvider.notifier).state = 1;
      }
    } catch (e) {
      debugPrint('Error navigating to transcript: $e');
      ref.read(mainTabIndexProvider.notifier).state = 1;
    }
  }

  Future<void> _handleNotificationNavigation(Map<String, dynamic> data) async {
    final type = data['type']?.toString();
    final url = (data['url'] ?? data['deep_link'] ?? data['link'] ?? '').toString();

    if (type == 'livestream' ||
        type == 'live' ||
        type == 'live_stream' ||
        url.contains('/app/audio') ||
        url.contains('/app/video') ||
        url.contains('listen-live')) {
      final isVideo = (data['sub_tab'] == 'video' ||
          data['live_type'] == 'video' ||
          url.contains('/app/video') ||
          url.contains('watch-live'));
      ref.read(liveStreamSubTabIndexProvider.notifier).state = isVideo ? 1 : 0;
      ref.read(mainTabIndexProvider.notifier).state = 2; // Switch to LiveStream tab
      return;
    }

    if (type == 'new_message' || type == 'message') {
      final messageId = data['message_id'];
      if (messageId != null) {
        final sermon = await _dataService.getMessageById(messageId.toString());
        if (sermon != null && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AudioPlayerPage(sermon: sermon),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    NotificationService.onNotificationTapped = null;
    WidgetsBinding.instance.removeObserver(this);
    _askWingAICubit.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveCurrentTab();
    }
  }

  @override
  void didHaveMemoryPressure() {
    // System is low on memory - clear image caches
    ImageCacheService.clearMemoryCache();
    debugPrint('Memory pressure detected - cleared image cache');
  }

  Future<void> _restoreLastTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastIndex = prefs.getInt(_lastTabKey) ?? 0;
      final showWallet = !ref.read(appConfigChangeNotifierProvider).config.walletPageDisabled;
      final maxIndex = showWallet ? 5 : 4;
      final safeIndex = (lastIndex >= 0 && lastIndex <= maxIndex) ? lastIndex : 0;
      if (mounted) {
        ref.read(mainTabIndexProvider.notifier).state = safeIndex;
      }
    } catch (e) {
      debugPrint('Error restoring last tab: $e');
    }
  }

  Future<void> _saveCurrentTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastTabKey, _currentIndex);
    } catch (e) {
      debugPrint('Error saving current tab: $e');
    }
  }

  Future<void> _initializeWallet() async {
    try {
      await ref.read(walletChangeNotifierProvider).initialize();
    } catch (e) {
      debugPrint('Wallet initialization error: $e');
    }
  }

  Future<void> _fetchAppConfig() async {
    try {
      await ref.read(appConfigChangeNotifierProvider).fetchConfig();
    } catch (e) {
      debugPrint('App config fetch error: $e');
    }
  }

  Future<void> _handleWalletTap() async {
    final walletProvider = ref.read(walletChangeNotifierProvider);

    // If user doesn't have wallet, go directly to wallet page (no auth needed for creation)
    if (!walletProvider.hasWallet) {
      _setCurrentIndex(3);
      return;
    }

    // If already authenticated in this session, go directly
    if (_walletAuthenticated) {
      _setCurrentIndex(3);
      return;
    }

    // Show authentication dialog
    final authenticated = await _showWalletAuthDialog();
    if (authenticated) {
      _walletAuthenticated = true;
      _setCurrentIndex(3);
    }
  }

  Future<bool> _showWalletAuthDialog() async {
    final biometricService = BiometricService();
    final biometricEnabled = await biometricService
        .isBiometricTransactionEnabled();
    final biometricAvailable = await biometricService.isBiometricAvailable();

    // Try biometric first if enabled and available
    if (biometricEnabled && biometricAvailable) {
      final authenticated = await biometricService.authenticate(
        reason: 'Authenticate to access wallet',
      );
      if (authenticated) return true;
    }

    // Fall back to PIN dialog
    if (!mounted) return false;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _WalletPinDialog(
            walletProvider: ref.read(walletChangeNotifierProvider),
            biometricService: biometricService,
            biometricAvailable: biometricAvailable,
          ),
        ) ??
        false;
  }



  Future<void> _checkForPromotion() async {
    try {
      final notificationProvider = ref.read(notificationChangeNotifierProvider);
      if (!notificationProvider.preferences.promotionsEnabled) {
        return;
      }

      final promotions = await _dataService.getActivePromotions();
      if (promotions.isNotEmpty && mounted) {
        setState(() {
          _activePromotions = promotions;
          _showPromotion = true;
        });
      }
    } catch (e) {
      debugPrint('Error checking promotion: $e');
    }
  }

  void _closePromotion() {
    setState(() {
      _showPromotion = false;
    });
  }



  @override
  Widget build(BuildContext context) {
    final appConfig = ref.watch(appConfigChangeNotifierProvider);
    final showWallet = !appConfig.config.walletPageDisabled;
    final maxIndex = showWallet ? 5 : 4;
    final safeIndex = _currentIndex > maxIndex ? 0 : _currentIndex;

    if (_showPromotion && _activePromotions.isNotEmpty) {
      return BlocProvider<AskWingAICubit>(
        create: (context) => _askWingAICubit,
        child: Stack(
          children: [
            Scaffold(
              body: _buildPage(safeIndex, showWallet),
              bottomNavigationBar: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (safeIndex != 2) const MiniPlayer(),
                  BottomNavBar(
                    currentIndex: safeIndex,
                    showWallet: showWallet,
                    onTap: (index) {
                      if (showWallet && index == 3) {
                        _handleWalletTap();
                      } else {
                        _setCurrentIndex(index);
                      }
                    },
                  ),
                ],
              ),
            ),
            PromotionPopup(
              promotions: _activePromotions,
              onClose: _closePromotion,
            ),
          ],
        ),
      );
    }

    if (_showReadyToPlayPopup) {
      return BlocProvider<AskWingAICubit>(
        create: (context) => _askWingAICubit,
        child: Stack(
          children: [
            Scaffold(
              body: _buildPage(safeIndex, showWallet),
              bottomNavigationBar: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (safeIndex != 2) const MiniPlayer(),
                  BottomNavBar(
                    currentIndex: safeIndex,
                    showWallet: showWallet,
                    onTap: (index) {
                      if (showWallet && index == 3) {
                        _handleWalletTap();
                      } else {
                        _setCurrentIndex(index);
                      }
                    },
                  ),
                ],
              ),
            ),
            ReadyToPlayPopup(onDismiss: _closeReadyToPlayPopup),
          ],
        ),
      );
    }

    return BlocProvider<AskWingAICubit>(
      create: (context) => _askWingAICubit,
      child: Scaffold(
        body: _buildPage(safeIndex, showWallet),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (safeIndex != 2) const MiniPlayer(),
            BottomNavBar(
              currentIndex: safeIndex,
              showWallet: showWallet,
              onTap: (index) {
                if (showWallet && index == 3) {
                  _handleWalletTap();
                } else {
                  _setCurrentIndex(index);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletPinDialog extends StatefulWidget {
  final WalletProvider walletProvider;
  final BiometricService biometricService;
  final bool biometricAvailable;

  const _WalletPinDialog({
    required this.walletProvider,
    required this.biometricService,
    required this.biometricAvailable,
  });

  @override
  State<_WalletPinDialog> createState() => _WalletPinDialogState();
}

class _WalletPinDialogState extends State<_WalletPinDialog> {
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _obscurePin = true;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    if (_pinController.text.length != 4) {
      setState(() => _error = 'Please enter a 4-digit PIN');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final success = await widget.walletProvider.verifyPin(_pinController.text);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = widget.walletProvider.error ?? 'Invalid PIN');
      }
    }
  }

  Future<void> _tryBiometric() async {
    final authenticated = await widget.biometricService.authenticate(
      reason: 'Authenticate to access wallet',
    );
    if (authenticated && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.lock_outline, color: AppColors.primaryGold),
          const SizedBox(width: 12),
          const Text('Wallet Access'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Enter your transaction PIN to access wallet'),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: _obscurePin,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
            decoration: InputDecoration(
              counterText: '',
              hintText: '****',
              errorText: _error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryGold,
                  width: 2,
                ),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePin ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _obscurePin = !_obscurePin),
              ),
            ),
            onSubmitted: (_) => _verifyPin(),
          ),
          if (widget.biometricAvailable) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _tryBiometric,
              icon: const Icon(Icons.fingerprint, color: AppColors.primaryGold),
              label: Text(
                'Use Biometrics',
                style: TextStyle(color: AppColors.primaryGold),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyPin,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGold,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Verify'),
        ),
      ],
    );
  }
}
