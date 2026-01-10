import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../widgets/custom_app_bar.dart';

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

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
                  // Wallet icon with gradient background
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
                  
                  // Coming Soon text
                  Text(
                    'Coming Soon',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGold,
                      fontSize: titleFontSize,
                    ),
                  ),
                  SizedBox(height: spacing),
                  
                  // Description
                  Text(
                    'The TCGC Wallet feature is currently under development. Soon you\'ll be able to manage your tithes, offerings, and donations right from the app.',
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
                  
                  // Features coming
                  Container(
                    padding: EdgeInsets.all(horizontalPadding * 1.25),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : Colors.grey[100],
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Features Coming',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: Responsive.subtitleFontSize(context) * 0.85,
                          ),
                        ),
                        SizedBox(height: spacing),
                        _buildFeatureItem(context, isDark, Icons.volunteer_activism, 'Tithes & Offerings'),
                        _buildFeatureItem(context, isDark, Icons.card_giftcard, 'Special Donations'),
                        _buildFeatureItem(context, isDark, Icons.history, 'Transaction History'),
                        _buildFeatureItem(context, isDark, Icons.receipt_long, 'Digital Receipts'),
                      ],
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
