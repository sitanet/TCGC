import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../widgets/custom_app_bar.dart';
import 'success_page.dart';

class AddMoneyPage extends StatefulWidget {
  const AddMoneyPage({super.key});

  @override
  State<AddMoneyPage> createState() => _AddMoneyPageState();
}

class _AddMoneyPageState extends State<AddMoneyPage> {
  String amount = '1,000';
  bool _isProcessing = false;

  Future<void> _addMoney() async {
    final cleanAmount = amount.replaceAll(',', '');
    final amountValue = double.tryParse(cleanAmount) ?? 0;
    
    if (amountValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    
    final walletProvider = context.read<WalletProvider>();
    final success = await walletProvider.addMoney(amountValue);
    
    setState(() => _isProcessing = false);
    
    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SuccessPage(
            title: 'Add Money',
            amount: amount,
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(walletProvider.error ?? 'Failed to add money'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final walletProvider = context.watch<WalletProvider>();
    final spacing = Responsive.verticalSpacing(context);
    final horizontalPadding = Responsive.horizontalPadding(context);
    final maxWidth = Responsive.maxContentWidth(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final smallFontSize = Responsive.smallFontSize(context);
    final amountFontSize = Responsive.value(context, mobile: 40.0, tablet: 48.0, desktop: 56.0);
    final borderRadius = Responsive.borderRadius(context);
    final buttonHeight = Responsive.buttonHeight(context);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Add Money'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Enter Amount',
                        style: TextStyle(
                          color: AppColors.primaryGold,
                          fontSize: bodyFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: spacing),
                      Text(
                        '₦$amount',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: amountFontSize,
                            ),
                      ),
                      SizedBox(height: spacing * 0.5),
                      Text(
                        'To',
                        style: TextStyle(
                          color: AppColors.primaryGold,
                          fontSize: smallFontSize,
                        ),
                      ),
                      SizedBox(height: spacing * 0.5),
                      Text(
                        'Your Wallet',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: bodyFontSize,
                            ),
                      ),
                      SizedBox(height: spacing),
                      Text(
                        'Current Balance: ₦${walletProvider.balance.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          fontSize: bodyFontSize,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildNumpad(isDark),
                SizedBox(height: spacing * 1.25),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: SizedBox(
                    width: double.infinity,
                    height: buttonHeight,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _addMoney,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGold,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                      ),
                      child: _isProcessing
                          ? SizedBox(
                              width: Responsive.iconSize(context),
                              height: Responsive.iconSize(context),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Add Money',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: bodyFontSize,
                                fontWeight: FontWeight.w600,
                              ),
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
    );
  }

  Widget _buildNumpad(bool isDark) {
    final spacing = Responsive.verticalSpacing(context);
    final keySize = Responsive.value(context, mobile: 70.0, tablet: 80.0, desktop: 90.0);
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.wp(context, 10)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNumKey('1', isDark, keySize),
              _buildNumKey('2', isDark, keySize),
              _buildNumKey('3', isDark, keySize),
            ],
          ),
          SizedBox(height: spacing),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNumKey('4', isDark, keySize),
              _buildNumKey('5', isDark, keySize),
              _buildNumKey('6', isDark, keySize),
            ],
          ),
          SizedBox(height: spacing),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNumKey('7', isDark, keySize),
              _buildNumKey('8', isDark, keySize),
              _buildNumKey('9', isDark, keySize),
            ],
          ),
          SizedBox(height: spacing),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(width: keySize),
              _buildNumKey('0', isDark, keySize),
              _buildBackspaceKey(isDark, keySize),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumKey(String num, bool isDark, double keySize) {
    final fontSize = Responsive.value(context, mobile: 24.0, tablet: 28.0, desktop: 32.0);
    final borderRadius = Responsive.borderRadius(context);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          final cleanAmount = amount.replaceAll(',', '');
          final newAmount = cleanAmount + num;
          amount = _formatAmount(newAmount);
        });
      },
      child: Container(
        width: keySize,
        height: keySize,
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.dividerLight.withOpacity(0.5),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Center(
          child: Text(
            num,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey(bool isDark, double keySize) {
    final borderRadius = Responsive.borderRadius(context);
    final iconSize = Responsive.iconSize(context);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          final cleanAmount = amount.replaceAll(',', '');
          if (cleanAmount.isNotEmpty) {
            final newAmount = cleanAmount.substring(0, cleanAmount.length - 1);
            amount = newAmount.isEmpty ? '0' : _formatAmount(newAmount);
          }
        });
      },
      child: Container(
        width: keySize,
        height: keySize,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Center(
          child: Icon(
            Icons.backspace_outlined,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            size: iconSize,
          ),
        ),
      ),
    );
  }

  String _formatAmount(String amount) {
    if (amount.isEmpty) return '0';
    final number = int.tryParse(amount) ?? 0;
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
