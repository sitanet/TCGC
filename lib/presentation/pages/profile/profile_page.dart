import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../main.dart';
import '../legal/privacy_policy_page.dart';
import '../support/complaint_page.dart';
import 'edit_profile_page.dart';
import 'settings_page.dart';
import '../wallet/wallet_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spacing = Responsive.verticalSpacing(context);
    final maxWidth = Responsive.maxContentWidth(context);

    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              children: [
                _buildProfileHeader(context, isDark, ref),
                SizedBox(height: spacing * 1.5),
                _buildMenuItems(context, isDark),
                SizedBox(height: spacing * 1.5),
                _buildPrivacyPolicyLink(context, isDark),
                SizedBox(height: spacing * 1.5),
                _buildDeleteAccountButton(context, isDark, ref),
                SizedBox(height: spacing),
                _buildLogoutButton(context, isDark, ref),
                SizedBox(height: spacing * 6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, bool isDark, WidgetRef ref) {
    final themeProvider = ref.watch(themeChangeNotifierProvider);
    final authProvider = ref.watch(authChangeNotifierProvider);
    final user = authProvider.user;
    final displayName = user?.fullName ?? user?.email ?? 'User';
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        image: const DecorationImage(
          image: AssetImage('assets/images/profile_background.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
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
            // Status bar space
            SizedBox(height: statusBarHeight),
            // Top row with back button and theme toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  // Theme toggle
                  _buildThemeToggle(context, themeProvider),
                ],
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
                    backgroundImage: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                        ? NetworkImage(user.photoUrl!)
                        : null,
                    child: user?.photoUrl == null || user!.photoUrl!.isEmpty
                        ? const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.grey,
                          )
                        : null,
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
    final horizontalPadding = Responsive.horizontalPadding(context);
    final borderRadius = Responsive.borderRadius(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(borderRadius),
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
                    builder: (_) => const WalletPage(),
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
    final spacing = Responsive.verticalSpacing(context);
    final iconSize = Responsive.iconSize(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final borderRadius = Responsive.borderRadius(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(borderRadius),
      child: Padding(
        padding: EdgeInsets.all(spacing),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              size: iconSize,
            ),
            SizedBox(width: spacing),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: bodyFontSize,
                ),
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

  Widget _buildDeleteAccountButton(BuildContext context, bool isDark, WidgetRef ref) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final spacing = Responsive.verticalSpacing(context);
    final buttonHeight = Responsive.buttonHeight(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final iconSize = Responsive.iconSize(context);
    final borderRadius = Responsive.borderRadius(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: SizedBox(
        width: double.infinity,
        height: buttonHeight,
        child: OutlinedButton.icon(
          onPressed: () => _showDeleteAccountDialog(context, isDark, ref),
          icon: Icon(Icons.delete_forever, color: AppColors.error, size: iconSize),
          label: Text(
            'Delete Account',
            style: TextStyle(
              color: AppColors.error,
              fontSize: bodyFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.error, width: 1.5),
            padding: EdgeInsets.symmetric(vertical: spacing),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, bool isDark, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            const Text('Delete Account'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete your account?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              'This action is permanent and cannot be undone. All your data, including your profile, wallet, and activity history will be permanently deleted.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final authProvider = ref.read(authChangeNotifierProvider);
              await authProvider.deleteAccount();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, bool isDark, WidgetRef ref) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final spacing = Responsive.verticalSpacing(context);
    final buttonHeight = Responsive.buttonHeight(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final iconSize = Responsive.iconSize(context);
    final borderRadius = Responsive.borderRadius(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: SizedBox(
        width: double.infinity,
        height: buttonHeight,
        child: ElevatedButton.icon(
          onPressed: () async {
            final authProvider = ref.read(authChangeNotifierProvider);
            await authProvider.logout();
            if (context.mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
          icon: Icon(Icons.logout, color: Colors.white, size: iconSize),
          label: Text(
            'Log Out',
            style: TextStyle(
              color: Colors.white,
              fontSize: bodyFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGold,
            padding: EdgeInsets.symmetric(vertical: spacing),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyPolicyLink(BuildContext context, bool isDark) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final spacing = Responsive.verticalSpacing(context);
    final iconSize = Responsive.iconSize(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final borderRadius = Responsive.borderRadius(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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
          padding: EdgeInsets.all(spacing),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(borderRadius),
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
                size: iconSize,
              ),
              SizedBox(width: spacing),
              Expanded(
                child: Text(
                  'Privacy & Data Policy',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: bodyFontSize,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                size: iconSize * 0.67,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
