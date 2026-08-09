import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/error_handler.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';

class FundWalletPage extends ConsumerWidget {
  const FundWalletPage({super.key});

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ErrorHandler.showSuccess(context, '$label copied to clipboard');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final walletProvider = ref.watch(walletChangeNotifierProvider);
    final spacing = Responsive.verticalSpacing(context);
    final horizontalPadding = Responsive.horizontalPadding(context);
    final maxWidth = Responsive.maxContentWidth(context);
    final borderRadius = Responsive.borderRadius(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final smallFontSize = Responsive.smallFontSize(context);
    final titleFontSize = Responsive.titleFontSize(context);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Fund Wallet'),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.all(horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: spacing),
                  
                  // Info Card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(spacing),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(borderRadius),
                      border: Border.all(
                        color: AppColors.primaryGold.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.primaryGold,
                          size: Responsive.iconSize(context),
                        ),
                        SizedBox(width: spacing * 0.75),
                        Expanded(
                          child: Text(
                            'Transfer money to your wallet using the account details below',
                            style: TextStyle(
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              fontSize: smallFontSize,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing * 2),

                  // Wallet Details Card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(spacing * 1.5),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wallet Details',
                          style: TextStyle(
                            fontSize: titleFontSize * 0.9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGold,
                          ),
                        ),
                        SizedBox(height: spacing * 1.5),

                        // Bank Name
                        _buildDetailRow(
                          context,
                          isDark,
                          'Bank Name',
                          '9 Payment Service Bank (9PSB)',
                          Icons.account_balance,
                          onCopy: () => _copyToClipboard(context, '9 Payment Service Bank', 'Bank name'),
                        ),
                        SizedBox(height: spacing),

                        // Account Number
                        _buildDetailRow(
                          context,
                          isDark,
                          'Account Number',
                          walletProvider.accountNumber ?? 'N/A',
                          Icons.numbers,
                          onCopy: walletProvider.accountNumber != null
                              ? () => _copyToClipboard(context, walletProvider.accountNumber!, 'Account number')
                              : null,
                          isHighlighted: true,
                        ),
                        SizedBox(height: spacing),

                        // Account Name
                        _buildDetailRow(
                          context,
                          isDark,
                          'Account Name',
                          walletProvider.accountName ?? 'N/A',
                          Icons.person,
                          onCopy: walletProvider.accountName != null
                              ? () => _copyToClipboard(context, walletProvider.accountName!, 'Account name')
                              : null,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing * 2),

                  // Copy All Button
                  SizedBox(
                    width: double.infinity,
                    height: Responsive.buttonHeight(context),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final details = '''
Bank: 9 Payment Service Bank (9PSB)
Account Number: ${walletProvider.accountNumber ?? 'N/A'}
Account Name: ${walletProvider.accountName ?? 'N/A'}
''';
                        _copyToClipboard(context, details, 'Wallet details');
                      },
                      icon: const Icon(Icons.copy_all, color: Colors.white),
                      label: Text(
                        'Copy All Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: bodyFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGold,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: spacing * 2),

                  // Instructions
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(spacing),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : Colors.grey[100],
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How to Fund Your Wallet',
                          style: TextStyle(
                            fontSize: bodyFontSize,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                        SizedBox(height: spacing),
                        _buildInstructionStep(context, isDark, '1', 'Copy the account number above'),
                        SizedBox(height: spacing * 0.5),
                        _buildInstructionStep(context, isDark, '2', 'Open your bank app or USSD'),
                        SizedBox(height: spacing * 0.5),
                        _buildInstructionStep(context, isDark, '3', 'Transfer any amount to the account'),
                        SizedBox(height: spacing * 0.5),
                        _buildInstructionStep(context, isDark, '4', 'Your wallet will be credited instantly'),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing * 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    bool isDark,
    String label,
    String value,
    IconData icon, {
    VoidCallback? onCopy,
    bool isHighlighted = false,
  }) {
    final spacing = Responsive.verticalSpacing(context);
    final borderRadius = Responsive.borderRadius(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final smallFontSize = Responsive.smallFontSize(context);

    return Container(
      padding: EdgeInsets.all(spacing),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppColors.primaryGold.withOpacity(0.1)
            : (isDark ? AppColors.backgroundDark : Colors.grey[50]),
        borderRadius: BorderRadius.circular(borderRadius * 0.75),
        border: isHighlighted
            ? Border.all(color: AppColors.primaryGold.withOpacity(0.3))
            : null,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.primaryGold,
            size: Responsive.iconSize(context) * 0.9,
          ),
          SizedBox(width: spacing * 0.75),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: smallFontSize,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                SizedBox(height: spacing * 0.25),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isHighlighted ? bodyFontSize * 1.1 : bodyFontSize,
                    fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    letterSpacing: isHighlighted ? 1.5 : 0,
                  ),
                  softWrap: true,
                ),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              onPressed: onCopy,
              icon: Icon(
                Icons.copy,
                color: AppColors.primaryGold,
                size: Responsive.iconSize(context) * 0.8,
              ),
              tooltip: 'Copy',
            ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(BuildContext context, bool isDark, String step, String text) {
    final smallFontSize = Responsive.smallFontSize(context);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primaryGold,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: smallFontSize,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ),
      ],
    );
  }
}
