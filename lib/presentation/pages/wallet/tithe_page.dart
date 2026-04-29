import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/biometric_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';
import 'success_page.dart';
import 'transaction_processing_page.dart';

class TithePage extends ConsumerStatefulWidget {
  final String title;
  final int giveOptionId;

  const TithePage({super.key, required this.title, required this.giveOptionId});

  @override
  ConsumerState<TithePage> createState() => _TithePageState();
}

class _TithePageState extends ConsumerState<TithePage> {
  String amount = '1,000';

  /// Estimated 9PSB transaction fee (CBN NIP schedule)
  /// 9PSB deducts this silently — not reported in API response
  double _calculatePlatformFee(double amount) {
    if (amount <= 0) return 0;
    if (amount <= 5000) return 10;
    if (amount <= 50000) return 25;
    return 50;
  }

  Future<void> _processPayment() async {
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
    
    final walletProvider = ref.read(walletChangeNotifierProvider);
    final biometricProvider = ref.read(biometricChangeNotifierProvider);
    
    if (walletProvider.balance < amountValue) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Insufficient balance. Please add money to your wallet.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Enforce single transaction limit
    if (walletProvider.singleLimit > 0 && amountValue > walletProvider.singleLimit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Amount exceeds your Tier ${walletProvider.tier} limit of ₦${_fmtLimit(walletProvider.singleLimit)} per transaction. '
              'Please upgrade your wallet.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }
    
    // Check if biometric is enabled for transactions
    if (biometricProvider.biometricTransactionEnabled) {
      final authenticated = await biometricProvider.authenticateForTransaction();
      if (authenticated && mounted) {
        await _executePaymentWithBiometric(amountValue);
      } else if (mounted) {
        // Fall back to PIN if biometric fails
        _showPinDialog(amountValue);
      }
      return;
    }
    
    // Check if user has PIN set
    final hasPin = await walletProvider.checkHasPin();
    if (!hasPin && mounted) {
      _showSetPinDialog();
      return;
    }
    
    // Show PIN input dialog
    if (mounted) {
      _showPinDialog(amountValue);
    }
  }
  
  Future<void> _executePaymentWithBiometric(double amountValue) async {
    final walletProvider = ref.read(walletChangeNotifierProvider);
    final authProvider = ref.read(authChangeNotifierProvider);
    final currentAmount = amount;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionProcessingPage(
          title: widget.title,
          amount: currentAmount,
          processTransaction: () async {
            return await walletProvider.giveWithBiometric(widget.giveOptionId, amountValue);
          },
          getErrorMessage: () => walletProvider.error,
          successPage: SuccessPage(
            title: widget.title,
            amount: currentAmount,
            reference: walletProvider.transactions.isNotEmpty
                ? walletProvider.transactions.first.reference
                : null,
            donorName: authProvider.user?.fullName,
            accountNumber: walletProvider.accountNumber,
            accountName: walletProvider.accountName,
          ),
        ),
      ),
    );
    
