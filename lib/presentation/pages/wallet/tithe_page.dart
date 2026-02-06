import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/custom_app_bar.dart';
import 'success_page.dart';

class TithePage extends StatefulWidget {
  final String title;
  final int giveOptionId;

  const TithePage({super.key, required this.title, required this.giveOptionId});

  @override
  State<TithePage> createState() => _TithePageState();
}

class _TithePageState extends State<TithePage> {
  String amount = '1,000';
  bool _isProcessing = false;

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
    
    final walletProvider = context.read<WalletProvider>();
    
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
              
              final walletProvider = context.read<WalletProvider>();
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
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        title: const Text('Enter Transaction PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Amount: ₦$amount'),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'PIN',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (pinController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your PIN')),
                );
                return;
              }
              
              Navigator.pop(dialogContext);
              await _executePayment(amountValue, pinController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  Future<void> _executePayment(double amountValue, String pin) async {
    setState(() => _isProcessing = true);
    
    final walletProvider = context.read<WalletProvider>();
    final success = await walletProvider.give(widget.giveOptionId, amountValue, pin);
    
    setState(() => _isProcessing = false);
    
    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SuccessPage(
            title: widget.title,
            amount: amount,
          ),
        ),
      );
    } else if (mounted) {
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
    final walletProvider = context.watch<WalletProvider>();

    return Scaffold(
      appBar: CustomAppBar(title: widget.title),
      body: SafeArea(
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
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '₦$amount',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 40,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To',
                    style: TextStyle(
                      color: AppColors.primaryGold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The CityGate Apostolic\nKingdom Ministry',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Balance: ₦${walletProvider.balance.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            _buildNumpad(isDark),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Pay now',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNumKey('1', isDark),
              _buildNumKey('2', isDark),
              _buildNumKey('3', isDark),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNumKey('4', isDark),
              _buildNumKey('5', isDark),
              _buildNumKey('6', isDark),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNumKey('7', isDark),
              _buildNumKey('8', isDark),
              _buildNumKey('9', isDark),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 70),
              _buildNumKey('0', isDark),
              _buildBackspaceKey(isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumKey(String num, bool isDark) {
    return GestureDetector(
      onTap: () {
        setState(() {
          final cleanAmount = amount.replaceAll(',', '');
          final newAmount = cleanAmount + num;
          amount = _formatAmount(newAmount);
        });
      },
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.dividerLight.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            num,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey(bool isDark) {
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
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Icon(
            Icons.backspace_outlined,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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
