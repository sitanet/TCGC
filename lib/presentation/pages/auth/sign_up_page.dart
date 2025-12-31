import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';

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
          _showEmailConfirmationDialog(authProvider.message ?? 'Please check your email to confirm your account.');
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

  void _showEmailConfirmationDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.mark_email_read, color: AppColors.primaryGold, size: 28),
            const SizedBox(width: 12),
            const Text('Check Your Email'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              'A confirmation link has been sent to:\n${_emailController.text}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final success = await authProvider.resendConfirmationEmail(_emailController.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Confirmation email resent!' : (authProvider.error ?? 'Failed to resend')),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Resend Email'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onGoToSignIn != null) {
                widget.onGoToSignIn!();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
            ),
            child: const Text('Go to Login', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 24,
                  highlightColor: Colors.grey.withOpacity(0.2),
                  splashColor: Colors.grey.withOpacity(0.3),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Create\nAccount',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Sign up',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 32),
                // Full Name Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Full Name',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    TextField(
                      controller: _nameController,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'John Davidson',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.dividerLight),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primaryGold),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Email Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Email Address',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'Davidson@gmail.com',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.dividerLight),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primaryGold),
                        ),
                        suffixIcon: _isEmailValid
                            ? const Icon(Icons.check, color: Colors.black)
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Password Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: '**********',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.dividerLight),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primaryGold),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.grey[600],
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Confirm Password Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confirm Password',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        hintText: '**********',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.dividerLight),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primaryGold),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.grey[600],
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Sign Up Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGold,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Spacer(),
                              const Padding(
                                padding: EdgeInsets.only(left: 24),
                                child: Text(
                                  'Sign up',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                child: const Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 32),
                // Sign In Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onGoToSignIn,
                      child: const Text(
                        'Sign in',
                        style: TextStyle(
                          color: AppColors.primaryGold,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
