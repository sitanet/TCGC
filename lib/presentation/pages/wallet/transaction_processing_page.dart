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

  const TransactionProcessingPage({
    super.key,
    required this.title,
    required this.amount,
    required this.processTransaction,
    required this.successPage,
    this.errorMessage,
  });

  @override
  State<TransactionProcessingPage> createState() => _TransactionProcessingPageState();
}

class _TransactionProcessingPageState extends State<TransactionProcessingPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _shimmerController;
  late AnimationController _floatController;
  late AnimationController _ringController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _floatAnimation;
  String _statusText = 'Processing your payment...';
  bool _isProcessing = true;
  int _currentStep = 0;
  final List<String> _steps = [
    'Initiating transaction...',
    'Processing your payment...',
    'Verifying transaction...',
    'Almost done...',
  ];

  @override
  void initState() {
    super.initState();

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

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _floatAnimation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _startStepAnimation();
    _processPayment();
  }

  void _startStepAnimation() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted || !_isProcessing) return false;
      setState(() {
        _currentStep = (_currentStep + 1) % _steps.length;
        _statusText = _steps[_currentStep];
      });
      return _isProcessing;
    });
  }

  Future<void> _processPayment() async {
    try {
      // Simulate minimum processing time for better UX
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;

      setState(() {
        _statusText = 'Verifying transaction...';
      });

      final success = await widget.processTransaction();

      if (!mounted) return;

      if (success) {
        setState(() {
          _statusText = 'Payment successful!';
          _isProcessing = false;
        });

        await Future.delayed(const Duration(milliseconds: 500));

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

        // Navigate to failure page instead of just returning
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FailurePage(
              title: widget.title,
              amount: widget.amount,
              errorMessage: widget.errorMessage,
              onRetry: () {
                // Pop back to the amount entry page
                Navigator.pop(context);
              },
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

      // Navigate to failure page on error
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FailurePage(
            title: widget.title,
            amount: widget.amount,
            errorMessage: e.toString(),
            onRetry: () {
              Navigator.pop(context);
            },
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spacing = Responsive.verticalSpacing(context);
    final maxWidth = Responsive.maxContentWidth(context);
    final horizontalPadding = Responsive.horizontalPadding(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final titleFontSize = Responsive.titleFontSize(context);
    final iconContainerSize = Responsive.value(context, mobile: 140.0, tablet: 160.0, desktop: 180.0);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              // Background particles
              if (_isProcessing) ..._buildFloatingParticles(context),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                    padding: EdgeInsets.all(horizontalPadding),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Floating animation wrapper
                        AnimatedBuilder(
                          animation: _floatAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _isProcessing ? _floatAnimation.value : 0),
                              child: child,
                            );
                          },
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _isProcessing ? _pulseAnimation.value : 1.0,
                                child: child,
                              );
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Animated rings
                                ..._buildAnimatedRings(iconContainerSize),
                                // Outer glow with shimmer
                                AnimatedBuilder(
                                  animation: _shimmerAnimation,
                                  builder: (context, child) {
                                    return Container(
                                      width: iconContainerSize * 1.4,
                                      height: iconContainerSize * 1.4,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            AppColors.primaryGold.withOpacity(0.4),
                                            AppColors.primaryGold.withOpacity(0.1),
                                            AppColors.primaryGold.withOpacity(0.0),
                                          ],
                                          stops: const [0.0, 0.5, 1.0],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Main circle with gradient
                                Container(
                                  width: iconContainerSize,
                                  height: iconContainerSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFFFD700),
                                        AppColors.primaryGold,
                                        Color(0xFFB8860B),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryGold.withOpacity(0.5),
                                        blurRadius: 30,
                                        spreadRadius: 5,
                                        offset: const Offset(0, 10),
                                      ),
                                      BoxShadow(
                                        color: AppColors.primaryGold.withOpacity(0.3),
                                        blurRadius: 60,
                                        spreadRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: _isProcessing
                                      ? RotationTransition(
                                          turns: _rotationController,
                                          child: const Icon(
                                            Icons.sync_rounded,
                                            color: Colors.white,
                                            size: 60,
                                          ),
                                        )
                                      : TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0.0, end: 1.0),
                                          duration: const Duration(milliseconds: 500),
                                          builder: (context, value, child) {
                                            return Transform.scale(
                                              scale: value,
                                              child: const Icon(
                                                Icons.check_rounded,
                                                color: Colors.white,
                                                size: 70,
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: spacing * 3),
                        // Animated status text
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.3),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            _statusText,
                            key: ValueKey(_statusText),
                            style: TextStyle(
                              fontSize: titleFontSize * 0.85,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: spacing * 1.5),
                        // Amount with shimmer effect
                        ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
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
                            ).createShader(bounds);
                          },
                          child: Text(
                            '₦${widget.amount}',
                            style: TextStyle(
                              fontSize: titleFontSize * 1.4,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(height: spacing * 0.5),
                        // Type with icon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.volunteer_activism_rounded,
                              size: 18,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: bodyFontSize,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: spacing * 3),
                        // Custom animated progress indicator
                        if (_isProcessing) _buildCustomProgressIndicator(isDark),
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

  List<Widget> _buildAnimatedRings(double size) {
    return List.generate(3, (index) {
      return AnimatedBuilder(
        animation: _ringController,
        builder: (context, child) {
          final progress = (_ringController.value + index * 0.33) % 1.0;
          final scale = 1.0 + progress * 0.5;
          final opacity = (1.0 - progress).clamp(0.0, 0.4);
          return Transform.scale(
            scale: scale,
            child: Container(
              width: size * 1.2,
              height: size * 1.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryGold.withOpacity(opacity),
                  width: 2,
                ),
              ),
            ),
          );
        },
      );
    });
  }

  List<Widget> _buildFloatingParticles(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return List.generate(12, (index) {
      final random = math.Random(index);
      final startX = random.nextDouble() * screenSize.width;
      final startY = random.nextDouble() * screenSize.height;
      final size = 4.0 + random.nextDouble() * 8;
      
      return AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          final offsetY = math.sin(_floatController.value * math.pi * 2 + index) * 20;
          final offsetX = math.cos(_floatController.value * math.pi * 2 + index) * 10;
          return Positioned(
            left: startX + offsetX,
            top: startY + offsetY,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: index % 2 == 0 ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: index % 2 == 0 ? null : BorderRadius.circular(2),
                color: AppColors.primaryGold.withOpacity(0.2 + random.nextDouble() * 0.2),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildCustomProgressIndicator(bool isDark) {
    return Column(
      children: [
        SizedBox(
          width: 220,
          height: 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: AnimatedBuilder(
              animation: _shimmerController,
              builder: (context, child) {
                return ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      colors: [
                        AppColors.primaryGold.withOpacity(0.3),
                        AppColors.primaryGold,
                        AppColors.primaryGold.withOpacity(0.3),
                      ],
                      stops: [
                        (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                        _shimmerAnimation.value.clamp(0.0, 1.0),
                        (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
                      ],
                    ).createShader(bounds);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Please wait while we secure your transaction',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}
