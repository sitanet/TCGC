import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/password_input_field.dart';
import '../../providers/feature_toggle_provider.dart';
import 'give_page.dart';
import 'set_transaction_pin_page.dart';

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage>
    with WidgetsBindingObserver {
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
      // NOTE: _startAuthentication() is now called from build() after toggle check
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
    if (state == AppLifecycleState.resumed &&
        _hasInitialized &&
        !_isAuthenticated) {
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

    if (biometricProvider.biometricTransactionEnabled &&
        biometricProvider.isAvailable) {
      final authenticated = await biometricProvider
          .authenticateForTransaction();
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

    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop && result != true) {
            _authenticationInProgress = false;
            ref.read(mainTabIndexProvider.notifier).state = 0;
          }
        },
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            final sheetBg = isDark ? AppColors.cardDark : Colors.white;
            final labelColor = isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight;
            final valueColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── drag handle ──────────────────────────────────────
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // ── close button ─────────────────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: Icon(
                          Icons.close,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        onPressed: isVerifying
                            ? null
                            : () {
                                _authenticationInProgress = false;
                                Navigator.pop(sheetContext);
                                ref.read(mainTabIndexProvider.notifier).state =
                                    0;
                              },
                      ),
                    ),

                    // ── lock icon + title ─────────────────────────────────
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        color: AppColors.primaryGold,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Enter Transaction PIN',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: valueColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter your PIN to access wallet',
                      style: TextStyle(fontSize: 14, color: labelColor),
                    ),
                    const SizedBox(height: 28),

                    // ── PIN field ─────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: PasswordInputField(
                        controller: pinController,
                        labelText: 'PIN',
                        hintText: '••••',
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        textAlign: TextAlign.center,
                        autofocus: true,
                        enabled: !isVerifying,
                        style: const TextStyle(
                          fontSize: 24,
                          letterSpacing: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            letterSpacing: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primaryGold,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                        ),
                        onSubmitted: (_) async {
                          if (pinController.text.isEmpty || isVerifying) return;
                          if (pinController.text.length < 4) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('PIN must be at least 4 digits'),
                              ),
                            );
                            return;
                          }
                          setSheetState(() => isVerifying = true);
                          final walletProvider = ref.read(
                            walletChangeNotifierProvider,
                          );
                          final isValid = await walletProvider.verifyPin(
                            pinController.text,
                          );
                          if (isValid && mounted) {
                            _authenticationInProgress = false;
                            Navigator.pop(sheetContext, true);
                            setState(() => _isAuthenticated = true);
                            _checkWalletStatus();
                          } else if (mounted) {
                            setSheetState(() => isVerifying = false);
                            pinController.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  walletProvider.error ?? 'Invalid PIN',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Confirm button ────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: isVerifying
                              ? null
                              : () async {
                                  if (pinController.text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please enter your PIN'),
                                      ),
                                    );
                                    return;
                                  }
                                  if (pinController.text.length < 4) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'PIN must be at least 4 digits',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  setSheetState(() => isVerifying = true);
                                  final walletProvider = ref.read(
                                    walletChangeNotifierProvider,
                                  );
                                  final isValid = await walletProvider
                                      .verifyPin(pinController.text);
                                  if (isValid && mounted) {
                                    _authenticationInProgress = false;
                                    Navigator.pop(sheetContext, true);
                                    setState(() => _isAuthenticated = true);
                                    _checkWalletStatus();
                                  } else if (mounted) {
                                    setSheetState(() => isVerifying = false);
                                    pinController.clear();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          walletProvider.error ?? 'Invalid PIN',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGold,
                            disabledBackgroundColor: AppColors.primaryGold
                                .withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                          child: isVerifying
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Confirm',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
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
      MaterialPageRoute(builder: (context) => const SetTransactionPinPage()),
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
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.privacy_tip_outlined,
                      color: AppColors.primaryGold,
                      size: 28,
                    ),
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
                        '1. INTRODUCTION',
                        'The City Gate Church ("the Church," "we," "us," or "our") is committed to protecting the privacy and personal data of our members, visitors, partners, and all users of our website, mobile application and digital platforms. This Privacy Policy is issued in compliance with the Nigeria Data Protection Act, 2023 ("NDPA"), its subsidiary regulations, and applicable guidance issued by the Nigeria Data Protection Commission ("NDPC").\n\nThis Policy explains what personal data we collect, why we collect it, how we use, store, share, and protect it, and the rights available to you as a data subject. It applies to our website https://thecitygatechurch.org, our mobile app (City Gate Mobile), our online giving platform, our livestream and social media channels, and any offline data collection connected to church activities (e.g., membership forms, event registration, pastoral care records).\n\nBy visiting our website, registering as a member, making a donation, joining our mailing list, attending our services (physically or online), or otherwise interacting with our ministries, you acknowledge that you have read and understood this Policy.',
                        isDark,
                      ),
                      _buildPolicySection(
                        '2. WHO WE ARE (DATA CONTROLLER)',
                        'The City Gate Church is registered as an incorporated trustee under the laws of the Federal Republic of Nigeria. We are the Data Controller responsible for your personal data collected and/or processed in connection with the above-listed channels.\n\nData Protection Officer Contact:\nName/Office: Tolulope Idowu\nEmail: itolulopeidowu@gmail.com',
                        isDark,
                      ),
                      _buildPolicySection(
                        '3. PERSONAL DATA WE COLLECT',
                        'We collect personal data in ways appropriate to modern church ministry, including online and hybrid worship. This includes:\n\n3.1 Identity and Contact Data\n• Full name, gender, date of birth, marital status\n• Home address, phone number, email address\n• Membership/unit/department affiliation\n\n3.2 Membership and Pastoral Data\n• Membership registration and attendance records\n• Dedication, wedding, and other sacramental records\n• Prayer requests, counseling notes, and pastoral care information\n• Small group, cell, or department membership\n\n3.3 Financial Data\n• Aggregated tithe, offering, and donation records\n• Payment card or bank details processed via third-party payment gateways (we do not directly store full card details)\n• Pledge and giving history for record-keeping and tax/receipt purposes\n\n3.4 Digital and Media Data\n• Photographs, audio, and video recordings of you taken during physical or online services, meetings, weddings, conferences, and other church events, including for livestreaming, sermon archiving, YouTube/social media uploads, and promotional materials\n• Comments, testimonies, and engagement on our social media pages, livestream chats, and website\n• Website usage data: IP address, browser type, device identifiers, cookies, and analytics data\n• Data submitted via online forms (event registration, newsletter subscription, contact forms)\n\n3.5 Children\'s Data\n• Data of minors relating to Sunday school, children\'s church, youth camps, and related programs, collected with parental/guardian consent\n\n3.6 Special Category / Sensitive Personal Data\n• Given the nature of our ministry, we may process data revealing religious beliefs (inherent in membership), health information (e.g., prayer requests for illness, medical needs during events, or First Aid incidents). This data is processed only where necessary, with explicit consent or another lawful basis recognized under the NDPA, and with heightened safeguards.',
                        isDark,
                      ),
                      _buildPolicySection(
                        '4. HOW WE COLLECT YOUR DATA',
                        '• Directly from you: membership forms, event registration, online giving, newsletter sign-up, contact forms, counseling sessions\n• Automatically: through cookies, analytics tools, and livestreaming platforms when you visit our website or watch our services online\n• From third parties: payment processors, event partner organizations, or publicly available sources (e.g., where you tag the Church on social media)',
                        isDark,
                      ),
                      _buildPolicySection(
                        '5. LAWFUL BASIS FOR PROCESSING',
                        'We process your personal data on one or more of the following lawful bases recognized under the NDPA:\n• Consent (e.g., Photography/video at events, newsletter subscriptions, children\'s programs)\n• Contract (e.g., Processing event registrations, staff/volunteer engagement)\n• Legal obligation (e.g., Statutory returns, tax purposes, regulatory reporting)\n• Vital interest (e.g., Emergency medical situations during church programs)\n• Legitimate interest (e.g., Church administration, security fraud prevention, ministry communication)\n• Public/religious interest task (e.g., Core religious and pastoral functions carried out in furtherance of our legitimate not-for-profit religious objectives)\n\nWhere consent is the basis for processing, you may withdraw it at any time without affecting the lawfulness of processing carried out before withdrawal.',
                        isDark,
                      ),
                      _buildPolicySection(
                        '6. CHILDREN\'S DATA',
                        'We recognize that children\'s data requires enhanced protection.\n• We obtain verifiable parental or guardian consent before collecting or processing personal data of children under 18 years.\n• Parents/guardians may request access to, correction of, or deletion of their child\'s data at any time.\n• We do not knowingly use children\'s images or data for unrelated marketing purposes without specific parental consent.\n• Photography and filming involving children during services or events will, where reasonably practicable, be flagged through visible notices, and parents may opt their children out by notifying the church office.',
                        isDark,
                      ),
                      _buildPolicySection(
                        '7. LIVESTREAMING, RECORDING, AND MEDIA MINISTRY',
                        'As part of our media and outreach ministry, our services, conferences, and select events are recorded, livestreamed, and/or broadcast via our website, YouTube, Facebook, Instagram, and other platforms.\n\n• Notice: Signage and/or verbal announcements will, where practicable, be displayed at physical venues to notify attendees that recording is in progress.\n• Public nature of broadcast: Please be aware that if you are seated in a congregation being filmed or attend in a livestreamed section, your image, voice, and likeness may be captured and made publicly available online indefinitely, including via third-party platforms whose own privacy policies also apply.\n• Requests for removal: If you appear in recorded content and wish to be removed, blurred, or excluded from future recordings, you may contact us, and we will make reasonable efforts to accommodate such requests, subject to technical feasibility and archival/ministry considerations.\n• Testimonies and personal stories: Where members share personal testimonies for broadcast, we obtain specific consent before publishing or repurposing such content.',
                        isDark,
                      ),
                      _buildPolicySection(
                        '8. COOKIES AND WEBSITE ANALYTICS',
                        'Our website uses cookies and similar tracking technologies to:\n• Enable core website functionality (e.g., online giving, event registration)\n• Understand how visitors use our website (analytics)\n• Improve user experience and remember preferences\n\nYou may control or disable cookies through your browser settings; however, this may affect certain website functionalities. Where required, we will present a cookie consent banner allowing you to accept or reject non-essential cookies before they are set.',
                        isDark,
                      ),
                      _buildPolicySection(
                        '9. HOW WE USE YOUR PERSONAL DATA',
                        'We use your personal data to:\n• Administer membership records and church activities\n• Process donations, tithes, and offerings, and issue giving statements/receipts\n• Communicate with you regarding services, events, and pastoral matters\n• Provide pastoral care and counseling\n• Livestream, record, and broadcast services and events\n• Operate and improve our website and digital platforms\n• Ensure security at our premises and events\n• Comply with legal, regulatory, and statutory obligations\n• Send newsletters and ministry updates\n\nWe do not sell your personal data to third parties, and we do not use your data for purposes incompatible with our religious, pastoral, and administrative mandate without your consent.',
                        isDark,
                      ),
                      _buildPolicySection(
                        '10. SHARING AND DISCLOSURE OF YOUR DATA',
                        'We may share your personal data with:\n• Service providers/processors: payment gateway providers, cloud storage and email service providers, livestreaming/broadcast platforms, church mobile application partners, software providers — all bound by data processing agreements consistent with the NDPA\n• Affiliated ministries/branches: where necessary for coordinated ministry activities\n• Regulatory and law enforcement authorities: where required by law, court order, or to protect vital interests\n• Professional advisers: auditors, lawyers, and consultants, under confidentiality obligations\n\nWe do not share sensitive pastoral or counseling records except with your consent, on a need-to-know basis among ministers involved in your care, or where disclosure is required by law.',
                        isDark,
                      ),
                      _buildPolicySection(
                        '11. CROSS-BORDER DATA TRANSFERS',
                        'We do not ordinarily transfer personal data outside of Nigeria but where personal data is transferred outside Nigeria (e.g., cloud hosting, livestreaming platforms, email service providers based abroad), we ensure such transfers comply with the NDPA\'s cross-border data transfer requirements.',
                        isDark,
                      ),
                      _buildPolicySection(
                        '12. DATA RETENTION',
                        'We retain personal data only for as long as necessary to fulfil the purposes outlined in this Policy. Specific retention periods include:\n• Membership and pastoral records: retained for the duration of membership and a reasonable period thereafter\n• Financial/giving records: retained in line with applicable tax and financial regulations (typically 6 years)\n• Website analytics and cookies: retained per the specific cookie/tool\'s retention settings\n• Media/livestream recordings: retained indefinitely for archival and ministry purposes, unless a removal request is honoured',
                        isDark,
                      ),
                      _buildPolicySection(
                        '13. YOUR RIGHTS AS A DATA SUBJECT',
                        'Under the NDPA, you have the right to:\n• Be informed about how your data is processed\n• Access the personal data we hold about you\n• Rectification of inaccurate or incomplete data\n• Erasure of your data, subject to legal or legitimate retention grounds\n• Restrict processing in certain circumstances\n• Object to processing based on legitimate interest or for direct marketing\n• Withdraw consent at any time, without affecting prior lawful processing\n• Not be subject to solely automated decision-making\n• Lodge a complaint with the Nigeria Data Protection Commission (NDPC)\n\nTo exercise any of these rights, please contact us. We will respond within the timeframe prescribed by the NDPA, and may request proof of identity before acting on your request.',
                        isDark,
                      ),
                      _buildPolicySection(
                        '14. HOW TO CONTACT US',
                        'For any questions, concerns, or requests regarding this Policy or your personal data:\nData Protection Officer | Email: itolulopeidowu@gmail.com\n\nIf you are not satisfied with our response, you may lodge a complaint with:\nNigeria Data Protection Commission (NDPC) Website: www.ndpc.gov.ng',
                        isDark,
                      ),
                      _buildPolicySection(
                        '15. DATA SECURITY',
                        'We implement appropriate technical and organizational measures to protect your personal data against unauthorized access, alteration, disclosure, or destruction. However, no method of electronic transmission or storage is completely secure, and we cannot guarantee absolute security.',
                        isDark,
                      ),
                      _buildPolicySection(
                        '16. THIRD-PARTY LINKS AND PLATFORMS',
                        'Our website and social media pages may contain links to third-party platforms (e.g., YouTube, Facebook, Instagram, payment processors). We are not responsible for the privacy practices of these third parties, and we encourage you to review their respective privacy policies.',
                        isDark,
                      ),
                      _buildPolicySection(
                        '17. CHANGES TO THIS POLICY',
                        'We may update this Privacy Policy from time to time to reflect changes in our practices, technology, legal requirements, or ministry operations. The updated version will be posted on our website with a revised "Last Reviewed" date. Continued use of our website and services after such changes constitutes your acceptance of the updated Policy.',
                        isDark,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Effective Date: July 31, 2026',
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
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appConfig = ref.watch(appConfigChangeNotifierProvider);

    if (appConfig.config.walletPageDisabled) {
      return _buildMaintenancePage(
        context,
        appConfig.config.walletPageDisabledMessage,
      );
    }

    if (!_hasInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startAuthentication();
      });
    }
    return _buildWalletUI(context);
  }

  Widget _buildMaintenancePage(BuildContext context, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = Responsive.horizontalPadding(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Wallet',
        showBackButton: true,
        lightBackground: true,
        onBackPressed: () => ref.read(mainTabIndexProvider.notifier).state = 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryGold.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.build_circle_outlined,
                  size: 48,
                  color: AppColors.primaryGold,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Wallet Under Maintenance',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message.isNotEmpty
                    ? message
                    : 'Wallet is temporarily under maintenance while we perform system upgrades. Please check back later.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ref.read(mainTabIndexProvider.notifier).state = 0;
                  },
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Back to Home'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the actual wallet UI (extracted from original build method)
  Widget _buildWalletUI(BuildContext context) {
    final walletProvider = ref.watch(walletChangeNotifierProvider);

    // Watch tab index to detect when user navigates to wallet tab
    final currentTabIndex = ref.watch(mainTabIndexProvider);

    // Check if tab changed and trigger re-authentication if needed (only if not already authenticated)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentTabIndex == 3 &&
          _previousTabIndex != null &&
          _previousTabIndex != 3 &&
          _hasInitialized &&
          !_isAuthenticated) {
        _startAuthentication();
      }
      _previousTabIndex = currentTabIndex;
    });

    // Show loading while authenticating or loading wallet
    if (!_isAuthenticated ||
        (walletProvider.isLoading && !walletProvider.isInitialized)) {
      return Scaffold(
        appBar: CustomAppBar(
          title: '',
          showBackButton: true,
          lightBackground: true,
          onBackPressed: _handleBackNavigation,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGold),
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

  Widget _buildWalletWelcomePage(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = Responsive.horizontalPadding(context);
    final spacing = Responsive.verticalSpacing(context);
    final maxWidth = Responsive.maxContentWidth(context);
    final titleFontSize = Responsive.titleFontSize(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final borderRadius = Responsive.borderRadius(context);
    
    final bgGradient = isDark 
        ? const LinearGradient(
            colors: [Color(0xFF1E1E1E), Color(0xFF121212)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter)
        : const LinearGradient(
            colors: [Color(0xFFF9FAFB), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Wallet',
        showBackButton: true,
        lightBackground: true,
        onBackPressed: _handleBackNavigation,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: EdgeInsets.all(horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: spacing * 2),

                    // Modern Glowing Wallet Icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryGold,
                            AppColors.primaryGold.withOpacity(0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryGold.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing * 2),

                    // Title
                    Text(
                      'TCGC Wallet',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: titleFontSize,
                      ),
                    ),
                    SizedBox(height: spacing),

                    // Description
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Experience seamless giving. Manage your tithes, offerings, and donations securely in one place.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          height: 1.5,
                          fontSize: bodyFontSize,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing * 2.5),

                    // Feature Cards
                    _buildPremiumFeatureItem(
                      context,
                      isDark,
                      Icons.shield_rounded,
                      'Bank-Grade Security',
                      'Powered by 9PSB with end-to-end encryption.',
                    ),
                    SizedBox(height: spacing),
                    _buildPremiumFeatureItem(
                      context,
                      isDark,
                      Icons.volunteer_activism_rounded,
                      'Effortless Giving',
                      'Give seamlessly with just a few taps.',
                    ),
                    SizedBox(height: spacing),
                    _buildPremiumFeatureItem(
                      context,
                      isDark,
                      Icons.history_rounded,
                      'Smart Tracking',
                      'Monitor all your transactions in real-time.',
                    ),
                    SizedBox(height: spacing * 2.5),

                    // Disclaimers (Modernized)
                    Container(
                      padding: EdgeInsets.all(horizontalPadding),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2D3E).withOpacity(0.5) : Colors.blue[50]?.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(borderRadius + 8),
                        border: Border.all(
                          color: isDark ? Colors.blueAccent.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.blueAccent.withOpacity(0.2) : Colors.blue[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.info_outline_rounded,
                              color: isDark ? Colors.blueAccent : Colors.blue[700],
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Important Notice',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.blue[900],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'TCGC is not a financial institution. Wallet transactions are securely handled by 9PSB via Sitanet Global Orbit.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.grey[400] : Colors.blue[800],
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'A one-time ₦150 verification fee will be deducted from your first deposit.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.orangeAccent : Colors.deepOrange[700],
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: spacing * 3),

                    // Policy Checkbox (Modernized)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Transform.scale(
                            scale: 1.1,
                            child: Checkbox(
                              value: _acceptedDataPolicy,
                              onChanged: (value) {
                                setState(
                                  () => _acceptedDataPolicy = value ?? false,
                                );
                              },
                              activeColor: AppColors.primaryGold,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              side: BorderSide(
                                color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
                                width: 2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text.rich(
                                TextSpan(
                                  text: 'I agree to the ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Data Protection Policy',
                                      style: const TextStyle(
                                        color: AppColors.primaryGold,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () => _showDataProtectionPolicy(
                                          context,
                                          isDark,
                                        ),
                                    ),
                                    const TextSpan(
                                      text: ' and consent to identity verification.',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: spacing * 4),

                    // Modern Create Button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(borderRadius),
                        boxShadow: _acceptedDataPolicy
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryGold.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : [],
                      ),
                      child: ElevatedButton(
                        onPressed: _acceptedDataPolicy
                            ? _navigateToCreateWallet
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGold,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                          disabledForegroundColor: isDark ? Colors.grey[600] : Colors.grey[500],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(borderRadius),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Create Wallet',
                          style: TextStyle(
                            fontSize: bodyFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: spacing * 3),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumFeatureItem(
    BuildContext context,
    bool isDark,
    IconData icon,
    String title,
    String description,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.15) : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryGold, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        height: 1.4,
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
