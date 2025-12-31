import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/notification_provider.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadPreferences();
    });
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
                      _buildSwitchTile(
                        context,
                        isDark,
                        'SMS Notifications',
                        prefs.smsEnabled,
                        (value) => notificationProvider.setSmsEnabled(value),
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
                        'Events & Announcements',
                        prefs.eventsEnabled,
                        (value) => notificationProvider.setEventsEnabled(value),
                      ),
                      _buildSwitchTile(
                        context,
                        isDark,
                        'New Sermons',
                        prefs.sermonsEnabled,
                        (value) => notificationProvider.setSermonsEnabled(value),
                      ),
                      _buildSwitchTile(
                        context,
                        isDark,
                        'Wallet Activity',
                        prefs.walletEnabled,
                        (value) => notificationProvider.setWalletEnabled(value),
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
                      _buildNavigationTile(context, isDark, 'Language', Icons.language),
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
                color: Colors.black.withOpacity(0.05),
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
}
