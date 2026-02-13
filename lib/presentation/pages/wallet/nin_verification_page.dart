import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../widgets/custom_app_bar.dart';
import 'set_transaction_pin_page.dart';

class NinVerificationPage extends StatefulWidget {
  const NinVerificationPage({super.key});

  @override
  State<NinVerificationPage> createState() => _NinVerificationPageState();
}

class _NinVerificationPageState extends State<NinVerificationPage> {
  final _ninController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureNin = true;
  bool _isVerifying = false;

  @override
  void dispose() {
    _ninController.dispose();
    super.dispose();
  }

  Future<void> _verifyNin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isVerifying = true);

    final authProvider = context.read<AuthProvider>();
    final result = await authProvider.verifyNin(
      _ninController.text,
      updateProfile: true,
    );

    setState(() => _isVerifying = false);

    if (!mounted) return;

    if (result.success) {
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
                'NIN Verified Successfully!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your identity has been verified. Please set your transaction PIN to continue.',
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

      // Navigate to Set Transaction PIN page
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SetTransactionPinPage(
              nin: _ninController.text,
              verifiedData: result.verifiedData,
            ),
          ),
        );
      }
    } else {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'NIN verification failed. Please try again.'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
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
      appBar: const CustomAppBar(title: 'Create Wallet', showBackButton: true),
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
                        Icons.verified_user_outlined,
                        size: iconContainerSize * 0.5,
                        color: AppColors.primaryGold,
                      ),
                    ),
                    SizedBox(height: spacing * 1.5),

                    // Title
                    Text(
                      'Verify Your Identity',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGold,
                        fontSize: titleFontSize,
                      ),
                    ),
                    SizedBox(height: spacing * 0.5),

                    // Subtitle
                    Text(
                      'Enter your NIN (National Identification Number) to verify your identity and create your wallet.',
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

                    // NIN Input Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NIN (National Identification Number)',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _ninController,
                          obscureText: _obscureNin,
                          keyboardType: TextInputType.number,
                          maxLength: 11,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'NIN is required';
                            }
                            if (value.length != 11) {
                              return 'NIN must be 11 digits';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: 'Enter your 11-digit NIN',
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
                                _obscureNin
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: Colors.grey[600],
                              ),
                              onPressed: () {
                                setState(() => _obscureNin = !_obscureNin);
                              },
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing * 3),

                    // Next Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isVerifying ? null : _verifyNin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGold,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(borderRadius),
                          ),
                          elevation: 2,
                        ),
                        child: _isVerifying
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Next',
                                style: TextStyle(
                                  fontSize: bodyFontSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: spacing * 2),

                    // Info text
                    Container(
                      padding: EdgeInsets.all(horizontalPadding * 0.75),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your NIN is securely verified to protect your wallet and enable transactions.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue[700],
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
}
