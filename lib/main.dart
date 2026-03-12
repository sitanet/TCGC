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
import 'data/services/data_service.dart' show DataService, AppUpdateInfo;
import 'data/services/notification_service.dart';
import 'presentation/pages/audio/audio_player_page.dart';
import 'domain/entities/promotion.dart';
import 'core/services/connectivity_service.dart';
import 'core/widgets/network_aware_widget.dart';
import 'data/services/biometric_service.dart';

const String appVersion = '1.0.0';

// Riverpod providers wrapping ChangeNotifier classes
final themeChangeNotifierProvider = ChangeNotifierProvider<ThemeProvider>((ref) => ThemeProvider());
final authChangeNotifierProvider = ChangeNotifierProvider<AuthProvider>((ref) => AuthProvider());
final notificationChangeNotifierProvider = ChangeNotifierProvider<NotificationProvider>((ref) => NotificationProvider());
final walletChangeNotifierProvider = ChangeNotifierProvider<WalletProvider>((ref) => WalletProvider());
final audioPlayerChangeNotifierProvider = ChangeNotifierProvider<AudioPlayerProvider>((ref) => AudioPlayerProvider());
final biometricChangeNotifierProvider = ChangeNotifierProvider<BiometricProvider>((ref) => BiometricProvider());
final appConfigChangeNotifierProvider = ChangeNotifierProvider<AppConfigProvider>((ref) => AppConfigProvider());

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
    
    // Initialize Firebase FIRST (required for other services) - this is fast
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await Firebase.initializeApp();
      } catch (e) {
        debugPrint('Firebase initialization error: $e');
      }
    }
    
    // Initialize AudioService BEFORE runApp (required for background audio)
    try {
      await initAudioService();
    } catch (e) {
      debugPrint('Audio service initialization error: $e');
    }
    
    // Now start the app
    runApp(
      const ProviderScope(
        child: MyApp(),
      ),
    );
    
    // Initialize non-critical services in background
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        await ConnectivityService().initialize();
      } catch (e) {
        debugPrint('Connectivity service initialization error: $e');
      }
    });
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
    // Show UI immediately, don't wait for initialization
    if (mounted) {
      setState(() {
        _initialized = true;
      });
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
  bool _walletAuthenticated = false;
  List<Promotion> _activePromotions = [];
  final DataService _dataService = DataService();
  AppUpdateInfo? _updateInfo;
  
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
    
    // Delay non-critical operations to let UI render first
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _initializeWallet();
      if (mounted) _fetchAppConfig();
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _checkForAppUpdate();
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _checkForPromotion();
    });
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
    final biometricEnabled = await biometricService.isBiometricTransactionEnabled();
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
    ) ?? false;
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
                borderSide: const BorderSide(color: AppColors.primaryGold, width: 2),
              ),
              suffixIcon: IconButton(
                icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility),
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
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyPin,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGold,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Verify'),
        ),
      ],
    );
  }
}
