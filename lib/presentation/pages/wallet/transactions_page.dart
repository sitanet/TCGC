import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  String selectedFilter = 'All';
  final filters = ['All', 'Money In', 'Money Out'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletChangeNotifierProvider).fetchTransactions();
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
      appBar: const CustomAppBar(title: 'Transactions'),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.all(horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(context, isDark, walletProvider),
                  SizedBox(height: spacing * 1.5),
                  _buildFilterSelector(isDark),
                  SizedBox(height: spacing * 1.5),
                  _buildTransactionsList(context, isDark, walletProvider),
                  SizedBox(height: spacing * 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, bool isDark, WalletProvider walletProvider) {
    final spacing = Responsive.verticalSpacing(context);
    final borderRadius = Responsive.largeBorderRadius(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final smallFontSize = Responsive.smallFontSize(context);
    final balanceFontSize = Responsive.value(context, mobile: 32.0, tablet: 38.0, desktop: 44.0);
    final subtitleFontSize = Responsive.subtitleFontSize(context);
    
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
                'Transaction Summary',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: bodyFontSize,
                ),
              ),
              Text(
                _formatDate(DateTime.now()),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: smallFontSize,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing * 1.25),
          Text(
            'Current Balance:',
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
          SizedBox(height: spacing),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Transactions',
                      style: TextStyle(color: Colors.white70, fontSize: smallFontSize),
                    ),
                    SizedBox(height: spacing * 0.25),
                    Text(
                      '${walletProvider.transactions.length}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: subtitleFontSize * 0.9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSelector(bool isDark) {
    final spacing = Responsive.verticalSpacing(context);
    final borderRadius = Responsive.borderRadius(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    
    return Container(
      padding: EdgeInsets.all(spacing),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Wrap(
        spacing: spacing * 0.5,
        runSpacing: spacing * 0.5,
        children: filters.map((filter) {
          final isSelected = filter == selectedFilter;
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedFilter = filter;
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: spacing, vertical: spacing * 0.5),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryGold : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryGold
                      : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
                ),
              ),
              child: Text(
                filter,
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
    );
  }

  Widget _buildTransactionsList(BuildContext context, bool isDark, WalletProvider walletProvider) {
    var transactions = walletProvider.transactions;
    final spacing = Responsive.verticalSpacing(context);
    final borderRadius = Responsive.borderRadius(context);
    final iconSize = Responsive.iconSize(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final smallFontSize = Responsive.smallFontSize(context);
    final iconContainerSize = Responsive.value(context, mobile: 44.0, tablet: 52.0, desktop: 60.0);
    
    if (selectedFilter == 'Money In') {
      transactions = transactions.where((t) => t.isMoneyIn).toList();
    } else if (selectedFilter == 'Money Out') {
      transactions = transactions.where((t) => !t.isMoneyIn).toList();
    }

    if (transactions.isEmpty) {
      return Container(
        padding: EdgeInsets.all(spacing * 2.5),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: iconSize * 2.5,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
              SizedBox(height: spacing),
              Text(
                'No transactions yet',
                style: TextStyle(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  fontSize: bodyFontSize,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: transactions.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        ),
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          final isMoneyIn = transaction.isMoneyIn;
          
          return ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: spacing, vertical: spacing * 0.5),
            leading: Container(
              width: iconContainerSize,
              height: iconContainerSize,
              decoration: BoxDecoration(
                color: (isMoneyIn ? Colors.green : Colors.red).withOpacity(0.1),
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: Icon(
                isMoneyIn ? Icons.arrow_downward : Icons.arrow_upward,
                color: isMoneyIn ? Colors.green : Colors.red,
                size: iconSize,
              ),
            ),
            title: Text(
              transaction.title,
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: bodyFontSize),
            ),
            subtitle: Text(
              _formatDate(transaction.date),
              style: TextStyle(
                fontSize: smallFontSize,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            trailing: Text(
              '${isMoneyIn ? '+' : '-'}${_formatCurrency(transaction.amount, transaction.currency)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isMoneyIn ? Colors.green : Colors.red,
                fontSize: bodyFontSize,
              ),
            ),
          );
        },
      ),
    );
  }
}
