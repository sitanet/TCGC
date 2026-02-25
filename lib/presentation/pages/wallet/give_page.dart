import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';
import 'tithe_page.dart';
import 'transactions_page.dart';
import 'fund_wallet_page.dart';

class GivePage extends ConsumerStatefulWidget {
  const GivePage({super.key});

  @override
  ConsumerState<GivePage> createState() => _GivePageState();
}

class _GivePageState extends ConsumerState<GivePage> {
  String selectedCurrency = 'NGN';
  final currencies = ['NGN', 'USD', 'EUR', 'GBP'];
  bool isGiveExpanded = false;
  bool isTransactionsExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = ref.read(walletChangeNotifierProvider);
      provider.fetchTransactions();
      provider.fetchGivings();
    });
  }

  String _formatCurrency(double amount, String currency) {
    final symbols = {'NGN': 'N', 'USD': '\$', 'EUR': '€', 'GBP': '£'};
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '${symbols[currency] ?? currency}$formatted';
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    String daySuffix(int day) {
      if (day >= 11 && day <= 13) return 'th';
      switch (day % 10) {
        case 1: return 'st';
        case 2: return 'nd';
        case 3: return 'rd';
        default: return 'th';
      }
    }
    return '${date.day}${daySuffix(date.day)} ${months[date.month - 1]}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = Responsive.horizontalPadding(context);
    final spacing = Responsive.verticalSpacing(context);
    final maxWidth = Responsive.maxContentWidth(context);

    final walletProvider = ref.watch(walletChangeNotifierProvider);
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFFAFAFA),
      appBar: const CustomAppBar(title: '', showBackButton: true),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: spacing),
                  _buildPortfolioCard(context, isDark, walletProvider),
                  SizedBox(height: spacing * 1.5),
                  _buildCurrencySelector(isDark),
                  SizedBox(height: spacing * 1.5),
                  _buildMenuItems(context, isDark, walletProvider),
                  SizedBox(height: spacing * 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortfolioCard(BuildContext context, bool isDark, WalletProvider walletProvider) {
    final now = DateTime.now();
    
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Dark background with gradient
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF1A1A2E),
                      Color(0xFF0F0F1A),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // Red/maroon accent glow
            Positioned(
              right: 20,
              top: 20,
              child: Container(
                width: 120,
                height: 80,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF8B0000).withValues(alpha: 0.6),
                      const Color(0xFF8B0000).withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Gold accent line
            Positioned(
              left: 40,
              bottom: 60,
              child: Container(
                width: 80,
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryGold.withValues(alpha: 0.8),
                      AppColors.primaryGold.withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Portfolio',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
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
                  const Spacer(),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Your Balance:',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatCurrency(walletProvider.balance, walletProvider.currency),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencySelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppColors.primaryGold.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Your Wallet',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryGold : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected 
                              ? AppColors.primaryGold 
                              : (isDark ? Colors.grey[600]! : Colors.grey[300]!),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        currency,
                        style: TextStyle(
                          color: isSelected 
                              ? Colors.white 
                              : (isDark ? Colors.white : Colors.black87),
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItems(BuildContext context, bool isDark, WalletProvider walletProvider) {
    final giveOptions = walletProvider.giveOptions;
    final transactions = walletProvider.transactions;
    
    // Calculate money in/out totals
    double moneyIn = 0;
    double moneyOut = 0;
    for (final t in transactions) {
      if (t.transactionType == 'money_in') {
        moneyIn += t.amount;
      } else {
        moneyOut += t.amount;
      }
    }
    
    return Column(
      children: [
        // Give Section
        _buildExpandableMenuItem(
          context: context,
          isDark: isDark,
          icon: Icons.monetization_on_outlined,
          iconColor: AppColors.primaryGold,
          title: 'Give',
          isExpanded: isGiveExpanded,
          onTap: () => setState(() => isGiveExpanded = !isGiveExpanded),
          expandedContent: Column(
            children: giveOptions.map((option) => _buildGiveOptionItem(
              context: context,
              isDark: isDark,
              title: option.name,
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
            )).toList(),
          ),
        ),
        const SizedBox(height: 12),
        
        // Transactions Section
        _buildExpandableMenuItem(
          context: context,
          isDark: isDark,
          icon: Icons.swap_horiz,
          iconColor: AppColors.primaryGold,
          title: 'Transactions',
          isExpanded: isTransactionsExpanded,
          onTap: () => setState(() => isTransactionsExpanded = !isTransactionsExpanded),
          trailing: IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.grey),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TransactionsPage()),
            ),
          ),
          expandedContent: Column(
            children: [
              _buildTransactionSummaryRow('Money In', _formatCurrency(moneyIn, 'NGN'), isDark),
              _buildTransactionSummaryRow('Money Out', _formatCurrency(moneyOut, 'NGN'), isDark),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // My Cards Section
        _buildMenuItem(
          context: context,
          isDark: isDark,
          icon: Icons.credit_card_outlined,
          iconColor: AppColors.primaryGold,
          title: 'My Cards',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Coming soon')),
            );
          },
        ),
        const SizedBox(height: 12),
        
        // Savings Section
        _buildMenuItem(
          context: context,
          isDark: isDark,
          icon: Icons.savings_outlined,
          iconColor: AppColors.primaryGold,
          title: 'Savings',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Coming soon')),
            );
          },
        ),
        const SizedBox(height: 12),
        
        // Fund Wallet Section
        _buildMenuItem(
          context: context,
          isDark: isDark,
          icon: Icons.account_balance_wallet_outlined,
          iconColor: AppColors.primaryGold,
          title: 'Fund Wallet',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FundWalletPage()),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableMenuItem({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget expandedContent,
    Widget? trailing,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                trailing ?? Icon(
                  isExpanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
                  color: Colors.grey[400],
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: expandedContent,
          ),
      ],
    );
  }

  Widget _buildGiveOptionItem({
    required BuildContext context,
    required bool isDark,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionSummaryRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
