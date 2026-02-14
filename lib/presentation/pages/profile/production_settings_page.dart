import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/providers/biometric_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/custom_app_bar.dart';

class ProductionSettingsPage extends StatefulWidget {
  const ProductionSettingsPage({super.key});

  @override
  State<ProductionSettingsPage> createState() => _ProductionSettingsPageState();
}

class _ProductionSettingsPageState extends State<ProductionSettingsPage> {
  bool _messagesNotification = false;
  bool _faceBiometric = false;
  bool _fingerBiometric = false;
  bool _patternUnlock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPreferences();
    });
  }

  Future<void> _loadPreferences() async {
    try {
      final notificationProvider = context.read<NotificationProvider>();
      await notificationProvider.loadPreferences();
      if (mounted) {
        setState(() {
          _messagesNotification = notificationProvider.preferences.messagesEnabled;
        });
      }
    } catch (e) {
      debugPrint('Error loading notification preferences: $e');
    }

    try {
      final biometricProvider = context.read<BiometricProvider>();
      await biometricProvider.initialize();
      if (mounted) {
        setState(() {
          _faceBiometric = biometricProvider.biometricLoginEnabled;
          _fingerBiometric = biometricProvider.biometricTransactionEnabled;
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
      appBar: const CustomAppBar(title: 'Production Settings', showBackButton: true),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSettingsSection(
                context,
                isDark,
                'Production Settings',
                [
                  _buildSwitchTile(
                    context,
                    isDark,
                    'Messages Notification',
                    _messagesNotification,
                    (value) {
                      setState(() => _messagesNotification = value);
                      context.read<NotificationProvider>().setMessagesEnabled(value);
                    },
                  ),
                  _buildSwitchTileWithSubtitle(
                    context,
                    isDark,
                    'Enable Face Biometric',
                    'Use face recognition for authentication',
                    _faceBiometric,
                    (value) => _handleFaceBiometricToggle(value),
                  ),
                  _buildSwitchTileWithSubtitle(
                    context,
                    isDark,
                    'Enable Finger Biometric',
                    'Use fingerprint for authentication',
                    _fingerBiometric,
                    (value) {
                      setState(() => _fingerBiometric = value);
                      context.read<BiometricProvider>().setBiometricTransactionEnabled(value);
                    },
                  ),
                  _buildSwitchTileWithSubtitle(
                    context,
                    isDark,
                    'Enable Password/Pattern Unlock',
                    'Use device password or pattern for authentication',
                    _patternUnlock,
                    (value) => setState(() => _patternUnlock = value),
                  ),
                ],
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleFaceBiometricToggle(bool value) async {
    final biometricProvider = context.read<BiometricProvider>();
    if (value) {
      final authProvider = context.read<AuthProvider>();
      final email = authProvider.user?.email;
      if (email != null) {
        _showEnableBiometricDialog(biometricProvider, email);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to enable face biometric.')),
        );
      }
    } else {
      setState(() => _faceBiometric = false);
      await biometricProvider.setBiometricLoginEnabled(false);
    }
  }

  void _showEnableBiometricDialog(BiometricProvider biometricProvider, String email) {
    final passwordController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        title: const Text('Enable Face Biometric'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your password to enable face biometric:'),
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
                setState(() => _faceBiometric = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Face biometric enabled')),
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
}
