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
  final filters = ['All', 'Money In', 'Money Out', 'Fees'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletChangeNotifierProvider).fetchTransactions();
    });
  }

  String _formatCurrency(double amount, String currency) {
    final symbols = {'NGN': '₦', 'USD': '\$', 'EUR': '€', 'GBP': '£'};
    final formatted = amount
        .toStringAsFixed(2)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return '${symbols[currency] ?? currency}$formatted';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
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

  Widget _buildSummaryCard(
    BuildContext context,
    bool isDark,
    WalletProvider walletProvider,
  ) {
    final smallFontSize = Responsive.smallFontSize(context);
    final balanceFontSize = Responsive.value(
      context,
      mobile: 32.0,
      tablet: 38.0,
      desktop: 44.0,
    );

    return Container(
      width: double.infinity,
      height: 178,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(52),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(52),
        child: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: Image.asset(
                'assets/images/wallet_bg.png',
                fit: BoxFit.cover,
              ),
            ),
            // Content
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 35,
                  vertical: 20,
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
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: smallFontSize,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          _formatDate(DateTime.now()),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: smallFontSize * 0.9,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'Current Balance:',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: smallFontSize,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatCurrency(
                              walletProvider.balance,
                              walletProvider.currency,
                            ),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: balanceFontSize,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Total Transactions: ${walletProvider.transactions.length}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: smallFontSize,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSelector(bool isDark) {
    final spacing = Responsive.verticalSpacing(context);
    final borderRadius = Responsive.borderRadius(context);
    final bodyFontSize = Responsive.bodyFontSize(context);

    return Container(
      padding: EdgeInsets.all(spacing * 0.5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(borderRadius + 4),
      ),
      child: Row(
        children: filters.map((filter) {
          final isSelected = filter == selectedFilter;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedFilter = filter;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: spacing * 0.7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryGold
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(borderRadius),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primaryGold.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    filter,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight),
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      fontSize: bodyFontSize * 0.9,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTransactionsList(
    BuildContext context,
    bool isDark,
    WalletProvider walletProvider,
  ) {
    final allTxns = walletProvider.transactions;

    List<TransactionModel> transactions;
    if (selectedFilter == 'Money In') {
      transactions = allTxns.where((t) => t.isMoneyIn && !t.isFee).toList();
    } else if (selectedFilter == 'Money Out') {
      transactions = allTxns.where((t) => !t.isMoneyIn && !t.isFee).toList();
    } else if (selectedFilter == 'Fees') {
      // Show only giving/money-out transactions that had a fee charged
      transactions = allTxns
          .where((t) => !t.isMoneyIn && !t.isFee && t.effectiveFee > 0)
          .toList();
    } else {
      // All — exclude internal fee-category transactions
      transactions = allTxns.where((t) => !t.isFee).toList();
    }

    final spacing = Responsive.verticalSpacing(context);
    final borderRadius = Responsive.borderRadius(context);
    final iconSize = Responsive.iconSize(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final smallFontSize = Responsive.smallFontSize(context);
    final iconContainerSize = Responsive.value(
      context,
      mobile: 48.0,
      tablet: 54.0,
      desktop: 62.0,
    );

    if (transactions.isEmpty) {
      return Container(
        padding: EdgeInsets.all(spacing * 3),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: iconSize * 2,
                  color: AppColors.primaryGold,
                ),
              ),
              SizedBox(height: spacing),
              Text(
                'No transactions yet',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                  fontSize: bodyFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: spacing * 0.5),
              Text(
                'Your transaction history will appear here',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontSize: smallFontSize,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        final isMoneyIn = transaction.isMoneyIn;
        final isFeeTab = selectedFilter == 'Fees';
        final itemColor = isMoneyIn
            ? Colors.green
            : isFeeTab
            ? Colors.orange
            : Colors.red;
        final itemIcon = isMoneyIn
            ? Icons.south_west_rounded
            : isFeeTab
            ? Icons.receipt_outlined
            : Icons.north_east_rounded;
        final itemLabel = isMoneyIn
            ? 'Credit'
            : isFeeTab
            ? 'Fee'
            : 'Debit';
        // On Fees tab show the fee amount; otherwise show the transaction amount
        final displayAmount = isFeeTab
            ? transaction.effectiveFee
            : transaction.amount;
        // Fees tab: no sign prefix. Money In: +. Money Out: -
        final displayPrefix = isFeeTab ? '' : (isMoneyIn ? '+' : '-');

        return Container(
          margin: EdgeInsets.only(bottom: spacing * 0.75),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showTransactionDetails(
                context,
                isDark,
                transaction,
                isFeeTab,
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              child: Padding(
                padding: EdgeInsets.all(spacing),
                child: Row(
                  children: [
                    Container(
                      width: iconContainerSize,
                      height: iconContainerSize,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [itemColor.shade400, itemColor.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                      child: Icon(
                        itemIcon,
                        color: Colors.white,
                        size: iconSize,
                      ),
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: bodyFontSize,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: spacing * 0.25),
                          Text(
                            _formatDate(transaction.date),
                            style: TextStyle(
                              fontSize: smallFontSize,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$displayPrefix${_formatCurrency(displayAmount, transaction.currency)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: itemColor.shade600,
                            fontSize: bodyFontSize,
                          ),
                        ),
                        SizedBox(height: spacing * 0.25),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: itemColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            itemLabel,
                            style: TextStyle(
                              fontSize: smallFontSize * 0.85,
                              fontWeight: FontWeight.w500,
                              color: itemColor.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTransactionDetails(
    BuildContext context,
    bool isDark,
    TransactionModel transaction,
    bool isFeeTab,
  ) {
    final bodyFontSize = Responsive.bodyFontSize(context);
    final smallFontSize = Responsive.smallFontSize(context);
    final isMoneyIn = transaction.isMoneyIn;
    final isFee = transaction.isFee;
    final detailColor = isMoneyIn
        ? Colors.green
        : (isFeeTab || isFee)
        ? Colors.orange
        : Colors.red;
    final detailIcon = isMoneyIn
        ? Icons.south_west_rounded
        : (isFeeTab || isFee)
        ? Icons.receipt_outlined
        : Icons.north_east_rounded;

    // Amount shown at top of detail sheet
    final topAmount = isFeeTab ? transaction.effectiveFee : transaction.amount;
    final topPrefix = isFeeTab ? '' : (isMoneyIn ? '+' : '-');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [detailColor.shade400, detailColor.shade600],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(detailIcon, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              transaction.title,
              style: TextStyle(
                fontSize: bodyFontSize * 1.1,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$topPrefix${_formatCurrency(topAmount, transaction.currency)}',
              style: TextStyle(
                fontSize: bodyFontSize * 1.5,
                fontWeight: FontWeight.w700,
                color: detailColor.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    'Date',
                    _formatDate(transaction.date),
                    isDark,
                    smallFontSize,
                  ),
                  const Divider(height: 24),
                  _buildDetailRow(
                    'Type',
                    isMoneyIn
                        ? 'Money In'
                        : isFee
                        ? 'Fee'
                        : 'Money Out',
                    isDark,
                    smallFontSize,
                  ),
                  const Divider(height: 24),
                  _buildDetailRow(
                    'Category',
                    transaction.category.replaceAll('_', ' ').toUpperCase(),
                    isDark,
                    smallFontSize,
                  ),
                  const Divider(height: 24),
                  _buildDetailRow('Status', 'Completed', isDark, smallFontSize),
                  // Show fee breakdown if there's a fee
                  if (transaction.effectiveFee > 0) ...[
                    const Divider(height: 24),
                    _buildDetailRow(
                      'Transaction Fee',
                      _formatCurrency(
                        transaction.effectiveFee,
                        transaction.currency,
                      ),
                      isDark,
                      smallFontSize,
                    ),
                    if (transaction.psbFee > 0)
                      _buildDetailRow(
                        '  • 9PSB Fee',
                        _formatCurrency(
                          transaction.psbFee,
                          transaction.currency,
                        ),
                        isDark,
                        smallFontSize * 0.9,
                      ),
                    if (transaction.stampDuty > 0)
                      _buildDetailRow(
                        '  • Stamp Duty',
                        _formatCurrency(
                          transaction.stampDuty,
                          transaction.currency,
                        ),
                        isDark,
                        smallFontSize * 0.9,
                      ),
                    if (transaction.vatAmount > 0)
                      _buildDetailRow(
                        '  • VAT',
                        _formatCurrency(
                          transaction.vatAmount,
                          transaction.currency,
                        ),
                        isDark,
                        smallFontSize * 0.9,
                      ),
                    if (transaction.partnerFee > 0)
                      _buildDetailRow(
                        '  • Service Fee',
                        _formatCurrency(
                          transaction.partnerFee,
                          transaction.currency,
                        ),
                        isDark,
                        smallFontSize * 0.9,
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    bool isDark,
    double fontSize,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            fontSize: fontSize,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }
}
