import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/biometric_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';
import 'change_password_page.dart';
import 'change_pin_page.dart';
import '../interests/edit_interests_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _emailNotifications = false;
  bool _promotionsEnabled = true;
  bool _biometricLogin = false;
  bool _biometricTransactions = false;
  bool _faceLogin = false;
  bool _faceTransactions = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPreferences();
    });
  }

  Future<void> _loadPreferences() async {
    if (!mounted) return;

    final notificationProvider = ref.read(notificationChangeNotifierProvider);
    final biometricProvider = ref.read(biometricChangeNotifierProvider);

    // Load notification preferences from backend
    try {
      await notificationProvider.loadPreferences();
      if (mounted) {
        final prefs = notificationProvider.preferences;
        setState(() {
          _emailNotifications = prefs.emailEnabled;
          _promotionsEnabled = prefs.promotionsEnabled;
        });
      }
    } catch (e) {
      debugPrint('Error loading notification preferences: $e');
    }

    // Load biometric preferences
    try {
      await biometricProvider.initialize();
      if (mounted) {
        setState(() {
          _biometricLogin = biometricProvider.biometricLoginEnabled;
          _biometricTransactions =
              biometricProvider.biometricTransactionEnabled;
          _faceLogin = biometricProvider.faceLoginEnabled;
          _faceTransactions = biometricProvider.faceTransactionEnabled;
        });
      }
    } catch (e) {
      debugPrint('Error initializing biometric: $e');
    }
  }

  Future<void> _updateEmailNotificationSetting(bool value) async {
    if (_isSaving) return;
    _isSaving = true;

    final previousValue = _emailNotifications;
    setState(() => _emailNotifications = value);

    try {
      final success = await ref
          .read(notificationChangeNotifierProvider)
          .setEmailEnabled(value);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Email notifications ${value ? "enabled" : "disabled"}',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      } else if (mounted) {
        setState(() => _emailNotifications = previousValue);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save setting. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving email notification setting: $e');
      if (mounted) {
        setState(() => _emailNotifications = previousValue);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save setting. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _updatePromotionsSetting(bool value) async {
    if (_isSaving) return;
    _isSaving = true;

    final previousValue = _promotionsEnabled;
    setState(() => _promotionsEnabled = value);

    try {
      final success = await ref
          .read(notificationChangeNotifierProvider)
          .setPromotionsEnabled(value);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Promotions ${value ? "enabled" : "disabled"}'),
            duration: const Duration(seconds: 1),
          ),
        );
      } else if (mounted) {
        setState(() => _promotionsEnabled = previousValue);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save setting. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving promotions setting: $e');
      if (mounted) {
        setState(() => _promotionsEnabled = previousValue);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save setting. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isSaving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Settings', showBackButton: true),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSettingsSection(context, isDark, 'Notifications', [
                _buildSwitchTileWithSubtitle(
                  context,
                  isDark,
                  'Email Notifications',
                  'Receive email updates and alerts',
                  _emailNotifications,
                  (value) => _updateEmailNotificationSetting(value),
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: isDark
                      ? Colors.white.withAlpha(25)
                      : Colors.black.withAlpha(13),
                ),
                _buildSwitchTileWithSubtitle(
                  context,
                  isDark,
                  'Promotions',
                  'Show promotional popups in the app',
                  _promotionsEnabled,
                  (value) => _updatePromotionsSetting(value),
                ),
              ]),
              const SizedBox(height: 24),
              _buildSettingsSection(
                context,
                isDark,
                'Security',
                _buildSecurityTiles(isDark),
              ),
              const SizedBox(height: 24),
              _buildSettingsSection(context, isDark, 'Account', [
                _buildNavigationTile(
                  context,
                  isDark,
                  'Interests',
                  Icons.interests_outlined,
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: isDark
                      ? Colors.white.withAlpha(25)
                      : Colors.black.withAlpha(13),
                ),
                _buildNavigationTile(
                  context,
                  isDark,
                  'Change Password',
                  Icons.lock_outline,
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: isDark
                      ? Colors.white.withAlpha(25)
                      : Colors.black.withAlpha(13),
                ),
                _buildNavigationTile(
                  context,
                  isDark,
                  'Change Transaction PIN',
                  Icons.pin_outlined,
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: isDark
                      ? Colors.white.withAlpha(25)
                      : Colors.black.withAlpha(13),
                ),
                _buildNavigationTile(
                  context,
                  isDark,
                  'Reset Transaction PIN',
                  Icons.lock_reset_outlined,
                ),
              ]),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build security tiles dynamically based on device capabilities ──────────
  List<Widget> _buildSecurityTiles(bool isDark) {
    final biometricProvider = ref.read(biometricChangeNotifierProvider);
    final hasFingerprint = biometricProvider.hasFingerprint;
    final hasFace = biometricProvider.hasFace;
    final divider = Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(13),
    );

    final tiles = <Widget>[];

    // ── Fingerprint options (only if device has fingerprint) ─────────────────
    if (hasFingerprint) {
      tiles.add(
        _buildSwitchTileWithSubtitle(
          context,
          isDark,
          'Fingerprint Login',
          'Use fingerprint to sign in',
          _biometricLogin,
          (v) => _handleBiometricLoginToggle(v),
        ),
      );
      tiles.add(divider);
      tiles.add(
        _buildSwitchTileWithSubtitle(
          context,
          isDark,
          'Fingerprint for Transactions',
          'Use fingerprint instead of PIN for transactions',
          _biometricTransactions,
          (v) => _handleBiometricTransactionToggle(v),
        ),
      );
    }

    // ── Face recognition options (only if device has face recognition) ────────
    if (hasFace) {
      if (tiles.isNotEmpty) tiles.add(divider);
      tiles.add(
        _buildSwitchTileWithSubtitle(
          context,
          isDark,
          'Face ID Login',
          'Use face recognition to sign in',
          _faceLogin,
          (v) => _handleFaceLoginToggle(v),
        ),
      );
      tiles.add(divider);
      tiles.add(
        _buildSwitchTileWithSubtitle(
          context,
          isDark,
          'Face ID for Transactions',
          'Use face recognition instead of PIN for transactions',
          _faceTransactions,
          (v) => _handleFaceTransactionToggle(v),
        ),
      );
    }

    // ── No biometrics available ───────────────────────────────────────────────
    if (tiles.isEmpty) {
      tiles.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No biometrics available on this device. Use your password to sign in.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return tiles;
  }

  Future<void> _handleBiometricLoginToggle(bool value) async {
    final biometricProvider = ref.read(biometricChangeNotifierProvider);
    await biometricProvider.initialize();

    if (!biometricProvider.isAvailable || !biometricProvider.hasFingerprint) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fingerprint not available. Please set up fingerprint on your device first.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (value) {
      final authProvider = ref.read(authChangeNotifierProvider);
      final email = authProvider.user?.email;
      if (email != null) {
        _showEnableBiometricLoginDialog(
          biometricProvider,
          email,
          isFace: false,
        );
      }
    } else {
      setState(() => _biometricLogin = false);
      await biometricProvider.setBiometricLoginEnabled(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fingerprint login disabled')),
        );
      }
    }
  }

  Future<void> _handleFaceLoginToggle(bool value) async {
    final biometricProvider = ref.read(biometricChangeNotifierProvider);
    await biometricProvider.initialize();

    if (!biometricProvider.isAvailable || !biometricProvider.hasFace) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Face recognition not available on this device.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (value) {
      final authProvider = ref.read(authChangeNotifierProvider);
      final email = authProvider.user?.email;
      if (email != null) {
        _showEnableBiometricLoginDialog(biometricProvider, email, isFace: true);
      }
    } else {
      setState(() => _faceLogin = false);
      await biometricProvider.setFaceLoginEnabled(false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Face ID login disabled')));
      }
    }
  }

  Future<void> _handleFaceTransactionToggle(bool value) async {
    final biometricProvider = ref.read(biometricChangeNotifierProvider);

    if (!biometricProvider.isAvailable || !biometricProvider.hasFace) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Face recognition not available on this device.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final prev = _faceTransactions;
    setState(() => _faceTransactions = value);
    await biometricProvider.setFaceTransactionEnabled(value);

    if (biometricProvider.faceTransactionEnabled != value && mounted) {
      setState(() => _faceTransactions = prev);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Face ID authentication failed or was cancelled.'),
          backgroundColor: Colors.red,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Face ID for transactions enabled'
                : 'Face ID for transactions disabled',
          ),
        ),
      );
    }
  }

  Future<void> _handleBiometricTransactionToggle(bool value) async {
    final biometricProvider = ref.read(biometricChangeNotifierProvider);

    if (!biometricProvider.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Biometrics not available. Please set up fingerprint on your device first.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final previousValue = _biometricTransactions;
    setState(() => _biometricTransactions = value);

    await biometricProvider.setBiometricTransactionEnabled(value);

    if (biometricProvider.biometricTransactionEnabled != value && mounted) {
      setState(() => _biometricTransactions = previousValue);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to change fingerprint setting. Authentication required.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Fingerprint for transactions enabled'
                : 'Fingerprint for transactions disabled',
          ),
        ),
      );
    }
  }

  void _showEnableBiometricLoginDialog(
    BiometricProvider biometricProvider,
    String email, {
    bool isFace = false,
  }) {
    final passwordController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isVerifying = false;
    final label = isFace ? 'Face ID' : 'Fingerprint';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.cardDark : Colors.white,
          title: Text('Enable $label Login'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the password you created when you registered for the app. '
                'This is NOT your phone unlock pattern or PIN.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                enabled: !isVerifying,
                decoration: const InputDecoration(
                  labelText: 'Account Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isVerifying
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isVerifying
                  ? null
                  : () async {
                      if (passwordController.text.isEmpty) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter your password'),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => isVerifying = true);
                      final authProvider = ref.read(authChangeNotifierProvider);
                      final isValid = await authProvider.verifyPassword(
                        passwordController.text,
                      );
                      if (!isValid) {
                        setDialogState(() => isVerifying = false);
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                authProvider.error ?? 'Invalid password',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        return;
                      }
                      final password = passwordController.text;
                      Navigator.pop(dialogContext);
                      if (isFace) {
                        await biometricProvider.setFaceLoginEnabled(
                          true,
                          email: email,
                          password: password,
                        );
                        if (!mounted) return;
                        if (biometricProvider.faceLoginEnabled) {
                          setState(() => _faceLogin = true);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Face ID login enabled'),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Face ID authentication failed or was cancelled.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } else {
                        await biometricProvider.setBiometricLoginEnabled(
                          true,
                          email: email,
                          password: password,
                        );
                        if (!mounted) return;
                        if (biometricProvider.biometricLoginEnabled) {
                          setState(() => _biometricLogin = true);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Fingerprint login enabled'),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Fingerprint authentication failed or was cancelled.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
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
                  : const Text('Enable', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPinDialog(bool isDark) {
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    bool isLoading = false;
    bool isVerified = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    final biometricProvider = ref.read(biometricChangeNotifierProvider);
    final canUseBiometric =
        biometricProvider.isAvailable &&
        biometricProvider.biometricTransactionEnabled;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.cardDark : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(isVerified ? 'Set New PIN' : 'Verify Identity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isVerified) ...[
                Text(
                  'Verify your identity using your current PIN${canUseBiometric ? " or fingerprint" : ""}.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: currentPinController,
                  obscureText: obscureCurrent,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Current PIN',
                    counterText: '',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrent
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setDialogState(
                        () => obscureCurrent = !obscureCurrent,
                      ),
                    ),
                  ),
                ),
                if (canUseBiometric) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      onPressed: isLoading
                          ? null
                          : () async {
                              setDialogState(() => isLoading = true);
                              final authenticated = await biometricProvider
                                  .authenticateForTransaction();
                              if (authenticated) {
                                setDialogState(() {
                                  isVerified = true;
                                  isLoading = false;
                                });
                              } else {
                                setDialogState(() => isLoading = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Biometric authentication failed',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      icon: const Icon(
                        Icons.fingerprint,
                        color: AppColors.primaryGold,
                      ),
                      label: const Text(
                        'Use Fingerprint',
                        style: TextStyle(color: AppColors.primaryGold),
                      ),
                    ),
                  ),
                ],
              ] else ...[
                Text(
                  'Enter a new 4-digit PIN for your wallet transactions.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: newPinController,
                  obscureText: obscureNew,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'New PIN',
                    counterText: '',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPinController,
                  obscureText: obscureConfirm,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Confirm PIN',
                    counterText: '',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setDialogState(
                        () => obscureConfirm = !obscureConfirm,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final walletProvider = ref.read(
                        walletChangeNotifierProvider,
                      );

                      if (!isVerified) {
                        // Verify current PIN
                        if (currentPinController.text.length != 4) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('PIN must be 4 digits'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isLoading = true);
                        final isValid = await walletProvider.verifyPin(
                          currentPinController.text,
                        );

                        if (isValid) {
                          setDialogState(() {
                            isVerified = true;
                            isLoading = false;
                          });
                        } else {
                          setDialogState(() => isLoading = false);
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  walletProvider.error ?? 'Invalid PIN',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } else {
                        // Set new PIN
                        if (newPinController.text.length != 4) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('PIN must be 4 digits'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (newPinController.text !=
                            confirmPinController.text) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('PINs do not match'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isLoading = true);

                        final success = await walletProvider.setTransactionPin(
                          newPinController.text,
                          confirmPinController.text,
                        );

                        if (!mounted) return;
                        Navigator.pop(dialogContext);

                        if (success) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Transaction PIN reset successfully',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                walletProvider.error ?? 'Failed to reset PIN',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isVerified ? 'Reset PIN' : 'Verify',
                      style: const TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context,
    bool isDark,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryGold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTileWithSubtitle(
    BuildContext context,
    bool isDark,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool>? onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primaryGold,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile(
    BuildContext context,
    bool isDark,
    String title,
    IconData icon,
  ) {
    return InkWell(
      onTap: () {
        if (title == 'Change Password') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChangePasswordPage()),
          );
        } else if (title == 'Change Transaction PIN') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChangePinPage()),
          );
        } else if (title == 'Reset Transaction PIN') {
          _showResetPinDialog(isDark);
        } else if (title == 'Interests') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EditInterestsPage()),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.primaryGold),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.bodyLarge),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }
}
