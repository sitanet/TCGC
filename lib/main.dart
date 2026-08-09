import 'dart:async'
    show Future, StreamSubscription, TimeoutException, runZonedGuarded;
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'presentation/pages/get_started/get_started_page.dart';
import 'presentation/pages/auth/sign_in_page.dart';
import 'presentation/pages/auth/sign_up_page.dart';
import 'presentation/pages/interests/interests_page.dart';
import 'data/services/interests_service.dart';
import 'presentation/widgets/bottom_nav_bar.dart';
import 'presentation/widgets/mini_player.dart';
import 'presentation/widgets/promotion_popup.dart';
import 'presentation/widgets/ready_to_play_popup.dart';
import 'data/services/data_service.dart' show DataService, AppUpdateInfo;
import 'data/services/notification_service.dart';
import 'presentation/pages/audio/audio_player_page.dart';
import 'domain/entities/promotion.dart';
import 'core/widgets/network_aware_widget.dart';
import 'data/services/biometric_service.dart';
import 'core/providers/community_provider.dart';
import 'core/services/image_cache_service.dart';
import 'presentation/bloc/ask_wing_ai/ask_wing_ai_cubit.dart';
import 'data/services/ask_wing_ai_service.dart';
import 'core/services/token_service.dart';

final communityChangeNotifierProvider =
    ChangeNotifierProvider<CommunityProvider>((ref) => CommunityProvider());

