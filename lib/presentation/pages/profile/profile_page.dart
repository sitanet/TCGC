import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../legal/privacy_policy_page.dart';
import '../support/complaint_page.dart';
import 'edit_profile_page.dart';
import 'settings_page.dart';
import 'wallet_management_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(context, isDark),
            const SizedBox(height: 24),
            _buildMenuItems(context, isDark),
            const SizedBox(height: 24),
            _buildLogoutButton(context, isDark),
            const SizedBox(height: 24),
            _buildPrivacyPolicyLink(context, isDark),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, bool isDark) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final displayName = user?.fullName ?? user?.email ?? 'User';

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(30),
        bottomRight: Radius.circular(30),
      ),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/profile_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.5),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildThemeToggle(context, themeProvider),
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EditProfilePage(),
                    ),
                  );
                },
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[300],
                      child: const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context, ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode
                    ? Colors.white.withOpacity(0.2)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.dark_mode,
                color: Colors.white.withOpacity(0.8),
                size: 20,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => themeProvider.setThemeMode(ThemeMode.light),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: !themeProvider.isDarkMode
                    ? Colors.white.withOpacity(0.2)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.light_mode,
                color: Colors.white.withOpacity(0.8),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItems(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
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
        child: Column(
          children: [
            _buildMenuItem(
              context,
              isDark,
              Icons.person_outline,
              'Edit your Profile',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EditProfilePage(),
                  ),
                );
              },
            ),
            _buildDivider(isDark),
            _buildMenuItem(
              context,
              isDark,
              Icons.account_balance_wallet_outlined,
              'Wallet',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WalletManagementPage(),
                  ),
                );
              },
            ),
            _buildDivider(isDark),
            _buildMenuItem(
              context,
              isDark,
              Icons.settings_outlined,
              'Settings',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsPage(),
                  ),
                );
              },
            ),
            _buildDivider(isDark),
            _buildMenuItem(
              context,
              isDark,
              Icons.chat_bubble_outline,
              'Chat with us',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ComplaintPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    bool isDark,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
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
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 56,
      color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
    );
  }

  Widget _buildLogoutButton(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            await authProvider.logout();
          },
          icon: const Icon(Icons.logout, color: Colors.white),
          label: const Text(
            'Log Out',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGold,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyPolicyLink(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PrivacyPolicyPage(),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.privacy_tip_outlined,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Privacy & Data Policy',
                  style: Theme.of(context).textTheme.titleMedium,
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
      ),
    );
  }
}
