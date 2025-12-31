import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/custom_app_bar.dart';
import 'success_page.dart';

class SendMoneyPage extends StatefulWidget {
  const SendMoneyPage({super.key});

  @override
  State<SendMoneyPage> createState() => _SendMoneyPageState();
}

class _SendMoneyPageState extends State<SendMoneyPage> {
  String amount = '1,000';
  final TextEditingController _recipientController = TextEditingController();

  @override
  void dispose() {
    _recipientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Send Money'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: _recipientController,
                        decoration: InputDecoration(
                          hintText: 'Enter recipient email or phone',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primaryGold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
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
                      'N$amount',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 40,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            _buildNumpad(isDark),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SuccessPage(
                          title: 'Send Money',
                          amount: amount,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Send',
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
