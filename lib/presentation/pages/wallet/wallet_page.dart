import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../widgets/custom_app_bar.dart';
import 'give_page.dart';
import 'nin_verification_page.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  bool _isCheckingStatus = true;

  @override
  void initState() {
    super.initState();
    _checkWalletStatus();
  }

  Future<void> _checkWalletStatus() async {
    // Small delay to ensure provider is ready
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (mounted) {
      setState(() => _isCheckingStatus = false);
    }
  }

  void _navigateToCreateWallet() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NinVerificationPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingStatus) {
      return Scaffold(
        appBar: const CustomAppBar(title: '', showBackButton: false),
        body: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryGold,
          ),
        ),
      );
    }

    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        // If user has wallet, go to GivePage (wallet details)
        if (walletProvider.hasWallet) {
          return const GivePage();
        }
        
        // If user doesn't have wallet, show welcome page
        return _buildWalletWelcomePage(context);
      },
    );
  }

  Widget _buildWalletWelcomePage(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = Responsive.horizontalPadding(context);
    final spacing = Responsive.verticalSpacing(context);
    final maxWidth = Responsive.maxContentWidth(context);
    final titleFontSize = Responsive.titleFontSize(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final borderRadius = Responsive.borderRadius(context);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Wallet', showBackButton: false),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.all(horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: spacing * 3),
                  
                  // Wallet Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryGold.withOpacity(0.2),
                          AppColors.primaryGold.withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 60,
                      color: AppColors.primaryGold,
                    ),
                  ),
                  SizedBox(height: spacing * 2),

                  // Title
                  Text(
                    'TCGC Wallet',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGold,
                      fontSize: titleFontSize,
                    ),
                  ),
                  SizedBox(height: spacing),

                  // Description
                  Text(
                    'Create your digital wallet to give offerings, tithes, and manage all your giving conveniently.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      height: 1.5,
                      fontSize: bodyFontSize,
                    ),
                  ),
                  SizedBox(height: spacing * 3),

                  // Features List
                  _buildFeatureItem(
                    context,
                    isDark,
                    Icons.security_outlined,
                    'Secure Transactions',
                    'Powered by 9PSB with bank-level security',
                  ),
                  SizedBox(height: spacing),
                  _buildFeatureItem(
                    context,
                    isDark,
                    Icons.volunteer_activism_outlined,
                    'Easy Giving',
                    'Give tithes, offerings, and donations seamlessly',
                  ),
                  SizedBox(height: spacing),
                  _buildFeatureItem(
                    context,
                    isDark,
                    Icons.history_outlined,
                    'Transaction History',
                    'Track all your giving and transactions',
                  ),
                  SizedBox(height: spacing * 4),

                  // Create Wallet Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _navigateToCreateWallet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGold,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Create Wallet',
                        style: TextStyle(
                          fontSize: bodyFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: spacing * 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    bool isDark,
    IconData icon,
    String title,
    String description,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryGold,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
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
