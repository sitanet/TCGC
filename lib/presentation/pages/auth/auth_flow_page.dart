import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/services/notification_service.dart';
import 'sign_in_page.dart';
import 'sign_up_page.dart';

class AuthFlowPage extends ConsumerStatefulWidget {
  final bool isSignUp;
  final String? initialEmail;

  const AuthFlowPage({
    super.key,
    this.isSignUp = false,
    this.initialEmail,
  });

  static Future<bool?> open(
    BuildContext context, {
    bool isSignUp = false,
    String? initialEmail,
  }) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AuthFlowPage(
          isSignUp: isSignUp,
          initialEmail: initialEmail,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  ConsumerState<AuthFlowPage> createState() => _AuthFlowPageState();
}

class _AuthFlowPageState extends ConsumerState<AuthFlowPage> {
  late bool _showSignUp;

  @override
  void initState() {
    super.initState();
    _showSignUp = widget.isSignUp;
  }

  void _onSuccess() {
    // Notify push service for the logged-in user
    NotificationService().registerDevice();
    // Dismiss the auth flow and return true
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSignUp) {
      return SignUpPage(
        onSignUp: _onSuccess,
        onBack: () => Navigator.of(context).pop(false),
        onGoToSignIn: () => setState(() => _showSignUp = false),
      );
    }
    return SignInPage(
      initialEmail: widget.initialEmail,
      onSignIn: _onSuccess,
      onBack: () => Navigator.of(context).pop(false),
      onGoToSignUp: () => setState(() => _showSignUp = true),
    );
  }
}
