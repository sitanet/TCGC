import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../main.dart';
import '../../widgets/password_input_field.dart';
import '../legal/privacy_policy_page.dart';
import '../support/complaint_page.dart';
import 'edit_profile_page.dart';
import 'settings_page.dart';
import '../wallet/wallet_page.dart';
import '../audio/favorites_page.dart';
import '../audio/downloads_page.dart';
import '../audio/playlists_page.dart';
import '../../../data/services/favorites_service.dart';
import '../../../data/services/download_service.dart';
import '../../../data/services/playlist_service.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final FavoritesService _favoritesService = FavoritesService();
  final DownloadService _downloadService = DownloadService();
  final PlaylistService _playlistService = PlaylistService();

  @override
  void initState() {
    super.initState();
    _favoritesService.initialize();
    _downloadService.initialize();
    _playlistService.initialize();
  }

  Future<void> _authenticateAndNavigateToEditProfile(
    BuildContext context,
    bool isDark,
  ) async {
    final biometricProvider = ref.read(biometricChangeNotifierProvider);
    await biometricProvider.initialize();

    // Try biometric first if enabled
    if (biometricProvider.biometricLoginEnabled &&
        biometricProvider.isAvailable) {
      final authenticated = await biometricProvider.authenticate(
        reason: 'Authenticate to edit your profile',
      );
      if (authenticated && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EditProfilePage()),
        );
        return;
      }
    }

    // Fall back to password
    if (context.mounted) {
      _showPasswordDialog(context, isDark);
    }
  }

  void _showPasswordDialog(BuildContext context, bool isDark) {
    final passwordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.cardDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Verify Identity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter your password to edit your profile:'),
              const SizedBox(height: 16),
              PasswordInputField(
                controller: passwordController,
                labelText: 'Password',
                autofocus: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (passwordController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter your password'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isLoading = true);

                      final authProvider = ref.read(authChangeNotifierProvider);
                      final isValid = await authProvider.verifyPassword(
                        passwordController.text,
                      );

                      setDialogState(() => isLoading = false);

                      if (isValid && dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EditProfilePage(),
                          ),
                        );
                      } else if (dialogContext.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              authProvider.error ?? 'Invalid password',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
                  : const Text('Verify', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = ref.watch(authChangeNotifierProvider);
    final appConfig = ref.watch(appConfigChangeNotifierProvider);
    final showWallet = !appConfig.config.walletPageDisabled;
    final spacing = Responsive.verticalSpacing(context);
    final horizontalPadding = Responsive.horizontalPadding(context);
    final isTablet = Responsive.isTablet(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                // 1. Premium Profile Header
                _buildProfileHeader(context, isDark, isTablet),
                SizedBox(height: spacing),

                // 2. Personal Library Stats Bar (Favorites, Downloads, Playlists)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: _buildStatsStrip(context, isDark, isTablet),
                ),
                SizedBox(height: spacing * 1.2),

                // 3. Grouped Settings Sections
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    children: [
                      // Section A: Account & Security
                      _buildSectionCard(
                        context,
                        isDark: isDark,
                        title: 'ACCOUNT & SECURITY',
                        items: [
                          _MenuItemConfig(
                            icon: Icons.person_outline_rounded,
                            title: 'Edit Profile',
                            subtitle: 'Name, email, and personal information',
                            onTap: () => _authenticateAndNavigateToEditProfile(context, isDark),
                          ),
                          if (showWallet)
                            _MenuItemConfig(
                              icon: Icons.account_balance_wallet_outlined,
                              title: 'TCGC Wallet',
                              subtitle: 'Transactions and payment options',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const WalletPage()),
                                );
                              },
                            ),
                          _MenuItemConfig(
                            icon: Icons.security_rounded,
                            title: 'Password & Biometrics',
                            subtitle: 'Face ID, fingerprint, and login security',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SettingsPage()),
                              );
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: spacing),

                      // Section B: App Preferences
                      _buildSectionCard(
                        context,
                        isDark: isDark,
                        title: 'PREFERENCES',
                        items: [
                          _MenuItemConfig(
                            icon: Icons.palette_outlined,
                            title: 'Appearance',
                            subtitle: isDark ? 'Dark Mode active' : 'Light Mode active',
                            trailing: _buildThemeToggle(context),
                          ),
                          _MenuItemConfig(
                            icon: Icons.notifications_none_rounded,
                            title: 'Notifications & Audio',
                            subtitle: 'Sermon alerts, streaming quality',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SettingsPage()),
                              );
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: spacing),

                      // Section C: Church Support & Legal
                      _buildSectionCard(
                        context,
                        isDark: isDark,
                        title: 'SUPPORT & LEGAL',
                        items: [
                          _MenuItemConfig(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'Chat with Us',
                            subtitle: 'Pastoral assistance and inquiries',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ComplaintPage()),
                              );
                            },
                          ),
                          _MenuItemConfig(
                            icon: Icons.privacy_tip_outlined,
                            title: 'Privacy & NDPA Policy',
                            subtitle: 'Data protection and terms of service',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                              );
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: spacing * 1.5),

                      // Section D: Account Actions (Logout & Delete)
                      if (authProvider.isAuthenticated) ...[
                        _buildLogoutButton(context, isDark),
                        SizedBox(height: spacing * 0.8),
                        _buildDeleteAccountButton(context, isDark),
                      ],
                    ],
                  ),
                ),

                SizedBox(height: spacing * 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 1. Profile Header ─────────────────────────────────────────────
  Widget _buildProfileHeader(BuildContext context, bool isDark, bool isTablet) {
    final authProvider = ref.watch(authChangeNotifierProvider);
    final user = authProvider.user;
    final displayName = user != null && user.fullName.trim().isNotEmpty
        ? user.fullName
        : (user?.email ?? 'Beloved Member');
    final email = user?.email ?? '';
    final role = user != null && user.role.isNotEmpty
        ? user.role.toUpperCase()
        : 'TCGC MEMBER';
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final avatarRadius = isTablet ? 56.0 : 46.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1A1F2C),
                  const Color(0xFF11141C),
                ]
              : [
                  const Color(0xFF1E232F),
                  const Color(0xFF0F131D),
                ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(height: statusBarHeight + 6),

          // Top Nav Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (Navigator.canPop(context))
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  )
                else
                  const SizedBox(width: 40),
                const Text(
                  'My Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                _buildThemeToggle(context),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Avatar with Gold Accent Ring & Edit Badge
          GestureDetector(
            onTap: () => _authenticateAndNavigateToEditProfile(context, isDark),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryGold, Color(0xFFE5A93C), Colors.amber],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGold.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor: isDark ? AppColors.cardDark : Colors.grey[200],
                    backgroundImage: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                        ? NetworkImage(user.photoUrl!)
                        : null,
                    child: user?.photoUrl == null || user!.photoUrl!.isEmpty
                        ? Icon(Icons.person, size: avatarRadius * 1.1, color: AppColors.primaryGold)
                        : null,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.edit_rounded, size: 13, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // User Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              displayName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: isTablet ? 22 : 19,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              email,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Member Badge Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primaryGold.withValues(alpha: 0.5),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_rounded, size: 14, color: AppColors.primaryGold),
                const SizedBox(width: 5),
                Text(
                  role,
                  style: const TextStyle(
                    color: AppColors.primaryGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── 2. Personal Library Stats Strip ──────────────────────────────
  Widget _buildStatsStrip(BuildContext context, bool isDark, bool isTablet) {
    return ListenableBuilder(
      listenable: Listenable.merge([_favoritesService, _downloadService, _playlistService]),
      builder: (context, _) {
        final favoritesCount = _favoritesService.count;
        final downloadsCount = _downloadService.count;
        final playlistsCount = _playlistService.playlists.length;

        return Row(
          children: [
            Expanded(
              child: _buildStatItem(
                context,
                isDark: isDark,
                icon: Icons.favorite_rounded,
                iconColor: Colors.redAccent,
                count: favoritesCount,
                label: 'Favorites',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FavoritesPage()),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatItem(
                context,
                isDark: isDark,
                icon: Icons.download_done_rounded,
                iconColor: AppColors.primaryGold,
                count: downloadsCount,
                label: 'Downloads',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DownloadsPage()),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatItem(
                context,
                isDark: isDark,
                icon: Icons.playlist_play_rounded,
                iconColor: Colors.blueAccent,
                count: playlistsCount,
                label: 'Playlists',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PlaylistsPage()),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required int count,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
              width: 0.9,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(height: 7),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 3. Grouped Settings Section Card ─────────────────────────────
  Widget _buildSectionCard(
    BuildContext context, {
    required bool isDark,
    required String title,
    required List<_MenuItemConfig> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isDark ? AppColors.textSecondaryDark : Colors.grey.shade600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
              width: 0.9,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 0.8,
                indent: 52,
                color: isDark ? AppColors.dividerDark : Colors.grey.shade100,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  onTap: item.onTap,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withValues(alpha: isDark ? 0.16 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item.icon,
                      size: 20,
                      color: AppColors.primaryGold,
                    ),
                  ),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                  subtitle: item.subtitle != null
                      ? Text(
                          item.subtitle!,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        )
                      : null,
                  trailing: item.trailing ??
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                      ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── 4. Theme Toggle Segmented Control ─────────────────────────────
  Widget _buildThemeToggle(BuildContext context) {
    final themeProvider = ref.watch(themeChangeNotifierProvider);
    final isDark = themeProvider.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => themeProvider.setThemeMode(ThemeMode.light),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: !isDark ? Colors.white : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.light_mode_rounded,
                color: !isDark ? const Color(0xFF1E232F) : Colors.white70,
                size: 15,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.primaryGold : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.dark_mode_rounded,
                color: isDark ? Colors.white : Colors.white70,
                size: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 5. Logout & Delete Account Actions ─────────────────────────────
  Widget _buildLogoutButton(BuildContext context, bool isDark) {
    final bodyFontSize = Responsive.bodyFontSize(context);

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () async {
          final authProvider = ref.read(authChangeNotifierProvider);
          final walletProvider = ref.read(walletChangeNotifierProvider);
          final biometricProvider = ref.read(biometricChangeNotifierProvider);

          await authProvider.logout();
          walletProvider.reset();
          await biometricProvider.clearOnLogout();

          if (context.mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        },
        icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
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
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton(BuildContext context, bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: TextButton.icon(
        onPressed: () => _showDeleteAccountDialog(context, isDark),
        icon: const Icon(
          Icons.delete_forever_rounded,
          color: AppColors.error,
          size: 18,
        ),
        label: const Text(
          'Delete Account',
          style: TextStyle(
            color: AppColors.error,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Delete Account'),
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
              'This action is permanent and cannot be undone. All your data, wallet balance, and activity history will be deleted.',
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

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingContext) => AlertDialog(
                  backgroundColor: isDark ? AppColors.cardDark : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  content: const Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.error,
                        ),
                      ),
                      SizedBox(width: 20),
                      Text('Deleting account...'),
                    ],
                  ),
                ),
              );

              final authProvider = ref.read(authChangeNotifierProvider);
              final walletProvider = ref.read(walletChangeNotifierProvider);
              final biometricProvider = ref.read(biometricChangeNotifierProvider);

              final success = await authProvider.deleteAccount();

              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pop();
              }

              if (success) {
                walletProvider.reset();
                await biometricProvider.clearOnLogout();
                ref.read(mainTabIndexProvider.notifier).state = 0;

                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Your account has been deleted permanently.'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        authProvider.error ?? 'Failed to delete account. Please try again.',
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _MenuItemConfig {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  _MenuItemConfig({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
}
