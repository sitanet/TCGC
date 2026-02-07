import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../widgets/custom_app_bar.dart';
import 'give_page.dart';

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        if (walletProvider.hasWallet) {
          return const GivePage();
        }
        return const _CreateWalletView();
      },
    );
  }
}

class _CreateWalletView extends StatelessWidget {
  const _CreateWalletView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = Responsive.horizontalPadding(context);
    final spacing = Responsive.verticalSpacing(context);
    final maxWidth = Responsive.maxContentWidth(context);
    final titleFontSize = Responsive.titleFontSize(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final iconContainerSize = Responsive.value(context, mobile: 120.0, tablet: 150.0, desktop: 180.0);
    final iconSize = iconContainerSize * 0.5;
    final borderRadius = Responsive.borderRadius(context);
    final walletProvider = context.watch<WalletProvider>();

    return Scaffold(
      appBar: const CustomAppBar(title: '', showBackButton: false),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.all(horizontalPadding * 2.5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: spacing * 2.5),
                  Container(
                    width: iconContainerSize,
                    height: iconContainerSize,
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
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      size: iconSize,
                      color: AppColors.primaryGold,
                    ),
                  ),
                  SizedBox(height: spacing * 2),
                  
                  Text(
                    'TCGC Wallet',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGold,
                      fontSize: titleFontSize,
                    ),
                  ),
                  SizedBox(height: spacing),
                  
                  Text(
                    'Create your TCGC Wallet to start giving. You\'ll be able to pay Tithes, Offerings, support projects, and more.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isDark 
                          ? AppColors.textSecondaryDark 
                          : AppColors.textSecondaryLight,
                      height: 1.6,
                      fontSize: bodyFontSize,
                    ),
                  ),
                  SizedBox(height: spacing * 2.5),
                  
                  Container(
                    padding: EdgeInsets.all(horizontalPadding * 1.25),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : Colors.grey[100],
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'What You Can Do',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: Responsive.subtitleFontSize(context) * 0.85,
                          ),
                        ),
                        SizedBox(height: spacing),
                        _buildFeatureItem(context, isDark, Icons.volunteer_activism, 'Offering'),
                        _buildFeatureItem(context, isDark, Icons.church, 'Tithe'),
                        _buildFeatureItem(context, isDark, Icons.landscape, 'Project: Baba\'s Land'),
                        _buildFeatureItem(context, isDark, Icons.account_tree, 'Branches'),
                        _buildFeatureItem(context, isDark, Icons.card_giftcard, 'Special Offering'),
                        _buildFeatureItem(context, isDark, Icons.people, 'Giving to Ministers'),
                        _buildFeatureItem(context, isDark, Icons.stars, 'IMGC'),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing * 3),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: walletProvider.isLoading 
                          ? null 
                          : () => _createWallet(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGold,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                        elevation: 2,
                      ),
                      child: walletProvider.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Create Wallet',
                              style: TextStyle(
                                fontSize: bodyFontSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: spacing * 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createWallet(BuildContext context) async {
    final walletProvider = context.read<WalletProvider>();
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    
    // Check if user has required fields
    if (user?.dateOfBirth == null || user?.phoneNumber == null || user?.address == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please update your profile with date of birth, phone number, and address before creating a wallet.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }
    
    // Check if user has NIN or BVN
    if (user?.nin == null && user?.bvn == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide your NIN or BVN in your profile to create a wallet.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }
    
    // Pass user data to wallet creation
    final userData = {
      'phone_number': user!.phoneNumber,
      'date_of_birth': user.dateOfBirth?.toIso8601String().split('T').first, // Format as YYYY-MM-DD
      'address': user.address,
      'gender': user.gender,
      'nin': user.nin,
      'bvn': user.bvn,
    };
    
    final success = await walletProvider.openWallet(userData);
    
    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wallet created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(walletProvider.error ?? 'Failed to create wallet'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildFeatureItem(BuildContext context, bool isDark, IconData icon, String text) {
    final spacing = Responsive.verticalSpacing(context);
    final iconSize = Responsive.iconSize(context);
    final bodyFontSize = Responsive.bodyFontSize(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing * 0.5),
      child: Row(
        children: [
          Icon(
            icon,
            size: iconSize * 0.83,
            color: AppColors.primaryGold,
          ),
          SizedBox(width: spacing * 0.75),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark 
                  ? AppColors.textSecondaryDark 
                  : AppColors.textSecondaryLight,
              fontSize: bodyFontSize,
            ),
          ),
        ],
      ),
    );
  }
}
