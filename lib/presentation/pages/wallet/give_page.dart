import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/nigerian_banks.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';
import 'tithe_page.dart';
import 'transactions_page.dart';
import 'wallet_upgrade_page.dart';

class GivePage extends ConsumerStatefulWidget {
  const GivePage({super.key});

  @override
  ConsumerState<GivePage> createState() => _GivePageState();
}

class _GivePageState extends ConsumerState<GivePage> {
  String selectedCurrency = 'NGN';
  final currencies = ['NGN', 'USD', 'EUR', 'GBP'];
  bool _isBalanceHidden = true;

  void _handleBackNavigation() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      ref.read(mainTabIndexProvider.notifier).state = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = ref.read(walletChangeNotifierProvider);
      // Always fetch fresh wallet data to get account name/number
      provider.fetchWallet();
      provider.fetchTransactions();
      provider.fetchGivings();
      provider.fetchGiveOptions();
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

  void _toggleBalanceVisibility() {
    setState(() => _isBalanceHidden = !_isBalanceHidden);
  }

  void _showAddFundOptions(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add Fund',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a funding method',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            // Bank Transfer Option
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance,
                  color: AppColors.primaryGold,
                  size: 24,
                ),
              ),
              title: Text(
                'Bank Transfer',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                'Transfer from your bank account',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
              onTap: () {
                Navigator.pop(context);
                _showBankTransferDetails(context, isDark);
              },
            ),
            const SizedBox(height: 12),
            // ATM Card Option (Coming Soon)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.credit_card,
                  color: Colors.grey[400],
                  size: 24,
                ),
              ),
              title: Row(
                children: [
                  Text(
                    'ATM Card',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Coming Soon',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGold,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                'Pay with debit or credit card',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: Colors.grey[300],
              ),
              onTap: null,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showBankTransferDetails(BuildContext context, bool isDark) {
    final walletProvider = ref.read(walletChangeNotifierProvider);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Bank Transfer',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Transfer money to your wallet using the account details below',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            // Account Details Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryGold.withValues(alpha: 0.3),
                ),
              ),
              child: (walletProvider.accountNumber == null || walletProvider.accountNumber!.isEmpty)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.hourglass_empty,
                              color: AppColors.primaryGold,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Account details are being set up...',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Please check back in a few minutes.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[500] : Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAccountDetailRow(
                          context,
                          isDark,
                          'Bank Name',
                          '9 Payment Service Bank (9PSB)',
                        ),
                        const SizedBox(height: 16),
                        _buildAccountDetailRow(
                          context,
                          isDark,
                          'Account Number',
                          walletProvider.accountNumber!,
                          showCopy: true,
                        ),
                        const SizedBox(height: 16),
                        _buildAccountDetailRow(
                          context,
                          isDark,
                          'Account Name',
                          walletProvider.accountName ?? 'N/A',
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            // Transfer to Bank Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showBankSelectionSheet(context, isDark, walletProvider.accountNumber ?? '');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.account_balance),
                label: const Text(
                  'Transfer via Bank App',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Info Note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Colors.blue[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your wallet will be credited automatically once the transfer is confirmed.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showBankSelectionSheet(BuildContext context, bool isDark, String accountNumber) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select Your Bank',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose your bank to open the app and make a transfer',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: NigerianBanks.banks.length,
                  itemBuilder: (context, index) {
                    final bank = NigerianBanks.banks[index];
                    return _buildBankItem(context, isDark, bank, accountNumber);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBankItem(BuildContext context, bool isDark, NigerianBank bank, String accountNumber) {
    return InkWell(
      onTap: () => _openBankApp(context, bank, accountNumber),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                bank.logo,
                width: 40,
                height: 40,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      bank.name.substring(0, 1),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.primaryGold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                bank.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBankApp(BuildContext context, NigerianBank bank, String accountNumber) async {
    // Copy account number to clipboard first
    await Clipboard.setData(ClipboardData(text: accountNumber));
    
    if (!context.mounted) return;
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Account number copied! Opening ${bank.name}...'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primaryGold,
      ),
    );
    
    Navigator.pop(context);
    
    // Try to open the bank app
    bool launched = false;
    
    if (Platform.isAndroid && bank.androidPackage != null) {
      final androidUri = Uri.parse('android-app://${bank.androidPackage}');
      try {
        launched = await launchUrl(androidUri);
      } catch (e) {
        debugPrint('Failed to launch Android app: $e');
      }
      
      if (!launched) {
        // Try Play Store as fallback
        final playStoreUri = Uri.parse('market://details?id=${bank.androidPackage}');
        try {
          await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
        } catch (e) {
          // Try web Play Store
          final webPlayStore = Uri.parse('https://play.google.com/store/apps/details?id=${bank.androidPackage}');
          await launchUrl(webPlayStore, mode: LaunchMode.externalApplication);
        }
      }
    } else if (Platform.isIOS && bank.iosScheme != null) {
      final iosUri = Uri.parse(bank.iosScheme!);
      try {
        launched = await launchUrl(iosUri);
      } catch (e) {
        debugPrint('Failed to launch iOS app: $e');
      }
      
      if (!launched && bank.iosAppStoreId != null) {
        // Open App Store as fallback
        final appStoreUri = Uri.parse('https://apps.apple.com/app/id${bank.iosAppStoreId}');
        await launchUrl(appStoreUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Widget _buildAccountDetailRow(
    BuildContext context,
    bool isDark,
    String label,
    String value, {
    bool showCopy = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            if (showCopy)
              GestureDetector(
                onTap: () {
                  if (value != 'N/A') {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Account number copied to clipboard'),
                        duration: Duration(seconds: 2),
                        backgroundColor: AppColors.primaryGold,
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.copy,
                    size: 18,
                    color: AppColors.primaryGold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  IconData _getIconForGiveOption(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('tithe')) return Icons.account_balance;
    if (lowerName.contains('special')) return Icons.star_outline;
    if (lowerName.contains('baba') && lowerName.contains('land')) return Icons.landscape;
    if (lowerName.contains('baba')) return Icons.card_giftcard;
    if (lowerName.contains('mission')) return Icons.public;
    if (lowerName.contains('minister')) return Icons.person_outline;
    if (lowerName.contains('image') || lowerName.contains('glory')) return Icons.auto_awesome;
    return Icons.volunteer_activism;
  }

  void _showGiveOptions(BuildContext context, bool isDark) {
    final walletProvider = ref.read(walletChangeNotifierProvider);
    final giveOptions = walletProvider.giveOptions;

    if (giveOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No giving options available. Please try again later.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Giving Type',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ...giveOptions.map((option) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getIconForGiveOption(option.name),
                    color: AppColors.primaryGold,
                    size: 24,
                  ),
                ),
                title: Text(
                  option.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
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
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxWidth = Responsive.maxContentWidth(context);

    final walletProvider = ref.watch(walletChangeNotifierProvider);
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFFAFAFA),
      appBar: CustomAppBar(
        title: '',
        showBackButton: true,
        lightBackground: true,
        onBackPressed: _handleBackNavigation,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                _buildPortfolioCard(context, isDark, walletProvider),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 23),
                  child: _buildCurrencySelector(isDark),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 23),
                  child: _buildMenuItems(context, isDark),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortfolioCard(BuildContext context, bool isDark, WalletProvider walletProvider) {
    final now = DateTime.now();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 23),
      child: Container(
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
                  padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 20),
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
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            _formatDate(now),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Center(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Your Balance:',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _toggleBalanceVisibility(),
                                  child: Icon(
                                    _isBalanceHidden ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.white.withValues(alpha: 0.6),
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isBalanceHidden 
                                  ? '******' 
                                  : _formatCurrency(walletProvider.balance, walletProvider.currency),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Account Number with copy icon
                            (walletProvider.accountNumber != null && walletProvider.accountNumber!.isNotEmpty)
                                ? GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: walletProvider.accountNumber!));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Account number copied'),
                                          duration: Duration(seconds: 2),
                                          backgroundColor: AppColors.primaryGold,
                                        ),
                                      );
                                    },
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          walletProvider.accountNumber!,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.7),
                                            fontSize: 14,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.copy,
                                          color: Colors.white.withValues(alpha: 0.7),
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  )
                                : Text(
                                    'Setting up account...',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                          ],
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencySelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.primaryGold,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Select Currency',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: currencies.map((currency) {
              final isSelected = currency == selectedCurrency;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedCurrency = currency;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppColors.primaryGold 
                          : (isDark ? AppColors.surfaceDark : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isSelected 
                          ? [
                              BoxShadow(
                                color: AppColors.primaryGold.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        currency,
                        style: TextStyle(
                          color: isSelected 
                              ? Colors.white 
                              : (isDark ? Colors.white70 : Colors.black54),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 13,
                        ),
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

  Widget _buildMenuItems(BuildContext context, bool isDark) {
    final walletProvider = ref.watch(walletChangeNotifierProvider);
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            context: context,
            isDark: isDark,
            icon: Icons.add_circle_outline,
            gradientColors: [Colors.blue.shade400, Colors.blue.shade600],
            title: 'Add Fund',
            subtitle: 'Top up your wallet',
            onTap: () => _showAddFundOptions(context, isDark),
          ),
          Divider(
            height: 1,
            indent: 72,
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
          _buildMenuItem(
            context: context,
            isDark: isDark,
            icon: Icons.volunteer_activism_outlined,
            gradientColors: [AppColors.primaryGold, AppColors.goldVariant1],
            title: 'Give',
            subtitle: 'Tithe, Offerings & Seeds',
            onTap: () => _showGiveOptions(context, isDark),
          ),
          Divider(
            height: 1,
            indent: 72,
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
          _buildMenuItem(
            context: context,
            isDark: isDark,
            icon: Icons.history_rounded,
            gradientColors: [Colors.purple.shade400, Colors.purple.shade600],
            title: 'Transactions',
            subtitle: 'View transaction history',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TransactionsPage()),
            ),
          ),
          // Upgrade Wallet (only show if tier < 3)
          if (walletProvider.tier < 3) ...[
            Divider(
              height: 1,
              indent: 72,
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            ),
            _buildMenuItem(
              context: context,
              isDark: isDark,
              icon: Icons.upgrade_rounded,
              gradientColors: [Colors.teal.shade400, Colors.teal.shade600],
              title: 'Upgrade Wallet',
              subtitle: walletProvider.hasPendingUpgrade 
                  ? 'Upgrade pending review' 
                  : 'Increase your transaction limits',
              onTap: walletProvider.hasPendingUpgrade
                  ? () => _showPendingUpgradeInfo(context, isDark)
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WalletUpgradePage()),
                    ),
            ),
          ],
        ],
      ),
    );
  }
  
  void _showPendingUpgradeInfo(BuildContext context, bool isDark) {
    final walletProvider = ref.read(walletChangeNotifierProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.hourglass_empty, color: Colors.orange[600]),
            const SizedBox(width: 8),
            const Text('Upgrade Pending'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your wallet upgrade request is being reviewed by 9PSB.',
              style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Text(
              'Current Tier: ${walletProvider.tierName}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'This process typically takes 1-3 business days.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.primaryGold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required List<Color> gradientColors,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors[0].withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isDark ? Colors.white54 : Colors.grey.shade400,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
