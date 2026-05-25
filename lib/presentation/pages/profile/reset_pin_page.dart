import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';

class ResetPinPage extends ConsumerStatefulWidget {
  const ResetPinPage({super.key});

  @override
  ConsumerState<ResetPinPage> createState() => _ResetPinPageState();
}

class _ResetPinPageState extends ConsumerState<ResetPinPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureNewPin = true;
  bool _obscureConfirmPin = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _resetPin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final walletProvider = ref.read(walletChangeNotifierProvider);
      final success = await walletProvider.resetTransactionPin(
        _passwordController.text,
        _newPinController.text,
        _confirmPinController.text,
      );

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction PIN reset successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(walletProvider.error ?? 'Failed to reset PIN'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        String errorMessage = 'Failed to reset PIN. Please try again.';

        if (e is SocketException) {
          errorMessage =
              'Network error. Please check your internet connection.';
        } else if (e is TimeoutException) {
          errorMessage = 'Request timed out. Please try again.';
        } else if (e.toString().contains('Connection refused')) {
          errorMessage = 'Unable to connect to server. Please try again later.';
        } else if (e.toString().contains('Failed host lookup')) {
          errorMessage =
              'Network error. Please check your internet connection.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Reset Transaction PIN',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_reset, color: Colors.blue[700], size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Forgot Your PIN?',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[700],
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Enter your account password to reset your transaction PIN.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Reset your transaction PIN',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your account password and create a new PIN.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 32),
                _buildPasswordField(context, isDark),
                const SizedBox(height: 20),
                _buildPinField(
                  context,
                  isDark,
                  'New PIN',
                  _newPinController,
                  _obscureNewPin,
                  () => setState(() => _obscureNewPin = !_obscureNewPin),
                  (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a new PIN';
                    }
                    if (value.length != 4) {
                      return 'PIN must be 4 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _buildPinField(
                  context,
                  isDark,
                  'Confirm New PIN',
                  _confirmPinController,
                  _obscureConfirmPin,
                  () =>
                      setState(() => _obscureConfirmPin = !_obscureConfirmPin),
                  (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your new PIN';
                    }
                    if (value != _newPinController.text) {
                      return 'PINs do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _resetPin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGold,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Reset PIN',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Never share your PIN or password with anyone.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Password',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            return null;
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? AppColors.cardDark : AppColors.surfaceLight,
            hintText: 'Enter your account password',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryGold),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPinField(
    BuildContext context,
    bool isDark,
    String label,
    TextEditingController controller,
    bool obscureText,
    VoidCallback onToggleVisibility,
    String? Function(String?) validator,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          validator: validator,
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? AppColors.cardDark : AppColors.surfaceLight,
            counterText: '',
            hintText: '••••',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryGold),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off : Icons.visibility,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              onPressed: onToggleVisibility,
            ),
          ),
        ),
      ],
    );
  }
}
