import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';
import 'give_page.dart';

class NinVerificationPage extends ConsumerStatefulWidget {
  const NinVerificationPage({super.key});

  @override
  ConsumerState<NinVerificationPage> createState() => _NinVerificationPageState();
}

class _NinVerificationPageState extends ConsumerState<NinVerificationPage> {
  final _ninController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _ninFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _addressFocusNode = FocusNode();
  bool _obscureNin = true;
  bool _isVerifying = false;
  DateTime? _selectedDateOfBirth;
  
  // Field validation states
  bool _ninTouched = false;
  bool _phoneTouched = false;
  bool _addressTouched = false;
  bool _dobTouched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  void _loadUserData() {
    final authProvider = ref.read(authChangeNotifierProvider);
    final user = authProvider.user;
    if (user != null) {
      setState(() {
        _phoneController.text = user.phoneNumber ?? '';
        _addressController.text = user.address ?? '';
        _selectedDateOfBirth = user.dateOfBirth;
      });
    }
  }

  @override
  void dispose() {
    _ninController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _ninFocusNode.dispose();
    _phoneFocusNode.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData prefixIcon,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool touched = false,
    required bool isDark,
    required double borderRadius,
    FocusNode? nextFocusNode,
  }) {
    final hasError = touched && validator != null && validator(controller.text) != null;
    final isValid = touched && controller.text.isNotEmpty && (validator == null || validator(controller.text) == null);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: focusNode.hasFocus
            ? [
                BoxShadow(
                  color: AppColors.primaryGold.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLength: maxLength,
        maxLines: maxLines,
        inputFormatters: inputFormatters,
        textInputAction: nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
        onFieldSubmitted: (_) {
          if (nextFocusNode != null) {
            FocusScope.of(context).requestFocus(nextFocusNode);
          }
        },
        validator: validator,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontWeight: FontWeight.normal,
          ),
          labelStyle: TextStyle(
            color: focusNode.hasFocus
                ? AppColors.primaryGold
                : (isDark ? AppColors.textSecondaryDark : Colors.grey[600]),
            fontWeight: FontWeight.w500,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          filled: true,
          fillColor: isDark ? AppColors.cardDark : Colors.grey[50],
          counterText: '',
          prefixIcon: Container(
            margin: const EdgeInsets.only(left: 12, right: 8),
            child: Icon(
              prefixIcon,
              color: focusNode.hasFocus
                  ? AppColors.primaryGold
                  : (hasError ? AppColors.error : Colors.grey[500]),
              size: 22,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 48),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isValid)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.check_circle, color: AppColors.success, size: 20),
                ),
              if (onToggleObscure != null)
                IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: Colors.grey[500],
                    size: 22,
                  ),
                  onPressed: onToggleObscure,
                ),
            ],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(
              color: isValid
                  ? AppColors.success.withOpacity(0.5)
                  : (hasError ? AppColors.error.withOpacity(0.5) : Colors.grey[300]!),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: const BorderSide(color: AppColors.primaryGold, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: const BorderSide(color: AppColors.error, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: const BorderSide(color: AppColors.error, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildEnhancedDateField({
    required String label,
    required bool isDark,
    required double borderRadius,
  }) {
    final hasError = _dobTouched && _selectedDateOfBirth == null;
    final isValid = _selectedDateOfBirth != null;
    
    return GestureDetector(
      onTap: () async {
        setState(() => _dobTouched = true);
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDateOfBirth ?? DateTime(2000),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primaryGold,
                  onPrimary: Colors.white,
                  surface: isDark ? AppColors.cardDark : Colors.white,
                ),
                dialogBackgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
              ),
              child: child!,
            );
          },
        );
        if (date != null) {
          setState(() => _selectedDateOfBirth = date);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.grey[50],
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isValid
                ? AppColors.success.withOpacity(0.5)
                : (hasError ? AppColors.error.withOpacity(0.5) : Colors.grey[300]!),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: isValid ? AppColors.primaryGold : Colors.grey[500],
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedDateOfBirth != null
                        ? '${_selectedDateOfBirth!.day.toString().padLeft(2, '0')}/${_selectedDateOfBirth!.month.toString().padLeft(2, '0')}/${_selectedDateOfBirth!.year}'
                        : 'Select your date of birth',
                    style: TextStyle(
                      color: _selectedDateOfBirth != null
                          ? (isDark ? Colors.white : Colors.black87)
                          : Colors.grey[400],
                      fontSize: 16,
                      fontWeight: _selectedDateOfBirth != null ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (isValid)
              const Icon(Icons.check_circle, color: AppColors.success, size: 20)
            else
              Icon(Icons.arrow_drop_down, color: Colors.grey[500], size: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyNin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    // Validate required fields
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number is required'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Address is required'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_selectedDateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Date of birth is required'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);

    final authProvider = ref.read(authChangeNotifierProvider);
    final result = await authProvider.verifyNin(
      _ninController.text,
      phoneNumber: _phoneController.text,
      address: _addressController.text,
      dateOfBirth: _selectedDateOfBirth!.toIso8601String().split('T').first,
      updateProfile: true,
    );

    setState(() => _isVerifying = false);

    if (!mounted) return;

    if (result.success) {
      // Refresh wallet data
      final walletProvider = ref.read(walletChangeNotifierProvider);
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
                'Your identity has been verified and your wallet is ready. You can now make givings and offerings.',
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
                    Focus(
                      onFocusChange: (hasFocus) {
                        if (!hasFocus) setState(() => _ninTouched = true);
                        setState(() {});
                      },
                      child: _buildEnhancedTextField(
                        controller: _ninController,
                        focusNode: _ninFocusNode,
                        label: 'NIN (National Identification Number)',
                        hint: 'Enter your 11-digit NIN',
                        prefixIcon: Icons.badge_outlined,
                        obscureText: _obscureNin,
                        onToggleObscure: () => setState(() => _obscureNin = !_obscureNin),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 11,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'NIN is required';
                          if (value.length != 11) return 'NIN must be 11 digits';
                          return null;
                        },
                        touched: _ninTouched,
                        isDark: isDark,
                        borderRadius: borderRadius,
                        nextFocusNode: _phoneFocusNode,
                      ),
                    ),
                    SizedBox(height: spacing * 1.5),

                    // Phone Number Field
                    Focus(
                      onFocusChange: (hasFocus) {
                        if (!hasFocus) setState(() => _phoneTouched = true);
                        setState(() {});
                      },
                      child: _buildEnhancedTextField(
                        controller: _phoneController,
                        focusNode: _phoneFocusNode,
                        label: 'Phone Number',
                        hint: 'Enter your phone number',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 11,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Phone number is required';
                          if (value.length < 10) return 'Enter a valid phone number';
                          return null;
                        },
                        touched: _phoneTouched,
                        isDark: isDark,
                        borderRadius: borderRadius,
                        nextFocusNode: _addressFocusNode,
                      ),
                    ),
                    SizedBox(height: spacing * 1.5),

                    // Date of Birth Field
                    _buildEnhancedDateField(
                      label: 'Date of Birth',
                      isDark: isDark,
                      borderRadius: borderRadius,
                    ),
                    SizedBox(height: spacing * 1.5),

                    // Address Field
                    Focus(
                      onFocusChange: (hasFocus) {
                        if (!hasFocus) setState(() => _addressTouched = true);
                        setState(() {});
                      },
                      child: _buildEnhancedTextField(
                        controller: _addressController,
                        focusNode: _addressFocusNode,
                        label: 'Residential Address',
                        hint: 'Enter your residential address',
                        prefixIcon: Icons.location_on_outlined,
                        maxLines: 2,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Address is required';
                          if (value.length < 10) return 'Enter a complete address';
                          return null;
                        },
                        touched: _addressTouched,
                        isDark: isDark,
                        borderRadius: borderRadius,
                      ),
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
