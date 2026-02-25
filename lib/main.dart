import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/theme_provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/notification_provider.dart';
import 'core/providers/audio_player_provider.dart';
import 'core/providers/wallet_provider.dart';
import 'core/providers/biometric_provider.dart';
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
import 'package:cached_network_image/cached_network_image.dart';
import 'data/services/data_service.dart' show DataService, AppUpdateInfo;
import 'data/services/notification_service.dart';
import 'data/services/audio_cache_service.dart';
import 'presentation/pages/audio/audio_player_page.dart';
import 'domain/entities/promotion.dart';
import 'domain/entities/sermon.dart';
import 'domain/entities/event.dart';
import 'core/services/connectivity_service.dart';
import 'core/widgets/network_aware_widget.dart';

const String appVersion = '1.0.0';

// Riverpod providers wrapping ChangeNotifier classes
final themeChangeNotifierProvider = ChangeNotifierProvider<ThemeProvider>((ref) => ThemeProvider());
final authChangeNotifierProvider = ChangeNotifierProvider<AuthProvider>((ref) => AuthProvider());
final notificationChangeNotifierProvider = ChangeNotifierProvider<NotificationProvider>((ref) => NotificationProvider());
final walletChangeNotifierProvider = ChangeNotifierProvider<WalletProvider>((ref) => WalletProvider());
final audioPlayerChangeNotifierProvider = ChangeNotifierProvider<AudioPlayerProvider>((ref) => AudioPlayerProvider());
final biometricChangeNotifierProvider = ChangeNotifierProvider<BiometricProvider>((ref) => BiometricProvider());

// Navigation provider to allow tab pages to navigate to home
final mainTabIndexProvider = StateProvider<int>((ref) => 0);

void main() async {
  // Catch Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Flutter error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };
  
  // Run the app with error zone for async errors
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize Firebase only on supported platforms (Android/iOS)
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await Firebase.initializeApp();
      } catch (e) {
        debugPrint('Firebase initialization error: $e');
      }
    }
    
    // Initialize audio service for background playback
    await initAudioService();
    
    // Initialize connectivity service
    await ConnectivityService().initialize();
    
    runApp(
      const ProviderScope(
        child: MyApp(),
      ),
    );
  }, (error, stackTrace) {
    debugPrint('Uncaught async error: $error');
    debugPrint('Stack trace: $stackTrace');
  });
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
      
      await Future.wait([
        authProvider.initialize().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('Auth initialization timed out');
          },
        ),
        _interestsService.initialize().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('Interests initialization timed out');
          },
        ),
      ]);
      
      _initializeNotifications();
      
      if (mounted) {
        setState(() {
          _initialized = true;
          if (authProvider.isAuthenticated) {
            _showGetStarted = false;
            if (!_interestsService.interestsCompleted) {
              _showInterests = true;
            }
            // Start pre-buffering for already logged in users
            _startBackgroundPreBuffering();
          }
        });
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    }
  }
  
  Future<void> _initializeNotifications() async {
    try {
      await ref.read(notificationChangeNotifierProvider).initialize();
    } catch (e) {
      debugPrint('Notification initialization error: $e');
    }
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
    try {
      final dataService = DataService();
      final audioCacheService = AudioCacheService();
      await audioCacheService.initialize();
      
      // Fetch all messages - this will cache metadata in local database
      final sermons = await dataService.getMessages();
      if (sermons.isNotEmpty) {
        debugPrint('Caching ${sermons.length} sermons metadata, images, and audio');
        
        // Cache sermon metadata is already done by dataService
        // Pre-cache all sermon images in background
        _preCacheImages(sermons);
        
        // Pre-buffer audio for all sermons
        audioCacheService.preBufferCategory(sermons, count: sermons.length);
      }
      
      // Also cache events
      final events = await dataService.getEvents();
      if (events.isNotEmpty) {
        debugPrint('Caching ${events.length} events');
        _preCacheEventImages(events);
      }
      
      // Cache categories
      final categories = await dataService.getMessageCategories();
      if (categories.isNotEmpty) {
        debugPrint('Caching ${categories.length} categories');
        audioCacheService.cacheMetadata(categories: categories, sermons: sermons);
      }
    } catch (e) {
      debugPrint('Background caching error: $e');
    }
  }
  
  void _preCacheImages(List<Sermon> sermons) {
    for (final sermon in sermons) {
      if (sermon.imageUrl != null && sermon.imageUrl!.isNotEmpty) {
        try {
          CachedNetworkImageProvider(sermon.imageUrl!).resolve(ImageConfiguration.empty);
        } catch (_) {}
      }
    }
  }
  
  void _preCacheEventImages(List<Event> events) {
    for (final event in events) {
      if (event.imageUrl != null && event.imageUrl!.isNotEmpty) {
        try {
          CachedNetworkImageProvider(event.imageUrl!).resolve(ImageConfiguration.empty);
        } catch (_) {}
      }
    }
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
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    Widget homeWidget;
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

class _MainScreenState extends ConsumerState<MainScreen> with WidgetsBindingObserver {
  bool _showPromotion = false;
  bool _showUpdateDialog = false;
  List<Promotion> _activePromotions = [];
  final DataService _dataService = DataService();
  AppUpdateInfo? _updateInfo;
  
  static const String _lastTabKey = 'last_tab_index';

  final List<Widget> _pages = const [
    HomePage(),
    AudioPage(),
    LiveStreamPage(),
    WalletPage(),
    TeensPage(),
  ];

  int get _currentIndex => ref.watch(mainTabIndexProvider);

  void _setCurrentIndex(int index) {
    ref.read(mainTabIndexProvider.notifier).state = index;
    _saveCurrentTab();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreLastTab();
    _initializeWallet();
    _checkForAppUpdate();
    _checkForPromotion();
    _setupNotificationHandler();
  }
  
  void _setupNotificationHandler() {
    NotificationService.onNotificationTapped = (data) {
      _handleNotificationNavigation(data);
    };
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
    NotificationService.onNotificationTapped = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive) {
      _saveCurrentTab();
    }
  }
  
  Future<void> _restoreLastTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastIndex = prefs.getInt(_lastTabKey) ?? 0;
      if (lastIndex >= 0 && lastIndex < _pages.length && mounted) {
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
      
      final updateInfo = await _dataService.checkForAppUpdate(appVersion, platform);
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
  
  void _closeUpdateDialog() {
    if (_updateInfo?.forceUpdate == true) {
      return;
    }
    setState(() {
      _showUpdateDialog = false;
    });
  }
  
  Future<void> _openUpdateUrl() async {
    final url = _updateInfo?.updateUrl;
    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_showUpdateDialog && _updateInfo != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.system_update,
                  size: 80,
                  color: AppColors.primaryGold,
                ),
                const SizedBox(height: 24),
                Text(
                  'Update Available',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Version ${_updateInfo!.latestVersion}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _updateInfo!.updateMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _openUpdateUrl,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGold,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Update Now',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (!_updateInfo!.forceUpdate) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _closeUpdateDialog,
                    child: Text(
                      'Later',
                      style: TextStyle(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    
    if (_showPromotion && _activePromotions.isNotEmpty) {
      return PromotionPopup(
        promotions: _activePromotions,
        onClose: _closePromotion,
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          BottomNavBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              _setCurrentIndex(index);
            },
          ),
        ],
      ),
    );
  }
}
