import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/mock_data.dart';
import '../../../domain/entities/transaction.dart';
import '../../widgets/custom_app_bar.dart';
import 'add_money_page.dart';
import 'give_page.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  String selectedCurrency = 'NGN';
  final currencies = ['NGN', 'USD', 'EUR', 'GBP'];
  final String walletNumber = '1234567890';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(title: '', showBackButton: false),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPortfolioCard(context, isDark),
              const SizedBox(height: 24),
              _buildCurrencySelector(isDark),
              const SizedBox(height: 24),
              _buildActionButtons(context, isDark),
              const SizedBox(height: 24),
              _buildTransactionsHistory(context, isDark),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortfolioCard(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1A1A2E),
            Color(0xFF16213E),
            Color(0xFF0F3460),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Portfolio',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              Text(
                '10th Dec, 2025',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Your Balance:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'N50,000',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencySelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
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
            'Your Wallet',
            style: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: currencies.map((currency) {
              final isSelected = currency == selectedCurrency;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedCurrency = currency;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.textPrimaryLight
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.textPrimaryLight
                            : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
                      ),
                    ),
                    child: Text(
                      currency,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Wallet Number: ',
                style: TextStyle(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  fontSize: 12,
                ),
              ),
              Text(
                walletNumber,
                style: TextStyle(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: walletNumber));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Wallet number copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Icon(
                  Icons.copy,
                  size: 18,
                  color: AppColors.primaryGold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            context,
            isDark,
            Icons.add,
            'Add Money',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddMoneyPage()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            context,
            isDark,
            Icons.volunteer_activism,
            'Give',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GivePage()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    bool isDark,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.primaryGold,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsHistory(BuildContext context, bool isDark) {
    final transactions = MockData.transactions;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transaction History',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'See All',
                    style: TextStyle(color: AppColors.primaryGold),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No transactions yet',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 72,
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              ),
              itemBuilder: (context, index) {
                final transaction = transactions[index];
                final isCredit = transaction.type == TransactionType.moneyIn;
                final dateStr = _formatDate(transaction.date);
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isCredit ? Colors.green : Colors.red)
                          .withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isCredit ? Colors.green : Colors.red,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    transaction.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  subtitle: Text(
                    dateStr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                  ),
                  trailing: Text(
                    '${isCredit ? '+' : '-'}N${transaction.amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isCredit ? Colors.green : Colors.red,
                        ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]}, ${date.year}';
  }
}
