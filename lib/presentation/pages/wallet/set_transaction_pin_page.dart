import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../main.dart' show walletChangeNotifierProvider;
import '../../widgets/custom_app_bar.dart';
import 'give_page.dart';

class SetTransactionPinPage extends ConsumerStatefulWidget {
  final String nin;
  final Map<String, dynamic>? verifiedData;

  const SetTransactionPinPage({
    super.key,
    required this.nin,
    this.verifiedData,
  });

  @override
  ConsumerState<SetTransactionPinPage> createState() => _SetTransactionPinPageState();
}

class _SetTransactionPinPageState extends ConsumerState<SetTransactionPinPage> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _createWalletAndSetPin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    final walletProvider = ref.read(walletChangeNotifierProvider);

    // Wallet should already be created during NIN verification
    // Just set the transaction PIN directly
    debugPrint('SetTransactionPinPage: Starting PIN setup...');
    debugPrint('SetTransactionPinPage: PIN length: ${_pinController.text.length}');
    
    bool pinSuccess = false;
    try {
      pinSuccess = await walletProvider.setTransactionPin(
        _pinController.text,
        _confirmPinController.text,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('SetTransactionPinPage: PIN setup timed out');
          return false;
        },
      );
    } catch (e) {
      debugPrint('SetTransactionPinPage: PIN setup error: $e');
      pinSuccess = false;
    }

    debugPrint('SetTransactionPinPage: PIN setup result: $pinSuccess');

    if (!mounted) return;

    setState(() => _isLoading = false);
    
    if (!pinSuccess && walletProvider.error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request timed out. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (pinSuccess) {
      // Refresh wallet data to ensure state is synced
      await walletProvider.fetchWallet();
      // Show success popup
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Wallet Created Successfully!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your wallet is ready. You can now make givings and offerings.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );

      // Navigate to wallet details (GivePage)
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const GivePage()),
          (route) => route.isFirst,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(walletProvider.error ?? 'Failed to set transaction PIN'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = Responsive.horizontalPadding(context);
    final spacing = Responsive.verticalSpacing(context);
    final maxWidth = Responsive.maxContentWidth(context);
    final titleFontSize = Responsive.titleFontSize(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final borderRadius = Responsive.borderRadius(context);
    final iconContainerSize = Responsive.value(context, mobile: 100.0, tablet: 120.0, desktop: 140.0);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Set Transaction PIN', showBackButton: false),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.all(horizontalPadding),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: spacing * 2),

                    // Icon
                    Container(
                      width: iconContainerSize,
                      height: iconContainerSize,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryGold.withOpacity(0.2),
                            AppColors.primaryGold.withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        size: iconContainerSize * 0.5,
                        color: AppColors.primaryGold,
                      ),
                    ),
                    SizedBox(height: spacing * 1.5),

                    // Title
                    Text(
                      'Set Transaction PIN',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGold,
                        fontSize: titleFontSize,
                      ),
                    ),
                    SizedBox(height: spacing * 0.5),

                    // Subtitle
                    Text(
                      'Create a 4-digit PIN to secure your wallet transactions. You\'ll need this PIN for all givings and offerings.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        height: 1.5,
                        fontSize: bodyFontSize,
                      ),
                    ),
                    SizedBox(height: spacing * 3),

                    // PIN Input Field
                    _buildPinField(
                      context: context,
                      controller: _pinController,
                      label: 'Transaction PIN',
                      hint: 'Enter 4-digit PIN',
                      isDark: isDark,
                      obscure: _obscurePin,
                      borderRadius: borderRadius,
                      onToggle: () => setState(() => _obscurePin = !_obscurePin),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'PIN is required';
                        }
                        if (value.length != 4) {
                          return 'PIN must be 4 digits';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: spacing * 1.5),

                    // Confirm PIN Input Field
                    _buildPinField(
                      context: context,
                      controller: _confirmPinController,
                      label: 'Confirm Transaction PIN',
                      hint: 'Re-enter 4-digit PIN',
                      isDark: isDark,
                      obscure: _obscureConfirmPin,
                      borderRadius: borderRadius,
                      onToggle: () => setState(() => _obscureConfirmPin = !_obscureConfirmPin),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your PIN';
                        }
                        if (value != _pinController.text) {
                          return 'PINs do not match';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: spacing * 3),

                    // Create Wallet Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createWalletAndSetPin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGold,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(borderRadius),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Create Wallet',
                                style: TextStyle(
                                  fontSize: bodyFontSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: spacing * 2),

                    // Security info
                    Container(
                      padding: EdgeInsets.all(horizontalPadding * 0.75),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.security,
                            color: Colors.orange[700],
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Never share your PIN with anyone. TCGC will never ask for your PIN.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: spacing * 4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    required bool obscure,
    required double borderRadius,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: isDark ? AppColors.cardDark : Colors.grey[100],
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: const BorderSide(
                color: AppColors.primaryGold,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Colors.grey[600],
              ),
              onPressed: onToggle,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}
