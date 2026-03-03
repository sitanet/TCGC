import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../main.dart';

class FailurePage extends ConsumerStatefulWidget {
  final String title;
  final String amount;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const FailurePage({
    super.key,
    required this.title,
    required this.amount,
    this.errorMessage,
    this.onRetry,
  });

  @override
  ConsumerState<FailurePage> createState() => _FailurePageState();
}

class _FailurePageState extends ConsumerState<FailurePage>
    with TickerProviderStateMixin {
  late AnimationController _iconController;
  late AnimationController _scaleController;
  late Animation<double> _iconAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _iconController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _iconAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.elasticOut),
    );

    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeIn),
    );

    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _scaleController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _iconController.forward();
  }

  @override
  void dispose() {
    _iconController.dispose();
    _scaleController.dispose();
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
    final smallFontSize = Responsive.smallFontSize(context);
    final borderRadius = Responsive.borderRadius(context);
    final buttonHeight = Responsive.buttonHeight(context);
    final iconContainerSize = Responsive.value(context, mobile: 120.0, tablet: 140.0, desktop: 160.0);
    final iconSize = Responsive.value(context, mobile: 60.0, tablet: 70.0, desktop: 80.0);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(horizontalPadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: spacing * 4),
                    // Failure icon with animation
                    AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
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
                                  Colors.red.withOpacity(0.3),
                                  Colors.red.withOpacity(0.0),
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
                                  Colors.red,
                                  Colors.red.withOpacity(0.8),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: AnimatedBuilder(
                              animation: _iconAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _iconAnimation.value,
                                  child: child,
                                );
                              },
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: iconSize,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: spacing * 2.5),
                    // Failure text
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Text(
                            'Transaction Failed',
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          SizedBox(height: spacing),
                          Text(
                            widget.errorMessage ?? 'Your ${widget.title.toLowerCase()} could not be processed',
                            style: TextStyle(
                              fontSize: bodyFontSize,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: spacing * 2),
                    // Transaction details card
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(spacing * 1.5),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.cardDark : Colors.grey[50],
                          borderRadius: BorderRadius.circular(borderRadius * 1.5),
                          border: Border.all(
                            color: isDark
                                ? AppColors.dividerDark
                                : Colors.grey[200]!,
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow(
                              context,
                              'Amount',
                              '₦${widget.amount}',
                              isAmount: true,
                              isDark: isDark,
                            ),
                            Divider(
                              height: spacing * 2,
                              color: isDark
                                  ? AppColors.dividerDark
                                  : Colors.grey[200],
                            ),
                            _buildDetailRow(
                              context,
                              'Type',
                              widget.title,
                              isDark: isDark,
                            ),
                            Divider(
                              height: spacing * 2,
                              color: isDark
                                  ? AppColors.dividerDark
                                  : Colors.grey[200],
                            ),
                            _buildDetailRow(
                              context,
                              'Status',
                              'Failed',
                              isDark: isDark,
                              isStatus: true,
                            ),
                            Divider(
                              height: spacing * 2,
                              color: isDark
                                  ? AppColors.dividerDark
                                  : Colors.grey[200],
                            ),
                            _buildDetailRow(
                              context,
                              'Date',
                              _formatDate(DateTime.now()),
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: spacing * 2),
                    // Encouragement message
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        padding: EdgeInsets.all(spacing),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange[700],
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Please check your balance or try again later.',
                                style: TextStyle(
                                  fontSize: smallFontSize,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: spacing * 2),
                    // Retry Button (if callback provided)
                    if (widget.onRetry != null)
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SizedBox(
                          width: double.infinity,
                          height: buttonHeight,
                          child: ElevatedButton(
                            onPressed: widget.onRetry,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGold,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(borderRadius),
                              ),
                              elevation: 4,
                              shadowColor: AppColors.primaryGold.withValues(alpha: 0.4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.refresh, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  'Try Again',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: bodyFontSize,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (widget.onRetry != null) SizedBox(height: spacing),
                    // Back to Wallet Button
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SizedBox(
                        width: double.infinity,
                        height: buttonHeight,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.popUntil(context, (route) => route.isFirst);
                            ref.read(mainTabIndexProvider.notifier).state = 2;
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.primaryGold, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(borderRadius),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.account_balance_wallet_outlined, color: AppColors.primaryGold),
                              const SizedBox(width: 8),
                              Text(
                                'Back to Wallet',
                                style: TextStyle(
                                  color: AppColors.primaryGold,
                                  fontSize: bodyFontSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isAmount = false,
    bool isStatus = false,
    required bool isDark,
  }) {
    final bodyFontSize = Responsive.bodyFontSize(context);
    final smallFontSize = Responsive.smallFontSize(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: smallFontSize,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isAmount ? bodyFontSize * 1.1 : bodyFontSize,
            fontWeight: isAmount || isStatus ? FontWeight.bold : FontWeight.w500,
            color: isStatus
                ? Colors.red
                : isAmount
                    ? AppColors.primaryGold
                    : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day} ${months[date.month - 1]}, ${date.year} at $hour:${date.minute.toString().padLeft(2, '0')} $amPm';
  }
}
