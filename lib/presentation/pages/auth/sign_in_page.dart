import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/biometric_provider.dart';
import '../../../core/utils/responsive.dart';

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
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmail);
    _initBiometric();
  }

  Future<void> _initBiometric() async {
    final biometricProvider = Provider.of<BiometricProvider>(context, listen: false);
    await biometricProvider.initialize();
    if (mounted) {
      setState(() {
        _biometricAvailable = biometricProvider.isAvailable && 
                              biometricProvider.biometricLoginEnabled &&
                              biometricProvider.hasSavedCredentials;
      });
    }
  }

  Future<void> _handleBiometricLogin() async {
    final biometricProvider = Provider.of<BiometricProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final authenticated = await biometricProvider.authenticateForLogin();
    if (!authenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication failed')),
        );
      }
      return;
    }

    final credentials = await biometricProvider.getSavedCredentials();
    if (credentials == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No saved credentials found')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    final success = await authProvider.login(
      credentials['email']!,
      credentials['password']!,
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
                    SizedBox(height: Responsive.hp(context, 8)),
                    Text(
                      'Welcome\nBack!',
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: spacing * 1.5),
                    Text(
                      'Sign in',
                      style: TextStyle(
                        fontSize: subtitleFontSize,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: spacing * 2),
                    // Email Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email Address',
                          style: TextStyle(
                            fontSize: smallFontSize,
                            color: Colors.grey[600],
                          ),
                        ),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'example@gmail.com',
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: bodyFontSize),
                            border: InputBorder.none,
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: AppColors.dividerLight),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: AppColors.primaryGold),
                            ),
                            suffixIcon: _isEmailValid
                                ? Icon(Icons.check, color: Colors.black, size: Responsive.iconSize(context))
                                : null,
                            contentPadding: EdgeInsets.symmetric(vertical: spacing * 0.75),
                          ),
                          style: TextStyle(
                            fontSize: bodyFontSize,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing * 1.5),
                    // Password Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Password',
                          style: TextStyle(
                            fontSize: smallFontSize,
                            color: Colors.grey[600],
                          ),
                        ),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
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
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: Colors.grey[600],
                                size: Responsive.iconSize(context),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            contentPadding: EdgeInsets.symmetric(vertical: spacing * 0.75),
                          ),
                          style: TextStyle(
                            fontSize: bodyFontSize,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing),
                    // Forgot Password
                    TextButton(
                      onPressed: () {
                        _showForgotPasswordDialog();
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: AppColors.primaryGold,
                          fontSize: smallFontSize,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing * 2),
                    // Sign In Button
                    SizedBox(
                      width: double.infinity,
                      height: buttonHeight,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSignIn,
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
                                      'Sign in',
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
                    if (_biometricAvailable) ...[
                      SizedBox(height: spacing),
                      Center(
                        child: Text(
                          'or',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: smallFontSize,
                          ),
                        ),
                      ),
                      SizedBox(height: spacing),
                      SizedBox(
                        width: double.infinity,
                        height: buttonHeight,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _handleBiometricLogin,
                          icon: Icon(
                            Icons.fingerprint,
                            color: AppColors.primaryGold,
                            size: Responsive.iconSize(context),
                          ),
                          label: Text(
                            'Sign in with Biometrics',
                            style: TextStyle(
                              color: AppColors.primaryGold,
                              fontSize: bodyFontSize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primaryGold),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(borderRadius),
                            ),
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: spacing * 2),
                    // Sign Up Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: smallFontSize,
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.onGoToSignUp,
                          child: Text(
                            'Sign up',
                            style: TextStyle(
                              color: AppColors.primaryGold,
                              fontSize: smallFontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing * 2),
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