const String appVersion = '1.0.0';

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

      // Initialize image cache with conservative memory limits first
      ImageCacheService.initialize();

      // Start the app IMMEDIATELY - don't block on any initialization
      // This prevents ANR on low-end devices
      runApp(const ProviderScope(child: MyApp()));

      // Initialize Firebase in background (non-blocking)
      Future.microtask(() async {
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          try {
            await Firebase.initializeApp().timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                debugPrint('Firebase initialization timed out');
                throw TimeoutException('Firebase init timeout');
              },
            );
            debugPrint('Firebase initialized');
          } catch (e) {
            debugPrint('Firebase initialization error: $e');
          }
        }
      });

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
  bool _showInterests = false;
  bool _initialized = false;
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
          url = 'https://apps.apple.com/app/tcgc'; // Replace with actual App store URL when available
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

  Widget _buildUpdateDialog(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0E0E0D)
          : const Color(0xFFFAF9F6),
      body: SafeArea(
        child: Column(
          children: [
            // Close button row — only shown when update is NOT forced
            if (!_updateInfo!.forceUpdate)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, right: 16),
                  child: IconButton(
                    onPressed: _closeUpdateDialog,
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04),
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(8),
                    ),
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white70 : Colors.black54,
                      size: 22,
                    ),
                    tooltip: 'Close',
                  ),
                ),
              )
            else
              const SizedBox(height: 24),
            // Scrollable content area
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    SizedBox(height: _updateInfo!.forceUpdate ? 40 : 16),
                    // Animated premium outer glowing ring artwork
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: AppColors.primaryGold.withValues(alpha: 0.03),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            color: AppColors.primaryGold.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFFD700),
                                Color(0xFFB8860B),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryGold.withValues(alpha: 0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.rocket_launch_rounded,
                            size: 42,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Title
                    Text(
                      _updateInfo!.forceUpdate
                          ? 'Update Required'
                          : 'New Update Available',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Version capsule
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: AppColors.primaryGold.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Version ${_updateInfo!.latestVersion}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryGold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // What's new card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161615) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.25 : 0.04,
                            ),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGold.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 18,
                                  color: AppColors.primaryGold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "What's New",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Update message
                          Text(
                            _updateInfo!.updateMessage,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: isDark
                                  ? const Color(0xFFABABAB)
                                  : const Color(0xFF555555),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Info note for force update
                    if (_updateInfo!.forceUpdate)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'This update is required to continue using the application.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.orange[200] : Colors.orange[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 32),
                    // Update Now CTA
                    Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFD700),
                            Color(0xFFB8860B),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryGold.withValues(alpha: 0.35),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _openUpdateUrl,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.download_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Update Now',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!_updateInfo!.forceUpdate) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: TextButton(
                          onPressed: _closeUpdateDialog,
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(
                            'Remind Me Later',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    // Show UI immediately without connectivity check
    if (mounted) {
      setState(() {
        _initialized = true;
      });
      _checkForAppUpdate();
    }

    // Initialize auth in background
    Future.microtask(() async {
      try {
        final authProvider = ref.read(authChangeNotifierProvider);

        await authProvider.initialize().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('Auth initialization timed out');
          },
        );

        await _interestsService.initialize().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint('Interests initialization timed out');
          },
        );

        if (mounted && authProvider.isAuthenticated) {
          setState(() {
            _showGetStarted = false;
            if (!_interestsService.interestsCompleted) {
              _showInterests = true;
            }
          });
          _startBackgroundPreBuffering();
        }

        _initializeNotifications();
      } catch (e) {
        debugPrint('Initialization error: $e');
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
      _showGetStarted = false;
      _showSignUp = false;
      if (!_interestsService.interestsCompleted) {
        _showInterests = true;
      }
    });
    // Start pre-buffering all messages in background after login
    _startBackgroundPreBuffering();
  }

  Future<void> _startBackgroundPreBuffering() async {
    // Disabled heavy background caching to prevent ANR issues
    // Data will be fetched on demand from screens
    debugPrint('Background pre-buffering disabled to prevent ANR');
  }

  void _onInterestsComplete() {
    setState(() {
      _showInterests = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ref.watch(themeChangeNotifierProvider);
    final authProvider = ref.watch(authChangeNotifierProvider);

    if (!_initialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeProvider.themeMode,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (_showUpdateDialog && _updateInfo != null) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return MaterialApp(
        title: 'TCGC',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeProvider.themeMode,
        home: _buildUpdateDialog(context, isDark),
      );
    }

    Widget homeWidget;

    // Always show main app interface (removed offline page check)
    if (authProvider.isAuthenticated) {
      if (_showInterests) {
        homeWidget = InterestsPage(onComplete: _onInterestsComplete);
      } else {
        homeWidget = const NetworkAwareWidget(child: MainScreen());
      }
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
  bool _showUpdateDialog = false;
  bool _showReadyToPlayPopup = false;
  bool _walletAuthenticated = false;
  List<Promotion> _activePromotions = [];
  final DataService _dataService = DataService();
  AppUpdateInfo? _updateInfo;
  StreamSubscription? _deepLinkSub;
  late AskWingAICubit _askWingAICubit;

  static const String _lastTabKey = 'last_tab_index';

  // Pages are built lazily to prevent ANR from heavy pages like LiveStreamPage
  Widget _buildPage(int index) {
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
    // tcgc://app or https://thecitygatechurch.org/app
    final path = uri.path.replaceAll('/', '');
    final host = uri.host;

    // Navigate based on path/host
    if (host == 'wallet' || path == 'wallet') {
      ref.read(mainTabIndexProvider.notifier).state = 3;
    } else if (host == 'audio' || path == 'audio') {
      ref.read(mainTabIndexProvider.notifier).state = 1;
    } else if (host == 'teens' || path == 'teens') {
      ref.read(mainTabIndexProvider.notifier).state = 4;
    } else {
      // Default — open home
      ref.read(mainTabIndexProvider.notifier).state = 0;
    }
  }

  Future<void> _handleNotificationNavigation(Map<String, dynamic> data) async {
    final type = data['type'];

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
      // Clear memory cache when app goes to background to prevent OOM
      ImageCacheService.clearMemoryCache();
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
      if (lastIndex >= 0 && lastIndex < 5 && mounted) {
        ref.read(mainTabIndexProvider.notifier).state = lastIndex;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_showPromotion && _activePromotions.isNotEmpty) {
      return PromotionPopup(
        promotions: _activePromotions,
        onClose: _closePromotion,
      );
    }

    if (_showReadyToPlayPopup) {
      return BlocProvider<AskWingAICubit>(
        create: (context) => _askWingAICubit,
        child: Stack(
          children: [
            Scaffold(
              body: _buildPage(_currentIndex),
              bottomNavigationBar: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MiniPlayer(),
                  BottomNavBar(
                    currentIndex: _currentIndex,
                    onTap: (index) {
                      if (index == 3) {
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
        body: _buildPage(_currentIndex),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            BottomNavBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                if (index == 3) {
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