    // If returned false, show error
    if (result == false && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(walletProvider.error ?? 'Failed to process payment'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _showSetPinDialog() {
    final pinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        title: const Text('Set Transaction PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('You need to set a transaction PIN before making payments.'),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Enter PIN (4-6 digits)',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm PIN',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (pinController.text.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN must be at least 4 digits')),
                );
                return;
              }
              if (pinController.text != confirmPinController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PINs do not match')),
                );
                return;
              }
              
              final walletProvider = ref.read(walletChangeNotifierProvider);
              final success = await walletProvider.setTransactionPin(
                pinController.text,
                confirmPinController.text,
              );
              
              if (success && mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN set successfully')),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(walletProvider.error ?? 'Failed to set PIN')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold),
            child: const Text('Set PIN', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  void _showPinDialog(double amountValue) {
    final pinController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final walletProvider = ref.read(walletChangeNotifierProvider);
    bool isProcessing = false;
    final fee = _calculatePlatformFee(amountValue);
    final total = amountValue + fee;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.cardDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.lock_outline, color: AppColors.primaryGold, size: 24),
              const SizedBox(width: 8),
              const Expanded(child: Text('Confirm Payment')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Transaction details
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.backgroundDark
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Transaction Details',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: AppColors.primaryGold,
                          )),
                      const SizedBox(height: 12),
                      _detailRow('From', walletProvider.accountName ?? 'Your Wallet', isDark),
                      const SizedBox(height: 8),
                      _detailRow('Account No.', walletProvider.accountNumber ?? 'N/A', isDark),
                      const SizedBox(height: 8),
                      _detailRow('Bank', '9 Payment Service Bank', isDark),
                      Divider(height: 20, color: isDark ? AppColors.dividerDark : AppColors.dividerLight),
                      _detailRow('To', 'The CityGate Apostolic Kingdom Ministry', isDark),
                      const SizedBox(height: 8),
                      _detailRow('Purpose', widget.title, isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Amount breakdown
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primaryGold.withOpacity(0.25)),
                  ),
                  child: Column(
                    children: [
                      _feeRow('Giving amount', '₦${_fmt(amountValue)}', isDark),
                      const SizedBox(height: 6),
                      _feeRow('Est. transaction fee (9PSB)', '~₦${_fmt(fee)}', isDark,
                          isSubtle: true),
                      Divider(height: 16, color: AppColors.primaryGold.withOpacity(0.3)),
                      _feeRow('Est. total deducted', '~₦${_fmt(total)}', isDark, isBold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // PIN field
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: true,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: '••••',
                    hintStyle: TextStyle(color: Colors.grey[400], letterSpacing: 8),
                    counterText: '',
                    labelText: 'Enter Transaction PIN',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryGold, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                  onSubmitted: (_) async {
                    if (pinController.text.isEmpty || isProcessing) return;
                    if (pinController.text.length < 4) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PIN must be at least 4 digits')),
                      );
                      return;
                    }
                    setDialogState(() => isProcessing = true);
                    Navigator.pop(dialogContext);
                    await _executePayment(amountValue, pinController.text);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(dialogContext),
              child: Text('Cancel',
                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: isProcessing
                  ? null
                  : () async {
                      if (pinController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter your PIN')),
                        );
                        return;
                      }
                      if (pinController.text.length < 4) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('PIN must be at least 4 digits')),
                        );
                        return;
                      }
                      setDialogState(() => isProcessing = true);
                      Navigator.pop(dialogContext);
                      await _executePayment(amountValue, pinController.text);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: isProcessing
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Pay Now', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              )),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              )),
        ),
      ],
    );
  }

  Widget _feeRow(String label, String value, bool isDark,
      {bool isSubtle = false, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: isSubtle ? 12 : 13,
              color: isSubtle
                  ? (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight)
                  : (isDark ? Colors.white : Colors.black87),
            )),
        Text(value,
            style: TextStyle(
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold
                  ? AppColors.primaryGold
                  : (isDark ? Colors.white : Colors.black87),
            )),
      ],
    );
  }

  String _fmt(double v) =>
      v.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String _fmtLimit(double v) =>
      v <= 0 ? 'Unlimited' : '${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  
  Future<void> _executePayment(double amountValue, String pin) async {
    final walletProvider = ref.read(walletChangeNotifierProvider);
    final authProvider = ref.read(authChangeNotifierProvider);
    final currentAmount = amount;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionProcessingPage(
          title: widget.title,
          amount: currentAmount,
          processTransaction: () async {
            return await walletProvider.give(widget.giveOptionId, amountValue, pin);
          },
          getErrorMessage: () => walletProvider.error,
          successPage: SuccessPage(
            title: widget.title,
            amount: currentAmount,
            reference: walletProvider.transactions.isNotEmpty
                ? walletProvider.transactions.first.reference
                : null,
            donorName: authProvider.user?.fullName,
            accountNumber: walletProvider.accountNumber,
            accountName: walletProvider.accountName,
          ),
        ),
      ),
    );
    
    // If returned false, show error
    if (result == false && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(walletProvider.error ?? 'Failed to process payment'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final walletProvider = ref.watch(walletChangeNotifierProvider);
    final spacing = Responsive.verticalSpacing(context);
    final horizontalPadding = Responsive.horizontalPadding(context);
    final maxWidth = Responsive.maxContentWidth(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final smallFontSize = Responsive.smallFontSize(context);
    final amountFontSize = Responsive.value(context, mobile: 40.0, tablet: 48.0, desktop: 56.0);
    final borderRadius = Responsive.borderRadius(context);
    final buttonHeight = Responsive.buttonHeight(context);

    return Scaffold(
      appBar: CustomAppBar(title: widget.title),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            color: AppColors.primaryGold,
                            fontSize: smallFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(height: spacing * 1.5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '₦',
                              style: TextStyle(
                                color: AppColors.primaryGold,
                                fontSize: amountFontSize * 0.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            amount,
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: amountFontSize,
                                  letterSpacing: -1,
                                ),
                          ),
                        ],
                      ),
                      SizedBox(height: spacing),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? AppColors.cardDark 
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'To',
                              style: TextStyle(
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                fontSize: smallFontSize * 0.9,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'The CityGate Apostolic Kingdom Ministry',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: bodyFontSize * 0.95,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: spacing),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: AppColors.primaryGold,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Balance: ₦${walletProvider.balance.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: AppColors.primaryGold,
                              fontSize: bodyFontSize * 0.9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Tier limits info
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.cardDark
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline,
                                size: 13,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight),
                            const SizedBox(width: 6),
                            Text(
                              'Tier ${walletProvider.tier} limit: ₦${_fmtLimit(walletProvider.singleLimit)} per transaction',
                              style: TextStyle(
                                fontSize: smallFontSize * 0.85,
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
                ),
                _buildNumpad(isDark),
                SizedBox(height: spacing * 1.25),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Container(
                    width: double.infinity,
                    height: buttonHeight + 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primaryGold, AppColors.goldVariant1],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(borderRadius + 4),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGold.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(borderRadius + 4),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            'Pay ₦$amount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: bodyFontSize,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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
    final spacing = Responsive.verticalSpacing(context) * 0.6;
    final keySize = Responsive.value(context, mobile: 72.0, tablet: 82.0, desktop: 92.0);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.wp(context, 6),
        vertical: spacing,
      ),
      margin: EdgeInsets.symmetric(horizontal: Responsive.wp(context, 4)),
      decoration: BoxDecoration(
        color: isDark 
            ? AppColors.cardDark.withOpacity(0.5) 
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
      ),
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
              _buildClearKey(isDark, keySize),
              _buildNumKey('0', isDark, keySize),
              _buildBackspaceKey(isDark, keySize),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumKey(String num, bool isDark, double keySize) {
    final fontSize = Responsive.value(context, mobile: 26.0, tablet: 30.0, desktop: 34.0);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            final cleanAmount = amount.replaceAll(',', '');
            final newAmount = cleanAmount + num;
            amount = _formatAmount(newAmount);
          });
        },
        borderRadius: BorderRadius.circular(keySize / 2),
        splashColor: AppColors.primaryGold.withOpacity(0.2),
        highlightColor: AppColors.primaryGold.withOpacity(0.1),
        child: Container(
          width: keySize,
          height: keySize,
          decoration: BoxDecoration(
            color: isDark 
                ? AppColors.surfaceDark 
                : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              num,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClearKey(bool isDark, double keySize) {
    final fontSize = Responsive.value(context, mobile: 14.0, tablet: 16.0, desktop: 18.0);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            amount = '0';
          });
        },
        borderRadius: BorderRadius.circular(keySize / 2),
        splashColor: AppColors.primaryGold.withOpacity(0.2),
        child: Container(
          width: keySize,
          height: keySize,
          decoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              'Clear',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryGold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey(bool isDark, double keySize) {
    final iconSize = Responsive.iconSize(context);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            final cleanAmount = amount.replaceAll(',', '');
            if (cleanAmount.isNotEmpty) {
              final newAmount = cleanAmount.substring(0, cleanAmount.length - 1);
              amount = newAmount.isEmpty ? '0' : _formatAmount(newAmount);
            }
          });
        },
        onLongPress: () {
          setState(() {
            amount = '0';
          });
        },
        borderRadius: BorderRadius.circular(keySize / 2),
        splashColor: Colors.red.withOpacity(0.2),
        child: Container(
          width: keySize,
          height: keySize,
          decoration: const BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.backspace_outlined,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              size: iconSize,
            ),
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
