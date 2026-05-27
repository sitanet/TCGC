import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import 'failure_page.dart';

class TransactionProcessingPage extends StatefulWidget {
  final String title;
  final String amount;
  final Future<bool> Function() processTransaction;
  final Widget successPage;
  final String? errorMessage;
  final String? Function()? getErrorMessage;

  const TransactionProcessingPage({
    super.key,
    required this.title,
    required this.amount,
    required this.processTransaction,
    required this.successPage,
    this.errorMessage,
    this.getErrorMessage,
  });

  @override
  State<TransactionProcessingPage> createState() =>
      _TransactionProcessingPageState();
}

class _TransactionProcessingPageState extends State<TransactionProcessingPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _shimmerController;
  late AnimationController _floatController;
  late AnimationController _ringController;
  late AnimationController _dotsController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _floatAnimation;

  String _statusText = 'Initiating transaction...';
  bool _isProcessing = true;
  int _currentStep = 0;

  final List<Map<String, dynamic>> _steps = [
    {'text': 'Initiating transaction...', 'icon': Icons.lock_outline_rounded},
    {'text': 'Processing your payment...', 'icon': Icons.payment_rounded},
    {'text': 'Verifying transaction...', 'icon': Icons.verified_outlined},
    {'text': 'Almost done...', 'icon': Icons.check_circle_outline_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startStepAnimation();
    _processPayment();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _floatController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);

    _ringController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _floatAnimation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  void _startStepAnimation() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted || !_isProcessing) return false;
      setState(() {
        _currentStep = (_currentStep + 1) % _steps.length;
        _statusText = _steps[_currentStep]['text'] as String;
      });
      return _isProcessing;
    });
  }

  Future<void> _processPayment() async {
    try {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;

      final success = await widget.processTransaction();
      if (!mounted) return;

      if (success) {
        setState(() {
          _statusText = 'Payment successful!';
          _isProcessing = false;
        });
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => widget.successPage),
        );
      } else {
        setState(() {
          _statusText = 'Transaction failed';
          _isProcessing = false;
        });
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        final errorMsg = widget.getErrorMessage?.call() ?? widget.errorMessage;

        // Check if this is a timeout error
        final isTimeout =
            errorMsg?.contains('timeout') == true ||
            errorMsg?.contains('TIMEOUT') == true;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FailurePage(
              title: widget.title,
              amount: widget.amount,
              errorMessage: errorMsg,
              isTimeout: isTimeout,
              onRetry: () => Navigator.pop(context),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusText = 'Transaction failed';
        _isProcessing = false;
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      final errorMsg = widget.getErrorMessage?.call() ?? e.toString();

      // Check if this is a timeout error
      final isTimeout =
          errorMsg.contains('timeout') || errorMsg.contains('TIMEOUT');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FailurePage(
            title: widget.title,
            amount: widget.amount,
            errorMessage: errorMsg,
            isTimeout: isTimeout,
            onRetry: () => Navigator.pop(context),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _shimmerController.dispose();
    _floatController.dispose();
    _ringController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final maxWidth = Responsive.maxContentWidth(context);
    final titleFontSize = Responsive.titleFontSize(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final iconSize = Responsive.value(
      context,
      mobile: 110.0,
      tablet: 130.0,
      desktop: 150.0,
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : const Color(0xFFF8F6F0),
        body: SafeArea(
          child: Stack(
            children: [
              // Background particles
              if (_isProcessing) ..._buildParticles(size),

              // Main content
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 2),

                        // ── Animated icon ──────────────────────────────────
                        AnimatedBuilder(
                          animation: _floatAnimation,
                          builder: (_, child) => Transform.translate(
                            offset: Offset(
                              0,
                              _isProcessing ? _floatAnimation.value : 0,
                            ),
                            child: child,
                          ),
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (_, child) => Transform.scale(
                              scale: _isProcessing
                                  ? _pulseAnimation.value
                                  : 1.0,
                              child: child,
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Expanding rings
                                ..._buildRings(iconSize),
                                // Outer glow
                                Container(
                                  width: iconSize * 1.5,
                                  height: iconSize * 1.5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        AppColors.primaryGold.withValues(
                                          alpha: 0.3,
                                        ),
                                        AppColors.primaryGold.withValues(
                                          alpha: 0.06,
                                        ),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                // Main circle
                                Container(
                                  width: iconSize,
                                  height: iconSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFFFE066),
                                        AppColors.primaryGold,
                                        Color(0xFFB8860B),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryGold.withValues(
                                          alpha: 0.55,
                                        ),
                                        blurRadius: 40,
                                        spreadRadius: 4,
                                        offset: const Offset(0, 12),
                                      ),
                                      BoxShadow(
                                        color: AppColors.primaryGold.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 80,
                                        spreadRadius: 12,
                                      ),
                                    ],
                                  ),
                                  child: _isProcessing
                                      ? RotationTransition(
                                          turns: _rotationController,
                                          child: const Icon(
                                            Icons.sync_rounded,
                                            color: Colors.white,
                                            size: 48,
                                          ),
                                        )
                                      : TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0.0, end: 1.0),
                                          duration: const Duration(
                                            milliseconds: 500,
                                          ),
                                          builder: (_, v, __) =>
                                              Transform.scale(
                                                scale: v,
                                                child: const Icon(
                                                  Icons.check_rounded,
                                                  color: Colors.white,
                                                  size: 56,
                                                ),
                                              ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // ── Amount ─────────────────────────────────────────
                        AnimatedBuilder(
                          animation: _shimmerAnimation,
                          builder: (_, __) => ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: const [
                                Color(0xFFFFD700),
                                AppColors.primaryGold,
                                Color(0xFFFFD700),
                              ],
                              stops: [
                                (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                                _shimmerAnimation.value.clamp(0.0, 1.0),
                                (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
                              ],
                            ).createShader(bounds),
                            child: Text(
                              '₦${widget.amount}',
                              style: TextStyle(
                                fontSize: titleFontSize * 1.6,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ── Giving type pill ───────────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGold.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primaryGold.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.volunteer_activism_rounded,
                                size: 14,
                                color: AppColors.primaryGold,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryGold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),

                        // ── Status card ────────────────────────────────────
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.2),
                                end: Offset.zero,
                              ).animate(anim),
                              child: child,
                            ),
                          ),
                          child: Container(
                            key: ValueKey(_statusText),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.cardDark.withValues(alpha: 0.8)
                                  : Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primaryGold.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryGold.withValues(
                                    alpha: 0.08,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _steps[_currentStep]['icon'] as IconData,
                                  size: 18,
                                  color: AppColors.primaryGold,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _statusText,
                                  style: TextStyle(
                                    fontSize: bodyFontSize,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── Animated progress dots ─────────────────────────
                        if (_isProcessing) _buildAnimatedDots(),

                        const Spacer(flex: 3),

                        // ── Security footer ────────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_rounded,
                              size: 12,
                              color: isDark
                                  ? AppColors.textSecondaryDark.withValues(
                                      alpha: 0.6,
                                    )
                                  : Colors.black38,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Secured by 9PSB · Do not close this screen',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.textSecondaryDark.withValues(
                                        alpha: 0.6,
                                      )
                                    : Colors.black38,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedDots() {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final t = (_dotsController.value - delay).clamp(0.0, 1.0);
            final scale = 0.6 + 0.4 * math.sin(t * math.pi);
            final opacity = 0.3 + 0.7 * math.sin(t * math.pi);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryGold.withValues(alpha: opacity),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  List<Widget> _buildRings(double size) {
    return List.generate(3, (i) {
      return AnimatedBuilder(
        animation: _ringController,
        builder: (_, __) {
          final progress = (_ringController.value + i * 0.33) % 1.0;
          final scale = 1.0 + progress * 0.6;
          final opacity = (1.0 - progress).clamp(0.0, 0.35);
          return Transform.scale(
            scale: scale,
            child: Container(
              width: size * 1.25,
              height: size * 1.25,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryGold.withValues(alpha: opacity),
                  width: 1.5,
                ),
              ),
            ),
          );
        },
      );
    });
  }

  List<Widget> _buildParticles(Size screenSize) {
    return List.generate(14, (i) {
      final rng = math.Random(i * 7);
      final x = rng.nextDouble() * screenSize.width;
      final y = rng.nextDouble() * screenSize.height;
      final sz = 3.0 + rng.nextDouble() * 6;
      return AnimatedBuilder(
        animation: _floatController,
        builder: (_, __) {
          final dy = math.sin(_floatController.value * math.pi * 2 + i) * 18;
          final dx = math.cos(_floatController.value * math.pi * 2 + i) * 9;
          return Positioned(
            left: x + dx,
            top: y + dy,
            child: Container(
              width: sz,
              height: sz,
              decoration: BoxDecoration(
                shape: i % 3 == 0 ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: i % 3 == 0 ? BorderRadius.circular(2) : null,
                color: AppColors.primaryGold.withValues(
                  alpha: 0.08 + rng.nextDouble() * 0.15,
                ),
              ),
            ),
          );
        },
      );
    });
  }
}
