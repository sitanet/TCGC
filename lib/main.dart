import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/theme_provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/notification_provider.dart';
import 'core/providers/audio_player_provider.dart' show AudioPlayerProvider, initAudioService;
import 'core/providers/wallet_provider.dart';
import 'presentation/pages/home/home_page.dart';
import 'presentation/pages/audio/audio_page.dart';
import 'presentation/pages/livestream/livestream_page.dart';
import 'presentation/pages/wallet/wallet_page.dart';

import 'presentation/pages/teens/teens_page.dart';
import 'presentation/pages/get_started/get_started_page.dart';
import 'presentation/pages/auth/sign_in_page.dart';
import 'presentation/pages/auth/sign_up_page.dart';
import 'presentation/widgets/bottom_nav_bar.dart';
import 'presentation/widgets/mini_player.dart';
import 'presentation/widgets/promotion_popup.dart';
import 'data/services/data_service.dart' show DataService, AppUpdateInfo;
import 'domain/entities/promotion.dart';

const String appVersion = '1.0.0';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initAudioService();
  
  // Set default status bar style (dark icons for light theme)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => AudioPlayerProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showGetStarted = true;
  bool _showSignUp = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Initialize auth first (this is quick - just loads tokens from storage)
      await authProvider.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('Auth initialization timed out');
        },
      );
      
      // Initialize notifications in background (don't block the app)
      _initializeNotifications();
      
      if (mounted) {
        setState(() {
          _initialized = true;
          if (authProvider.isAuthenticated) {
            _showGetStarted = false;
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
      final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
      await notificationProvider.initialize();
    } catch (e) {
      debugPrint('Notification initialization error: $e');
    }
  }

  void _onAuthenticated() {
    setState(() {
      _showGetStarted = false;
      _showSignUp = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

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
      homeWidget = const MainScreen();
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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _showPromotion = false;
  bool _showUpdateDialog = false;
  List<Promotion> _activePromotions = [];
  final DataService _dataService = DataService();
  AppUpdateInfo? _updateInfo;

  final List<Widget> _pages = const [
    HomePage(),
    AudioPage(),
    LiveStreamPage(),
    WalletPage(),
    TeensPage(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeWallet();
    _checkForAppUpdate();
    _checkForPromotion();
  }

  Future<void> _initializeWallet() async {
    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      await walletProvider.initialize();
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
    
    // Show update dialog if available
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
    
    // Show promotion popup if active
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
              setState(() {
                _currentIndex = index;
              });
            },
          ),
        ],
      ),
    );
  }
}
