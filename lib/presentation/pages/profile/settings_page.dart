import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/biometric_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';
import 'change_password_page.dart';
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
          _biometricTransactions = biometricProvider.biometricTransactionEnabled;
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
      final success =
          await ref.read(notificationChangeNotifierProvider).setEmailEnabled(value);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Email notifications ${value ? "enabled" : "disabled"}'),
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
      final success =
          await ref.read(notificationChangeNotifierProvider).setPromotionsEnabled(value);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Promotions ${value ? "enabled" : "disabled"}'),
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
              _buildSettingsSection(
                context,
                isDark,
                'Notifications',
                [
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
                ],
              ),
              const SizedBox(height: 24),
              _buildSettingsSection(
                context,
                isDark,
                'Security',
                [
                  _buildSwitchTileWithSubtitle(
                    context,
                    isDark,
                    'Fingerprint Login',
                    'Use fingerprint to sign in',
                    _biometricLogin,
                    (value) => _handleBiometricLoginToggle(value),
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
                    'Fingerprint for Transactions',
                    'Use fingerprint instead of PIN for transactions',
                    _biometricTransactions,
                    (value) => _handleBiometricTransactionToggle(value),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSettingsSection(
                context,
                isDark,
                'Account',
                [
                  _buildNavigationTile(
                      context, isDark, 'Interests', Icons.interests_outlined),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: isDark
                        ? Colors.white.withAlpha(25)
                        : Colors.black.withAlpha(13),
                  ),
                  _buildNavigationTile(
                      context, isDark, 'Change Password', Icons.lock_outline),
                ],
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleBiometricLoginToggle(bool value) async {
    final biometricProvider = ref.read(biometricChangeNotifierProvider);

    // Re-initialize to get fresh status
    await biometricProvider.initialize();

    if (!biometricProvider.isAvailable) {
      debugPrint('Biometric not available after re-check');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Biometrics not available. Please set up fingerprint on your device first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (value) {
      final authProvider = ref.read(authChangeNotifierProvider);
      final email = authProvider.user?.email;
      if (email != null) {
        _showEnableBiometricLoginDialog(biometricProvider, email);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Unable to enable fingerprint login. Please log in first.'),
            backgroundColor: Colors.red,
          ),
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

  Future<void> _handleBiometricTransactionToggle(bool value) async {
    final biometricProvider = ref.read(biometricChangeNotifierProvider);

    if (!biometricProvider.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Biometrics not available. Please set up fingerprint on your device first.'),
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
              'Failed to change fingerprint setting. Authentication required.'),
          backgroundColor: Colors.red,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(value
                ? 'Fingerprint for transactions enabled'
                : 'Fingerprint for transactions disabled')),
      );
    }
  }

  void _showEnableBiometricLoginDialog(
      BiometricProvider biometricProvider, String email) {
    final passwordController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        title: const Text('Enable Fingerprint Login'),
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
              decoration: const InputDecoration(
                labelText: 'Account Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter your password')),
                );
                return;
              }
              final password = passwordController.text;
              Navigator.pop(dialogContext);
              
              await biometricProvider.setBiometricLoginEnabled(
                true,
                email: email,
                password: password,
              );
              
              if (!mounted) return;
              
              if (biometricProvider.biometricLoginEnabled) {
                setState(() => _biometricLogin = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Fingerprint login enabled')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fingerprint authentication failed or was cancelled. Please try again.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold),
            child:
                const Text('Enable', style: TextStyle(color: Colors.white)),
          ),
        ],
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
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
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
            MaterialPageRoute(
                builder: (context) => const ChangePasswordPage()),
          );
        } else if (title == 'Interests') {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const EditInterestsPage()),
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
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
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
