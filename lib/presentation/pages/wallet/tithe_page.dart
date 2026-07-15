import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/biometric_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/password_input_field.dart';
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
  String amount = '0';

  /// Calculate fees using live config from backend via WalletProvider.
  /// Falls back to standard rates if provider not yet loaded.
  Map<String, double> _getFees(double amount) {
    final walletProvider = ref.read(walletChangeNotifierProvider);
    return walletProvider.calculateFees(amount);
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
            content: Text(
              'Insufficient balance. Please add money to your wallet.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Enforce single transaction limit
    if (walletProvider.singleLimit > 0 &&
        amountValue > walletProvider.singleLimit) {
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
      final authenticated = await biometricProvider
          .authenticateForTransaction();
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
            return await walletProvider.giveWithBiometric(
              widget.giveOptionId,
              amountValue,
            );
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
    bool isSetting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final sheetBg = isDark ? AppColors.cardDark : Colors.white;
          final labelColor = isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight;
          final valueColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── drag handle ────────────────────────────────────────
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // ── close button ───────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      onPressed: isSetting
                          ? null
                          : () => Navigator.pop(sheetContext),
                    ),
                  ),

                  // ── icon + title ───────────────────────────────────────
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: AppColors.primaryGold,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Set Transaction PIN',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: valueColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You need a PIN before making payments.',
                    style: TextStyle(fontSize: 14, color: labelColor),
                  ),
                  const SizedBox(height: 24),

                  // ── PIN fields ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: PasswordInputField(
                      controller: pinController,
                      labelText: 'Enter PIN (4-6 digits)',
                      hintText: '••••',
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      autofocus: true,
                      enabled: !isSetting,
                      style: const TextStyle(
                        fontSize: 24,
                        letterSpacing: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          letterSpacing: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primaryGold,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: PasswordInputField(
                      controller: confirmPinController,
                      labelText: 'Confirm PIN',
                      hintText: '••••',
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      enabled: !isSetting,
                      style: const TextStyle(
                        fontSize: 24,
                        letterSpacing: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          letterSpacing: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primaryGold,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Set PIN button ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: isSetting
                            ? null
                            : () async {
                                if (pinController.text.length < 4) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'PIN must be at least 4 digits',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                if (pinController.text !=
                                    confirmPinController.text) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('PINs do not match'),
                                    ),
                                  );
                                  return;
                                }
                                setSheetState(() => isSetting = true);
                                final walletProvider = ref.read(
                                  walletChangeNotifierProvider,
                                );
                                final success = await walletProvider
                                    .setTransactionPin(
                                      pinController.text,
                                      confirmPinController.text,
                                    );
                                if (success && mounted) {
                                  Navigator.pop(sheetContext);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('PIN set successfully'),
                                    ),
                                  );
                                } else if (mounted) {
                                  setSheetState(() => isSetting = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        walletProvider.error ??
                                            'Failed to set PIN',
                                      ),
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGold,
                          disabledBackgroundColor: AppColors.primaryGold
                              .withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: isSetting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Set PIN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Sheet 1: Confirmation (no PIN) ─────────────────────────────────────────
  void _showPinDialog(double amountValue) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fees = _getFees(amountValue);
    final fee = fees['totalFee']!;
    final total = amountValue + fee;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final sheetBg = isDark ? AppColors.cardDark : Colors.white;
        final labelColor = isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight;
        final valueColor = isDark ? Colors.white : AppColors.textPrimaryLight;
        final cardBg = isDark
            ? AppColors.backgroundDark
            : const Color(0xFFF7F7F7);
        final dividerColor = isDark
            ? AppColors.dividerDark
            : AppColors.dividerLight;

        Widget infoRow(String label, Widget valueWidget) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 14, color: labelColor),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: valueWidget,
                  ),
                ),
              ],
            ),
          );
        }

        Widget divider() => Divider(height: 1, color: dividerColor);

        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── drag handle ────────────────────────────────────────────
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.dividerDark
                      : AppColors.dividerLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 4),

              // ── header row: close + title ──────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDark
                            ? Colors.white70
                            : AppColors.textSecondaryLight,
                      ),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                    const Spacer(),
                  ],
                ),
              ),

              // ── total amount ───────────────────────────────────────────
              Text(
                '₦${_fmt(amountValue)}',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGold,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── details card ───────────────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    infoRow(
                      'Purpose',
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: valueColor,
                        ),
                      ),
                    ),
                    divider(),
                    infoRow(
                      'Amount',
                      Text(
                        '₦${_fmt(amountValue)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: valueColor,
                        ),
                      ),
                    ),
                    divider(),
                    infoRow(
                      'Fee',
                      Text(
                        '₦${_fmt(fee)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: valueColor,
                        ),
                      ),
                    ),
                    if (fees['vat']! > 0) ...[
                      divider(),
                      infoRow(
                        'VAT',
                        Text(
                          '₦${_fmt(fees['vat']!)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: valueColor,
                          ),
                        ),
                      ),
                    ],
                    divider(),
                    infoRow(
                      'Total',
                      Text(
                        '₦${_fmt(total)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Pay button ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _showPinEntrySheet(amountValue);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGold,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Pay',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  // ── Sheet 2: PIN entry ───────────────────────────────────────────────────────
  void _showPinEntrySheet(double amountValue) {
    final pinController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final sheetBg = isDark ? AppColors.cardDark : Colors.white;
          final labelColor = isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight;
          final valueColor = isDark ? Colors.white : AppColors.textPrimaryLight;

          Future<void> submit() async {
            if (pinController.text.isEmpty || isProcessing) return;
            if (pinController.text.length < 4) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PIN must be at least 4 digits')),
              );
              return;
            }
            setSheetState(() => isProcessing = true);
            Navigator.pop(sheetContext);
            await _executePayment(amountValue, pinController.text);
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── drag handle ──────────────────────────────────────────
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.dividerDark
                          : AppColors.dividerLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // ── close button ─────────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDark
                            ? Colors.white70
                            : AppColors.textSecondaryLight,
                      ),
                      onPressed: isProcessing
                          ? null
                          : () => Navigator.pop(sheetContext),
                    ),
                  ),

                  // ── lock icon ────────────────────────────────────────────
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: AppColors.primaryGold,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter Transaction PIN',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: valueColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Confirm your payment with your PIN',
                    style: TextStyle(fontSize: 14, color: labelColor),
                  ),
                  const SizedBox(height: 28),

                  // ── PIN field ────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: pinController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      obscureText: true,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        letterSpacing: 12,
                        fontWeight: FontWeight.bold,
                        color: valueColor,
                      ),
                      decoration: InputDecoration(
                        hintText: '\u2022\u2022\u2022\u2022',
                        hintStyle: TextStyle(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          letterSpacing: 10,
                          fontSize: 22,
                        ),
                        counterText: '',
                        filled: true,
                        fillColor: isDark
                            ? AppColors.backgroundDark
                            : const Color(0xFFF7F7F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.primaryGold,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 16,
                        ),
                      ),
                      onSubmitted: (_) => submit(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Confirm button ───────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: isProcessing ? null : submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGold,
                          disabledBackgroundColor: AppColors.primaryGold
                              .withValues(alpha: 0.5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: isProcessing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Confirm Payment',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _fmt(double v) => v
      .toStringAsFixed(2)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  String _fmtLimit(double v) => v <= 0
      ? 'Unlimited'
      : '${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

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
            return await walletProvider.give(
              widget.giveOptionId,
              amountValue,
              pin,
            );
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
    final amountFontSize = Responsive.value(
      context,
      mobile: 40.0,
      tablet: 48.0,
      desktop: 56.0,
    );
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
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
                            amount == '0' ? '0.00' : amount,
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: amountFontSize,
                                  letterSpacing: -1,
                                ),
                          ),
                        ],
                      ),
                      SizedBox(height: spacing),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
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
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                fontSize: smallFontSize * 0.9,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'The CityGate Apostolic Kingdom Ministry',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: bodyFontSize * 0.95,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildNumpad(isDark),
                // Tier limit info — between numpad and Pay button
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 13,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
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
                          const Icon(
                            Icons.check_circle_outline,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Pay ₦${amount == '0' ? '0.00' : amount}',
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
    final keySize = Responsive.value(
      context,
      mobile: 72.0,
      tablet: 82.0,
      desktop: 92.0,
    );

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
    final fontSize = Responsive.value(
      context,
      mobile: 26.0,
      tablet: 30.0,
      desktop: 34.0,
    );

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
            color: isDark ? AppColors.surfaceDark : Colors.white,
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
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClearKey(bool isDark, double keySize) {
    final fontSize = Responsive.value(
      context,
      mobile: 14.0,
      tablet: 16.0,
      desktop: 18.0,
    );

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
              final newAmount = cleanAmount.substring(
                0,
                cleanAmount.length - 1,
              );
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
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
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
