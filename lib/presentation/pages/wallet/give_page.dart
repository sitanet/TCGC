import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/custom_app_bar.dart';
import 'tithe_page.dart';
import 'transactions_page.dart';
import 'add_money_page.dart';

class GivePage extends StatefulWidget {
  const GivePage({super.key});

  @override
  State<GivePage> createState() => _GivePageState();
}

class _GivePageState extends State<GivePage> {
  String selectedCurrency = 'NGN';
  final currencies = ['NGN', 'USD', 'EUR', 'GBP'];
  bool isGiveExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<WalletProvider>();
      provider.fetchTransactions();
      provider.fetchGivings();
    });
  }

  String _formatCurrency(double amount, String currency) {
    final symbols = {'NGN': '₦', 'USD': '\$', 'EUR': '€', 'GBP': '£'};
    final formatted = amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '${symbols[currency] ?? currency}$formatted';
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(title: ''),
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, child) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPortfolioCard(context, isDark, walletProvider),
                  const SizedBox(height: 24),
                  _buildCurrencySelector(isDark),
                  const SizedBox(height: 24),
                  _buildGiveSection(context, isDark, walletProvider),
                  const SizedBox(height: 16),
                  _buildTransactionsItem(context, isDark),
                  const SizedBox(height: 16),
                  _buildAddMoneyItem(context, isDark),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPortfolioCard(BuildContext context, bool isDark, WalletProvider walletProvider) {
    final now = DateTime.now();
    
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
                _formatDate(now),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
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
          Text(
            _formatCurrency(walletProvider.balance, walletProvider.currency),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (walletProvider.accountNumber != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.account_balance,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    walletProvider.accountNumber!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: walletProvider.accountNumber!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Account number copied to clipboard'),
                          backgroundColor: AppColors.success,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.copy,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
        ],
      ),
    );
  }

  Widget _buildGiveSection(BuildContext context, bool isDark, WalletProvider walletProvider) {
    final giveOptions = walletProvider.giveOptions;

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
        children: [
          InkWell(
            onTap: () {
              setState(() {
                isGiveExpanded = !isGiveExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.monetization_on_outlined,
                    color: AppColors.primaryGold,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Give',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Icon(
                    isGiveExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ],
              ),
            ),
          ),
          if (isGiveExpanded)
            ...giveOptions.map((option) => InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TithePage(
                          title: option.name,
                          giveOptionId: option.id,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            option.name,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildTransactionsItem(BuildContext context, bool isDark) {
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
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TransactionsPage()),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.swap_horiz,
                color: AppColors.primaryGold,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Transactions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddMoneyItem(BuildContext context, bool isDark) {
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
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddMoneyPage()),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.add_circle_outline,
                color: AppColors.primaryGold,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Add Money',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
