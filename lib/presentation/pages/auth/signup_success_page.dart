import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_handler.dart';

class SignupSuccessPage extends StatefulWidget {
  final String email;
  final VoidCallback onGoToLogin;
  final Future<bool> Function() onResendEmail;

  const SignupSuccessPage({
    super.key,
    required this.email,
    required this.onGoToLogin,
    required this.onResendEmail,
  });

  @override
  State<SignupSuccessPage> createState() => _SignupSuccessPageState();
}

class _SignupSuccessPageState extends State<SignupSuccessPage>
    with TickerProviderStateMixin {
  late AnimationController _circleController;
  late AnimationController _checkController;
  late Animation<double> _circleAnimation;
  late Animation<double> _checkAnimation;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _circleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _circleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _circleController, curve: Curves.easeOutBack),
    );
    _checkAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.easeOutBack),
    );

    _circleController.forward().then((_) {
      _checkController.forward();
    });
  }

  @override
  void dispose() {
    _circleController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  Future<void> _handleResend() async {
    setState(() => _isResending = true);
    final success = await widget.onResendEmail();
    setState(() => _isResending = false);
    if (mounted) {
      if (success) {
        ErrorHandler.showSuccess(context, 'Confirmation email resent successfully!');
      } else {
        ErrorHandler.showError(context, 'Failed to resend email. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const Spacer(flex: 2),
              AnimatedBuilder(
                animation: _circleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _circleAnimation.value,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: AnimatedBuilder(
                        animation: _checkAnimation,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: CheckmarkPainter(
                              progress: _checkAnimation.value,
                              color: Colors.white,
                              strokeWidth: 8,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 48),
              const Text(
                'Account Created\nSuccessfully!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'A confirmation link has been sent to:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.email,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Please check your email and click the confirmation link to activate your account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isResending ? null : _handleResend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: _isResending
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Resend Email',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  CheckmarkPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final start = Offset(centerX - 25, centerY);
    final mid = Offset(centerX - 5, centerY + 20);
    final end = Offset(centerX + 30, centerY - 20);

    final path = Path();
    path.moveTo(start.dx, start.dy);

    if (progress <= 0.5) {
      final t = progress * 2;
      final x = start.dx + (mid.dx - start.dx) * t;
      final y = start.dy + (mid.dy - start.dy) * t;
      path.lineTo(x, y);
    } else {
      path.lineTo(mid.dx, mid.dy);
      final t = (progress - 0.5) * 2;
      final x = mid.dx + (end.dx - mid.dx) * t;
      final y = mid.dy + (end.dy - mid.dy) * t;
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
