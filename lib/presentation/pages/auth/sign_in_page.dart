import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';

class SignInPage extends StatefulWidget {
  final VoidCallback onSignIn;
  final VoidCallback onBack;
  final VoidCallback? onGoToSignUp;

  const SignInPage({super.key, required this.onSignIn, required this.onBack, this.onGoToSignUp});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (success) {
      widget.onSignIn();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error ?? 'Login failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();
    bool isLoading = false;
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your email address and we\'ll send you a link to reset your password.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !isLoading,
                decoration: InputDecoration(
                  hintText: 'Email address',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primaryGold),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (resetEmailController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter your email'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                setDialogState(() => isLoading = true);
                
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final success = await authProvider.forgotPassword(resetEmailController.text.trim());
                
                setDialogState(() => isLoading = false);
                
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(success 
                        ? authProvider.message ?? 'Password reset link sent to your email'
                        : authProvider.error ?? 'Failed to send reset link'),
                      backgroundColor: success ? AppColors.primaryGold : Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
              ),
              child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Send',
                    style: TextStyle(color: Colors.white),
                  ),
            ),
          ],
        ),
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
                const SizedBox(height: 80),
                const Text(
                  'Welcome\nBack!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Sign in',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 32),
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
                const SizedBox(height: 16),
                // Forgot Password
                TextButton(
                  onPressed: () {
                    _showForgotPasswordDialog();
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: AppColors.primaryGold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Sign In Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignIn,
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
                                  'Sign in',
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
                // Sign Up Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onGoToSignUp,
                      child: const Text(
                        'Sign up',
                        style: TextStyle(
                          color: AppColors.primaryGold,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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
  }
}
