import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/providers/biometric_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/custom_app_bar.dart';
import 'change_password_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    // Fire and forget - providers will notify listeners when ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSettings();
    });
  }

  Future<void> _initializeSettings() async {
    try {
      final notificationProvider = context.read<NotificationProvider>();
      await notificationProvider.loadPreferences().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('Notification preferences timed out');
        },
      );
    } catch (e) {
      debugPrint('Error loading notification preferences: $e');
    }

    try {
      final biometricProvider = context.read<BiometricProvider>();
      await biometricProvider.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('Biometric initialization timed out');
        },
      );
    } catch (e) {
      debugPrint('Error initializing biometric: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Settings', showBackButton: true),
      body: Consumer<NotificationProvider>(
        builder: (context, notificationProvider, _) {
          final prefs = notificationProvider.preferences;

          return SingleChildScrollView(
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
                      _buildSwitchTile(
                        context,
                        isDark,
                        'Push Notifications',
                        prefs.pushEnabled,
                        (value) => notificationProvider.setPushEnabled(value),
                      ),
                      _buildSwitchTile(
                        context,
                        isDark,
                        'Email Notifications',
                        prefs.emailEnabled,
                        (value) => notificationProvider.setEmailEnabled(value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSettingsSection(
                    context,
                    isDark,
                    'Notification Categories',
                    [
                      _buildSwitchTile(
                        context,
                        isDark,
                        'Events',
                        prefs.eventsEnabled,
                        (value) => notificationProvider.setEventsEnabled(value),
                      ),
                      _buildSwitchTile(
                        context,
                        isDark,
                        'New Sermons',
                        prefs.messagesEnabled,
                        (value) => notificationProvider.setMessagesEnabled(value),
                      ),
                      _buildSwitchTile(
                        context,
                        isDark,
                        'Wallet Activity',
                        prefs.walletEnabled,
                        (value) => notificationProvider.setWalletEnabled(value),
                      ),
                      _buildSwitchTile(
                        context,
                        isDark,
                        'Teens Content',
                        prefs.teensEnabled,
                        (value) => notificationProvider.setTeensEnabled(value),
                      ),
                      _buildSwitchTile(
                        context,
                        isDark,
                        'Announcements',
                        prefs.announcementsEnabled,
                        (value) => notificationProvider.setAnnouncementsEnabled(value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSecuritySection(context, isDark),
                  const SizedBox(height: 24),
                  _buildSettingsSection(
                    context,
                    isDark,
                    'Account',
                    [
                      _buildNavigationTile(context, isDark, 'Change Password', Icons.lock_outline),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSettingsSection(
                    context,
                    isDark,
                    'About',
                    [
                      _buildInfoTile(context, isDark, 'App Version', '1.0.0'),
                    ],
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
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

  Widget _buildSwitchTile(
    BuildContext context,
    bool isDark,
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge,
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
            MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context,
    bool isDark,
    String title,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection(BuildContext context, bool isDark) {
    return Consumer<BiometricProvider>(
      builder: (context, biometricProvider, _) {
        final isAvailable = biometricProvider.isAvailable;
        final biometricName = biometricProvider.biometricTypeName;

        return _buildSettingsSection(
          context,
          isDark,
          'Security',
          [
            _buildSwitchTileWithSubtitle(
              context,
              isDark,
              'Biometric Login',
              isAvailable
                  ? 'Use $biometricName to sign in'
                  : 'Biometric not available on this device',
              biometricProvider.biometricLoginEnabled,
              isAvailable
                  ? (value) => _handleBiometricLoginToggle(value, biometricProvider)
                  : null,
            ),
            _buildSwitchTileWithSubtitle(
              context,
              isDark,
              'Biometric for Transactions',
              isAvailable
                  ? 'Use $biometricName instead of PIN for transactions'
                  : 'Biometric not available on this device',
              biometricProvider.biometricTransactionEnabled,
              isAvailable
                  ? (value) => biometricProvider.setBiometricTransactionEnabled(value)
                  : null,
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleBiometricLoginToggle(bool value, BiometricProvider biometricProvider) async {
    if (value) {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.user;

      final email = user?.email;
      if (email != null) {
        _showEnableBiometricLoginDialog(biometricProvider, email);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to enable biometric login. Please try again later.')),
        );
      }
    } else {
      await biometricProvider.setBiometricLoginEnabled(false);
    }
  }

  void _showEnableBiometricLoginDialog(BiometricProvider biometricProvider, String email) {
    final passwordController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        title: const Text('Enable Biometric Login'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your password to enable biometric login:'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
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
                  const SnackBar(content: Text('Please enter your password')),
                );
                return;
              }

              Navigator.pop(dialogContext);

              await biometricProvider.setBiometricLoginEnabled(
                true,
                email: email,
                password: passwordController.text,
              );

              if (biometricProvider.biometricLoginEnabled && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Biometric login enabled')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold),
            child: const Text('Enable', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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
}
