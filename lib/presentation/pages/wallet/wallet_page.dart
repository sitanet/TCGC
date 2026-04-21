import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';
import 'give_page.dart';

import 'set_transaction_pin_page.dart';

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> with WidgetsBindingObserver {
  bool _needsPinSetup = false;
  bool _acceptedDataPolicy = false;
  bool _isAuthenticated = false;
  bool _hasInitialized = false;
  bool _authenticationInProgress = false;

  void _handleBackNavigation() {
    // Check if we can pop (i.e., there's a previous route)
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      // If can't pop, go to home tab
      ref.read(mainTabIndexProvider.notifier).state = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Refresh app config to get latest wallet page status
      ref.read(appConfigChangeNotifierProvider).fetchConfig();
      _startAuthentication();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-authenticate when app comes back to foreground only if not already authenticated
    if (state == AppLifecycleState.resumed && _hasInitialized && !_isAuthenticated) {
      _startAuthentication();
    }
    // Always refresh upgrade status on resume so tier updates are picked up
    if (state == AppLifecycleState.resumed && _isAuthenticated) {
      ref.read(walletChangeNotifierProvider).fetchUpgradeStatus();
    }
  }

  void _startAuthentication() {
    // Only reset if not currently authenticated
    if (!_isAuthenticated) {
      setState(() {
        _needsPinSetup = false;
      });
    }
    _hasInitialized = true;
    if (!_isAuthenticated) {
      _authenticateUser();
    }
  }

  // Track previous tab to detect when switching TO wallet tab
  int? _previousTabIndex;

  Future<void> _authenticateUser() async {
    // Prevent multiple simultaneous authentication attempts
    if (_authenticationInProgress) return;
    _authenticationInProgress = true;
    
    final walletProvider = ref.read(walletChangeNotifierProvider);
    
    // Always fetch wallet from backend to ensure we have latest state
    await walletProvider.fetchWallet();
    
    // If no wallet yet, no authentication needed
    if (!walletProvider.hasWallet) {
      _authenticationInProgress = false;
      setState(() => _isAuthenticated = true);
      return;
    }
    
    // Check if PIN is set
    final hasPin = await walletProvider.checkHasPin();
    if (!hasPin) {
      _authenticationInProgress = false;
      setState(() {
        _isAuthenticated = true;
        _needsPinSetup = true;
      });
      return;
    }

    // Try biometric first
    final biometricProvider = ref.read(biometricChangeNotifierProvider);
    await biometricProvider.initialize();
    
    if (biometricProvider.biometricTransactionEnabled && biometricProvider.isAvailable) {
      final authenticated = await biometricProvider.authenticateForTransaction();
      if (authenticated && mounted) {
        _authenticationInProgress = false;
        setState(() => _isAuthenticated = true);
        _checkWalletStatus();
        return;
      }
    }

    // Fall back to PIN dialog
    if (mounted) {
      _showPinDialog();
    } else {
      _authenticationInProgress = false;
    }
  }

  void _showPinDialog() {
    final pinController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isVerifying = false;

    showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop && result != true) {
            // Only go to home if user cancelled (result is null or false), not if PIN was verified (result is true)
            _authenticationInProgress = false;
            ref.read(mainTabIndexProvider.notifier).state = 0;
          }
        },
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: isDark ? AppColors.cardDark : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.lock_outline, color: AppColors.primaryGold, size: 24),
                const SizedBox(width: 8),
                const Text('Enter Transaction PIN'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter your PIN to access wallet',
                  style: TextStyle(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: '••••',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      letterSpacing: 8,
                    ),
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryGold, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                  onSubmitted: (_) async {
                    if (pinController.text.isEmpty || isVerifying) return;
                    setDialogState(() => isVerifying = true);
                    
                    final walletProvider = ref.read(walletChangeNotifierProvider);
                    final isValid = await walletProvider.verifyPin(pinController.text);

                    if (isValid && mounted) {
                      _authenticationInProgress = false;
                      Navigator.pop(dialogContext, true);
                      setState(() => _isAuthenticated = true);
                      _checkWalletStatus();
                    } else if (mounted) {
                      setDialogState(() => isVerifying = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(walletProvider.error ?? 'Invalid PIN'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isVerifying ? null : () {
                  _authenticationInProgress = false;
                  Navigator.pop(dialogContext);
                  ref.read(mainTabIndexProvider.notifier).state = 0;
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                onPressed: isVerifying ? null : () async {
                  if (pinController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter your PIN')),
                    );
                    return;
                  }
                  
                  if (pinController.text.length < 4) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PIN must be at least 4 digits')),
                    );
                    return;
                  }
                  
                  setDialogState(() => isVerifying = true);

                  final walletProvider = ref.read(walletChangeNotifierProvider);
                  final isValid = await walletProvider.verifyPin(pinController.text);

                  if (isValid && mounted) {
                    _authenticationInProgress = false;
                    Navigator.pop(dialogContext, true);
                    setState(() => _isAuthenticated = true);
                    _checkWalletStatus();
                  } else if (mounted) {
                    setDialogState(() => isVerifying = false);
                    pinController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(walletProvider.error ?? 'Invalid PIN'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: isVerifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Confirm', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkWalletStatus() async {
    final walletProvider = ref.read(walletChangeNotifierProvider);
    
    // If already initialized, just check PIN status without waiting
    if (walletProvider.isInitialized && walletProvider.hasWallet) {
      final hasPin = await walletProvider.checkHasPin();
      if (!hasPin && mounted) {
        setState(() => _needsPinSetup = true);
      }
      // Refresh in background
      walletProvider.fetchWallet();
      return;
    }
    
    // First time - fetch wallet
    await walletProvider.fetchWallet();
    
    // If wallet exists, check if PIN is set
    if (walletProvider.hasWallet) {
      final hasPin = await walletProvider.checkHasPin();
      if (!hasPin && mounted) {
        setState(() => _needsPinSetup = true);
      }
    }
  }

  void _navigateToCreateWallet() {
    // Navigate to PIN setup first, then NIN verification
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SetTransactionPinPage(),
      ),
    );
  }

  void _showDataProtectionPolicy(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.privacy_tip_outlined, color: AppColors.primaryGold, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Data Protection Policy',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPolicySection(
                        'Introduction',
                        'The CityGate Apostolic Kingdom Ministry ("TCGC", "the Church", "we", "us", or "our") is committed to protecting your personal data and ensuring your privacy as a valued member of our congregation. This policy is in accordance with the Nigeria Data Protection Regulation (NDPR) 2019 and other applicable data protection laws.',
                        isDark,
                      ),
                      _buildPolicySection(
                        'Our Commitment to You',
                        'As a faith-based organization, we hold your trust sacred. We collect and process your personal data with the utmost care, transparency, and in alignment with biblical principles of stewardship and integrity.',
                        isDark,
                      ),
                      _buildPolicySection(
                        'Data We Collect',
                        '• Full Name and Contact Information\n• National Identification Number (NIN)\n• Bank Verification Number (BVN)\n• Date of Birth and Gender\n• Phone Number and Email Address\n• Giving and Transaction History\n• Church Membership Information',
                        isDark,
                      ),
                      _buildPolicySection(
                        'Purpose of Data Collection',
                        'Your personal data is collected solely for:\n• Creating and managing your TCGC Wallet\n• Processing your tithes, offerings, seeds, and donations\n• Generating giving receipts and annual statements\n• Communicating church updates and giving confirmations\n• Compliance with Nigerian financial regulations\n• Enhancing your worship and giving experience',
                        isDark,
                      ),
                      _buildPolicySection(
                        'Financial Services Partner',
                        'Your wallet services are powered by 9 Payment Service Bank (9PSB), a licensed financial institution regulated by the Central Bank of Nigeria. Our technology partner, Sitanet Global Orbit, facilitates the secure integration of these services. Your data is shared with these partners only as necessary to provide wallet and payment services.',
                        isDark,
                      ),
                      _buildPolicySection(
                        'Data Security & Protection',
                        'We implement bank-grade security measures including:\n• End-to-end encryption for all transactions\n• Secure PIN and biometric authentication\n• Regular security audits and monitoring\n• Restricted access to authorized personnel only\n• Secure data storage on protected servers',
                        isDark,
                      ),
                      _buildPolicySection(
                        'Your Rights as a Member',
                        'You have the right to:\n• Access your personal data at any time\n• Request correction of any inaccurate information\n• Request deletion of your data (subject to legal requirements)\n• Withdraw your consent at any time\n• Receive a copy of your giving history\n• Lodge a complaint with NITDA if necessary',
                        isDark,
                      ),
                      _buildPolicySection(
                        'Data Retention',
                        'Your personal data and giving records will be retained for the duration of your membership and for a minimum of 6 years thereafter, in compliance with Nigerian tax and financial regulations. Transaction records may be retained longer for audit purposes.',
                        isDark,
                      ),
                      _buildPolicySection(
                        'Third-Party Disclosure',
                        'We do not sell, trade, or share your personal information with third parties for marketing purposes. Data is only shared with our financial service partners (9PSB) for transaction processing and with regulatory authorities when required by law.',
                        isDark,
                      ),
                      _buildPolicySection(
                        'Contact Us',
                        'For questions, concerns, or requests regarding your personal data, please contact the Church Admin through:\n• The app\'s Support section\n• Email: support@thecitygatechurch.org\n• Visit the Church office during working hours',
                        isDark,
                      ),
                      _buildPolicySection(
                        'Policy Updates',
                        'This policy may be updated from time to time. We will notify you of any significant changes through the app. Continued use of the TCGC Wallet after changes constitutes acceptance of the updated policy.',
                        isDark,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Last Updated: February 2026',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPolicySection(String title, String content, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryGold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = ref.watch(walletChangeNotifierProvider);
    
    // Watch tab index to detect when user navigates to wallet tab
    final currentTabIndex = ref.watch(mainTabIndexProvider);
    
    // Check if tab changed and trigger re-authentication if needed (only if not already authenticated)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentTabIndex == 3 && _previousTabIndex != null && _previousTabIndex != 3 && _hasInitialized && !_isAuthenticated) {
        _startAuthentication();
      }
      _previousTabIndex = currentTabIndex;
    });
    
    // Show loading while authenticating or loading wallet
    if (!_isAuthenticated || (walletProvider.isLoading && !walletProvider.isInitialized)) {
      return Scaffold(
        appBar: CustomAppBar(
          title: '',
          showBackButton: true,
          lightBackground: true,
          onBackPressed: _handleBackNavigation,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryGold,
          ),
        ),
      );
    }
    
    // If wallet exists but PIN not set, go to PIN setup
    if (walletProvider.hasWallet && _needsPinSetup) {
      return const SetTransactionPinPage();
    }
    
    // If user has wallet with PIN, go to GivePage (wallet details)
    if (walletProvider.hasWallet) {
      return const GivePage();
    }
    
    // If user doesn't have wallet, show welcome page
    return _buildWalletWelcomePage(context);
  }

  Widget _buildDisabledPage(BuildContext context, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = Responsive.horizontalPadding(context);
    
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Wallet',
        showBackButton: true,
        lightBackground: true,
        onBackPressed: _handleBackNavigation,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(horizontalPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.construction_rounded,
                  size: 50,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Under Maintenance',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletWelcomePage(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = Responsive.horizontalPadding(context);
    final spacing = Responsive.verticalSpacing(context);
    final maxWidth = Responsive.maxContentWidth(context);
    final titleFontSize = Responsive.titleFontSize(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final borderRadius = Responsive.borderRadius(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Wallet',
        showBackButton: true,
        lightBackground: true,
        onBackPressed: _handleBackNavigation,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.all(horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: spacing * 3),
                  
                  // Wallet Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryGold.withOpacity(0.2),
                          AppColors.primaryGold.withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 60,
                      color: AppColors.primaryGold,
                    ),
                  ),
                  SizedBox(height: spacing * 2),

                  // Title
                  Text(
                    'TCGC Wallet',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGold,
                      fontSize: titleFontSize,
                    ),
                  ),
                  SizedBox(height: spacing),

                  // Description
                  Text(
                    'Create your digital wallet to give offerings, tithes, and manage all your giving conveniently.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      height: 1.5,
                      fontSize: bodyFontSize,
                    ),
                  ),
                  SizedBox(height: spacing * 3),

                  // Features List
                  _buildFeatureItem(
                    context,
                    isDark,
                    Icons.security_outlined,
                    'Secure Transactions',
                    'Powered by 9PSB with bank-level security',
                  ),
                  SizedBox(height: spacing),
                  _buildFeatureItem(
                    context,
                    isDark,
                    Icons.volunteer_activism_outlined,
                    'Easy Giving',
                    'Give tithes, offerings, and donations seamlessly',
                  ),
                  SizedBox(height: spacing),
                  _buildFeatureItem(
                    context,
                    isDark,
                    Icons.history_outlined,
                    'Transaction History',
                    'Track all your giving and transactions',
                  ),
                  SizedBox(height: spacing * 2),

                  // Disclaimer Notice
                  Container(
                    padding: EdgeInsets.all(horizontalPadding * 0.75),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(borderRadius),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.account_balance_outlined,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Disclaimer: The CityGate Church is not a bank or financial institution. All wallet transactions are handled by 9 Payment Service Bank (9PSB) through our Technology Platform partner Sitanet Global Orbit.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[800],
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing),

                  // Verification Fee Notice
                  Container(
                    padding: EdgeInsets.all(horizontalPadding * 0.75),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(borderRadius),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange[700],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'A one-time fee of ₦150 will be deducted from your first deposit for NIN/BVN verification. This is a one-time charge only.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange[800],
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing * 2),

                  // Data Protection Policy Checkbox
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _acceptedDataPolicy,
                          onChanged: (value) {
                            setState(() => _acceptedDataPolicy = value ?? false);
                          },
                          activeColor: AppColors.primaryGold,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: 'I agree to the ',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                            children: [
                              TextSpan(
                                text: 'Data Protection Policy',
                                style: TextStyle(
                                  color: AppColors.primaryGold,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _showDataProtectionPolicy(context, isDark),
                              ),
                              const TextSpan(
                                text: ' and consent to the processing of my personal data for wallet creation and identity verification.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing * 3),

                  // Create Wallet Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _acceptedDataPolicy ? _navigateToCreateWallet : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGold,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[500],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Create Wallet',
                        style: TextStyle(
                          fontSize: bodyFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: spacing * 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    bool isDark,
    IconData icon,
    String title,
    String description,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryGold,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
