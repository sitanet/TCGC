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
  bool _pushNotifications = false;
  bool _emailNotifications = false;
  bool _events = false;
  bool _newSermons = false;
  bool _walletActivity = false;
  bool _teensContent = false;
  bool _announcements = false;
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

  Future<void> _updateNotificationSetting(
    bool value,
    String settingName,
    VoidCallback updateState,
    Future<bool> Function() saveToProvider,
    VoidCallback revertState,
  ) async {
    if (_isSaving) return;
    _isSaving = true;
    updateState();
    
    try {
      final success = await saveToProvider();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$settingName ${value ? "enabled" : "disabled"}'),
            duration: const Duration(seconds: 1),
          ),
        );
      } else if (mounted) {
        revertState();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save setting. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving notification setting: $e');
      if (mounted) {
        revertState();
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

  Future<void> _loadPreferences() async {
    if (!mounted) return;
    
    final notificationProvider = context.read<NotificationProvider>();
    final biometricProvider = context.read<BiometricProvider>();
    
    try {
      await notificationProvider.loadPreferences();
      if (mounted) {
        final prefs = notificationProvider.preferences;
        setState(() {
          _pushNotifications = prefs.pushEnabled;
          _emailNotifications = prefs.emailEnabled;
          _events = prefs.eventsEnabled;
          _newSermons = prefs.messagesEnabled;
          _walletActivity = prefs.walletEnabled;
          _teensContent = prefs.teensEnabled;
          _announcements = prefs.announcementsEnabled;
        });
      }
    } catch (e) {
      debugPrint('Error loading notification preferences: $e');
    }

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
                  _buildSwitchTile(
                    context,
                    isDark,
                    'Push Notifications',
                    _pushNotifications,
                    (value) => _updateNotificationSetting(
                      value,
                      'Push Notifications',
                      () => setState(() => _pushNotifications = value),
                      () => context.read<NotificationProvider>().setPushEnabled(value),
                      () => setState(() => _pushNotifications = !value),
                    ),
                  ),
                  _buildSwitchTile(
                    context,
                    isDark,
                    'Email Notifications',
                    _emailNotifications,
                    (value) => _updateNotificationSetting(
                      value,
                      'Email Notifications',
                      () => setState(() => _emailNotifications = value),
                      () => context.read<NotificationProvider>().setEmailEnabled(value),
                      () => setState(() => _emailNotifications = !value),
                    ),
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
                    _events,
                    (value) => _updateNotificationSetting(
                      value,
                      'Events notifications',
                      () => setState(() => _events = value),
                      () => context.read<NotificationProvider>().setEventsEnabled(value),
                      () => setState(() => _events = !value),
                    ),
                  ),
                  _buildSwitchTile(
                    context,
                    isDark,
                    'New Sermons',
                    _newSermons,
                    (value) => _updateNotificationSetting(
                      value,
                      'Sermons notifications',
                      () => setState(() => _newSermons = value),
                      () => context.read<NotificationProvider>().setMessagesEnabled(value),
                      () => setState(() => _newSermons = !value),
                    ),
                  ),
                  _buildSwitchTile(
                    context,
                    isDark,
                    'Wallet Activity',
                    _walletActivity,
                    (value) => _updateNotificationSetting(
                      value,
                      'Wallet notifications',
                      () => setState(() => _walletActivity = value),
                      () => context.read<NotificationProvider>().setWalletEnabled(value),
                      () => setState(() => _walletActivity = !value),
                    ),
                  ),
                  _buildSwitchTile(
                    context,
                    isDark,
                    'Teens Content',
                    _teensContent,
                    (value) => _updateNotificationSetting(
                      value,
                      'Teens notifications',
                      () => setState(() => _teensContent = value),
                      () => context.read<NotificationProvider>().setTeensEnabled(value),
                      () => setState(() => _teensContent = !value),
                    ),
                  ),
                  _buildSwitchTile(
                    context,
                    isDark,
                    'Announcements',
                    _announcements,
                    (value) => _updateNotificationSetting(
                      value,
                      'Announcements',
                      () => setState(() => _announcements = value),
                      () => context.read<NotificationProvider>().setAnnouncementsEnabled(value),
                      () => setState(() => _announcements = !value),
                    ),
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
                    'Biometric Login',
                    'Use biometric to sign in',
                    _biometricLogin,
                    (value) => _handleBiometricLoginToggle(value),
                  ),
                  _buildSwitchTileWithSubtitle(
                    context,
                    isDark,
                    'Biometric for Transactions',
                    'Use biometric instead of PIN for transactions',
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
      ),
    );
  }

  Future<void> _handleBiometricLoginToggle(bool value) async {
    final biometricProvider = context.read<BiometricProvider>();
    
    // Check if biometrics are available on device
    if (!biometricProvider.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometrics not available. Please set up fingerprint or face unlock on your device first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (value) {
      final authProvider = context.read<AuthProvider>();
      final email = authProvider.user?.email;
      if (email != null) {
        _showEnableBiometricLoginDialog(biometricProvider, email);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to enable biometric login. Please log in first.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      setState(() => _biometricLogin = false);
      await biometricProvider.setBiometricLoginEnabled(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric login disabled')),
        );
      }
    }
  }

  Future<void> _handleBiometricTransactionToggle(bool value) async {
    final biometricProvider = context.read<BiometricProvider>();
    
    if (!biometricProvider.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometrics not available. Please set up fingerprint or face unlock on your device first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final previousValue = _biometricTransactions;
    setState(() => _biometricTransactions = value);
    
    await biometricProvider.setBiometricTransactionEnabled(value);
    
    // Check if it actually changed (authentication might have failed)
    if (biometricProvider.biometricTransactionEnabled != value && mounted) {
      setState(() => _biometricTransactions = previousValue);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to change biometric setting. Authentication required.'),
          backgroundColor: Colors.red,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? 'Biometric for transactions enabled' : 'Biometric for transactions disabled')),
      );
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
                setState(() => _biometricLogin = true);
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
}
