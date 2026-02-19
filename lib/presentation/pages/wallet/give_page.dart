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
import 'add_money_page.dart';

class GivePage extends ConsumerStatefulWidget {
  const GivePage({super.key});

  @override
  ConsumerState<GivePage> createState() => _GivePageState();
}

class _GivePageState extends ConsumerState<GivePage> {
  String selectedCurrency = 'NGN';
  final currencies = ['NGN', 'USD', 'EUR', 'GBP'];
  bool isGiveExpanded = true;

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
    final horizontalPadding = Responsive.horizontalPadding(context);
    final spacing = Responsive.verticalSpacing(context);
    final maxWidth = Responsive.maxContentWidth(context);

    final walletProvider = ref.watch(walletChangeNotifierProvider);
    
    return Scaffold(
      appBar: const CustomAppBar(title: ''),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.all(horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPortfolioCard(context, isDark, walletProvider),
                  SizedBox(height: spacing * 1.5),
                  _buildCurrencySelector(isDark),
                  SizedBox(height: spacing * 1.5),
                  _buildGiveSection(context, isDark, walletProvider),
                  SizedBox(height: spacing),
                  _buildTransactionsItem(context, isDark),
                  SizedBox(height: spacing),
                  _buildAddMoneyItem(context, isDark),
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
    final spacing = Responsive.verticalSpacing(context);
    final borderRadius = Responsive.largeBorderRadius(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final smallFontSize = Responsive.smallFontSize(context);
    final balanceFontSize = Responsive.value(context, mobile: 36.0, tablet: 42.0, desktop: 48.0);
    final iconSize = Responsive.iconSize(context);
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(spacing * 1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
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
              Text(
                'Your Portfolio',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: bodyFontSize,
                ),
              ),
              Text(
                _formatDate(now),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: smallFontSize,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing * 1.25),
          Text(
            'Your Balance:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: smallFontSize,
            ),
          ),
          SizedBox(height: spacing * 0.25),
          Text(
            _formatCurrency(walletProvider.balance, walletProvider.currency),
            style: TextStyle(
              color: Colors.white,
              fontSize: balanceFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (walletProvider.accountNumber != null) ...[
            SizedBox(height: spacing),
            Container(
              padding: EdgeInsets.symmetric(horizontal: spacing * 0.75, vertical: spacing * 0.5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Responsive.borderRadius(context) * 0.67),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance,
                    color: Colors.white70,
                    size: iconSize * 0.67,
                  ),
                  SizedBox(width: spacing * 0.5),
                  Text(
                    walletProvider.accountNumber!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: bodyFontSize,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(width: spacing * 0.5),
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
                      padding: EdgeInsets.all(spacing * 0.25),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.copy,
                        color: Colors.white,
                        size: iconSize * 0.67,
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
    final spacing = Responsive.verticalSpacing(context);
    final borderRadius = Responsive.borderRadius(context);
    final smallFontSize = Responsive.smallFontSize(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    
    return Container(
      padding: EdgeInsets.all(spacing),
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
            'Your Wallet',
            style: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              fontSize: smallFontSize,
            ),
          ),
          SizedBox(height: spacing * 0.75),
          Wrap(
            spacing: spacing * 0.5,
            runSpacing: spacing * 0.5,
            children: currencies.map((currency) {
              final isSelected = currency == selectedCurrency;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedCurrency = currency;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: spacing, vertical: spacing * 0.5),
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
                      fontSize: bodyFontSize * 0.93,
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
    final spacing = Responsive.verticalSpacing(context);
    final borderRadius = Responsive.borderRadius(context);
    final iconSize = Responsive.iconSize(context);
    final bodyFontSize = Responsive.bodyFontSize(context);

    return Container(
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
        children: [
          InkWell(
            onTap: () {
              setState(() {
                isGiveExpanded = !isGiveExpanded;
              });
            },
            borderRadius: BorderRadius.circular(borderRadius),
            child: Padding(
              padding: EdgeInsets.all(spacing),
              child: Row(
                children: [
                  Icon(
                    Icons.monetization_on_outlined,
                    color: AppColors.primaryGold,
                    size: iconSize,
                  ),
                  SizedBox(width: spacing),
                  Expanded(
                    child: Text(
                      'Give',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: bodyFontSize,
                      ),
                    ),
                  ),
                  Icon(
                    isGiveExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    size: iconSize,
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
                    padding: EdgeInsets.symmetric(horizontal: spacing * 3.5, vertical: spacing * 0.75),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            option.name,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: bodyFontSize,
                            ),
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
    final spacing = Responsive.verticalSpacing(context);
    final borderRadius = Responsive.borderRadius(context);
    final iconSize = Responsive.iconSize(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    
    return Container(
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
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TransactionsPage()),
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(
          padding: EdgeInsets.all(spacing),
          child: Row(
            children: [
              Icon(
                Icons.swap_horiz,
                color: AppColors.primaryGold,
                size: iconSize,
              ),
              SizedBox(width: spacing),
              Expanded(
                child: Text(
                  'Transactions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: bodyFontSize,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                size: iconSize,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddMoneyItem(BuildContext context, bool isDark) {
    final spacing = Responsive.verticalSpacing(context);
    final borderRadius = Responsive.borderRadius(context);
    final iconSize = Responsive.iconSize(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    
    return Container(
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
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddMoneyPage()),
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(
          padding: EdgeInsets.all(spacing),
          child: Row(
            children: [
              Icon(
                Icons.add_circle_outline,
                color: AppColors.primaryGold,
                size: iconSize,
              ),
              SizedBox(width: spacing),
              Expanded(
                child: Text(
                  'Add Money',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: bodyFontSize,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                size: iconSize,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
