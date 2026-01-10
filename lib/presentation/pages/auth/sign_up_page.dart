import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';
import 'signup_success_page.dart';

class SignUpPage extends StatefulWidget {
  final VoidCallback onSignUp;
  final VoidCallback onBack;
  final VoidCallback? onGoToSignIn;

  const SignUpPage({super.key, required this.onSignUp, required this.onBack, this.onGoToSignIn});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isEmailValid = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmail);
  }

  void _validateEmail() {
    final email = _emailController.text;
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    setState(() {
      _isEmailValid = emailRegex.hasMatch(email);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    if (_passwordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final nameParts = _nameController.text.trim().split(' ');
    final firstName = nameParts.first;
    final lastName = nameParts.length > 1 ? nameParts.last : '';
    final middleName = nameParts.length > 2 ? nameParts.sublist(1, nameParts.length - 1).join(' ') : null;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.register(
      email: _emailController.text.trim(),
      username: _emailController.text.trim().split('@').first,
      password: _passwordController.text,
      firstName: firstName,
      lastName: lastName,
      middleName: middleName,
    );

    setState(() => _isLoading = false);

    if (success) {
      if (authProvider.requiresEmailConfirmation) {
        if (mounted) {
          _navigateToSuccessPage();
        }
      } else {
        widget.onSignUp();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error ?? 'Registration failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToSuccessPage() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => SignupSuccessPage(
          email: _emailController.text.trim(),
          onGoToLogin: () {
            Navigator.of(context).pop();
            if (widget.onGoToSignIn != null) {
              widget.onGoToSignIn!();
            }
          },
          onResendEmail: () async {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            return await authProvider.resendConfirmationEmail(_emailController.text.trim());
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final buttonHeight = Responsive.buttonHeight(context);
    final titleFontSize = Responsive.titleFontSize(context);
    final subtitleFontSize = Responsive.subtitleFontSize(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final smallFontSize = Responsive.smallFontSize(context);
    final spacing = Responsive.verticalSpacing(context);
    final maxWidth = Responsive.maxContentWidth(context);
    final borderRadius = Responsive.largeBorderRadius(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: spacing),
                    IconButton(
                      onPressed: widget.onBack,
                      icon: Icon(Icons.arrow_back, color: Colors.black, size: Responsive.iconSize(context)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 24,
                      highlightColor: Colors.grey.withOpacity(0.2),
                      splashColor: Colors.grey.withOpacity(0.3),
                    ),
                    SizedBox(height: spacing * 2.5),
                    Text(
                      'Create\nAccount',
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: spacing * 1.5),
                    Text(
                      'Sign up',
                      style: TextStyle(
                        fontSize: subtitleFontSize,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: spacing * 2),
                    // Full Name Field
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'John Davidson',
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      smallFontSize: smallFontSize,
                      bodyFontSize: bodyFontSize,
                      spacing: spacing,
                    ),
                    SizedBox(height: spacing * 1.5),
                    // Email Field
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      hint: 'example@gmail.com',
                      keyboardType: TextInputType.emailAddress,
                      suffixIcon: _isEmailValid
                          ? Icon(Icons.check, color: Colors.black, size: Responsive.iconSize(context))
                          : null,
                      smallFontSize: smallFontSize,
                      bodyFontSize: bodyFontSize,
                      spacing: spacing,
                    ),
                    SizedBox(height: spacing * 1.5),
                    // Password Field
                    _buildPasswordField(
                      controller: _passwordController,
                      label: 'Password',
                      obscureText: _obscurePassword,
                      onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                      smallFontSize: smallFontSize,
                      bodyFontSize: bodyFontSize,
                      spacing: spacing,
                    ),
                    SizedBox(height: spacing * 1.5),
                    // Confirm Password Field
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      obscureText: _obscureConfirmPassword,
                      onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      smallFontSize: smallFontSize,
                      bodyFontSize: bodyFontSize,
                      spacing: spacing,
                    ),
                    SizedBox(height: spacing * 2),
                    // Sign Up Button
                    SizedBox(
                      width: double.infinity,
                      height: buttonHeight,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSignUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGold,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(borderRadius),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: Responsive.iconSize(context),
                                width: Responsive.iconSize(context),
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Spacer(),
                                  Padding(
                                    padding: EdgeInsets.only(left: spacing * 1.5),
                                    child: Text(
                                      'Sign up',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: bodyFontSize,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    margin: EdgeInsets.only(right: spacing * 0.5),
                                    child: Icon(
                                      Icons.arrow_forward,
                                      color: Colors.white,
                                      size: Responsive.iconSize(context),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    SizedBox(height: spacing * 2),
                    // Sign In Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: smallFontSize,
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.onGoToSignIn,
                          child: Text(
                            'Sign in',
                            style: TextStyle(
                              color: AppColors.primaryGold,
                              fontSize: smallFontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing * 1.5),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required double smallFontSize,
    required double bodyFontSize,
    required double spacing,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: smallFontSize,
            color: Colors.grey[600],
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: bodyFontSize),
            border: InputBorder.none,
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.dividerLight),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primaryGold),
            ),
            suffixIcon: suffixIcon,
            contentPadding: EdgeInsets.symmetric(vertical: spacing * 0.75),
          ),
          style: TextStyle(
            fontSize: bodyFontSize,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
    required double smallFontSize,
    required double bodyFontSize,
    required double spacing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: smallFontSize,
            color: Colors.grey[600],
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: '**********',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: bodyFontSize),
            border: InputBorder.none,
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.dividerLight),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primaryGold),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: Colors.grey[600],
                size: Responsive.iconSize(context),
              ),
              onPressed: onToggle,
            ),
            contentPadding: EdgeInsets.symmetric(vertical: spacing * 0.75),
          ),
          style: TextStyle(
            fontSize: bodyFontSize,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
