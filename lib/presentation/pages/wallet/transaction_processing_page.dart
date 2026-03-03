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
  late Animation<double> _pulseAnimation;
  String _statusText = 'Processing your payment...';
  bool _isProcessing = true;

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

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _processPayment();
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
    final iconContainerSize = Responsive.value(context, mobile: 120.0, tablet: 140.0, desktop: 160.0);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: EdgeInsets.all(horizontalPadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Processing animation
                    AnimatedBuilder(
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
                          // Outer glow
                          Container(
                            width: iconContainerSize * 1.3,
                            height: iconContainerSize * 1.3,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.primaryGold.withOpacity(0.3),
                                  AppColors.primaryGold.withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                          // Main circle
                          Container(
                            width: iconContainerSize,
                            height: iconContainerSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primaryGold,
                                  AppColors.primaryGold.withOpacity(0.8),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryGold.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: _isProcessing
                                ? RotationTransition(
                                    turns: _rotationController,
                                    child: const Icon(
                                      Icons.sync,
                                      color: Colors.white,
                                      size: 50,
                                    ),
                                  )
                                : const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 60,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: spacing * 3),
                    // Status text
                    Text(
                      _statusText,
                      style: TextStyle(
                        fontSize: titleFontSize * 0.9,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: spacing),
                    // Amount
                    Text(
                      '₦${widget.amount}',
                      style: TextStyle(
                        fontSize: titleFontSize * 1.2,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGold,
                      ),
                    ),
                    SizedBox(height: spacing * 0.5),
                    // Type
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: bodyFontSize,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    SizedBox(height: spacing * 3),
                    // Loading indicator
                    if (_isProcessing)
                      SizedBox(
                        width: 200,
                        child: LinearProgressIndicator(
                          backgroundColor: isDark
                              ? AppColors.dividerDark
                              : Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primaryGold,
                          ),
                        ),
                      ),
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
