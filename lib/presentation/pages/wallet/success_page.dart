import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../main.dart';

class SuccessPage extends ConsumerStatefulWidget {
  final String title;
  final String amount;
  final String? reference;

  const SuccessPage({
    super.key,
    required this.title,
    required this.amount,
    this.reference,
  });

  @override
  ConsumerState<SuccessPage> createState() => _SuccessPageState();
}

class _SuccessPageState extends ConsumerState<SuccessPage>
    with TickerProviderStateMixin {
  late AnimationController _checkController;
  late AnimationController _scaleController;
  late AnimationController _confettiController;
  late Animation<double> _checkAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  bool _isGeneratingReceipt = false;

  @override
  void initState() {
    super.initState();

    _checkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _checkAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.elasticOut),
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
    _checkController.forward();
    _confettiController.forward();
  }

  @override
  void dispose() {
    _checkController.dispose();
    _scaleController.dispose();
    _confettiController.dispose();
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
          child: Stack(
            children: [
              // Confetti particles
              ...List.generate(20, (index) => _buildConfettiParticle(index)),
              // Main content
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(horizontalPadding),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: spacing * 4),
                        // Success icon with animation
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
                                      AppColors.success.withOpacity(0.3),
                                      AppColors.success.withOpacity(0.0),
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
                                      AppColors.success,
                                      AppColors.success.withOpacity(0.8),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.success.withOpacity(0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: AnimatedBuilder(
                                  animation: _checkAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _checkAnimation.value,
                                      child: child,
                                    );
                                  },
                                  child: Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: iconSize,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: spacing * 2.5),
                        // Success text
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Column(
                            children: [
                              Text(
                                'Payment Successful!',
                                style: TextStyle(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                              SizedBox(height: spacing),
                              Text(
                                'Your ${widget.title.toLowerCase()} has been received',
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
                                  'To',
                                  'The CityGate Church',
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
                                  'Date',
                                  _formatDate(DateTime.now()),
                                  isDark: isDark,
                                ),
                                if (widget.reference != null) ...[
                                  Divider(
                                    height: spacing * 2,
                                    color: isDark
                                        ? AppColors.dividerDark
                                        : Colors.grey[200],
                                  ),
                                  _buildDetailRow(
                                    context,
                                    'Reference',
                                    widget.reference!,
                                    isDark: isDark,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: spacing * 2),
                        // Blessing message
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            padding: EdgeInsets.all(spacing),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGold.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(borderRadius),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  color: AppColors.primaryGold,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '"Give, and it will be given to you..." - Luke 6:38',
                                    style: TextStyle(
                                      fontSize: smallFontSize,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.primaryGold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: spacing * 2),
                        // Generate Receipt Button
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: SizedBox(
                            width: double.infinity,
                            height: buttonHeight,
                            child: ElevatedButton(
                              onPressed: _isGeneratingReceipt ? null : () => _showReceiptOptions(context, isDark),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGold,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(borderRadius),
                                ),
                                elevation: 4,
                                shadowColor: AppColors.primaryGold.withValues(alpha: 0.4),
                              ),
                              child: _isGeneratingReceipt
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.receipt_long_outlined, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Generate Receipt',
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
                        SizedBox(height: spacing),
                        // Back to Wallet Button
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: SizedBox(
                            width: double.infinity,
                            height: buttonHeight,
                            child: OutlinedButton(
                              onPressed: () {
                                // Go back to wallet page (GivePage)
                                Navigator.popUntil(context, (route) => route.isFirst);
                                ref.read(mainTabIndexProvider.notifier).state = 2; // Wallet tab
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
            ],
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
            fontWeight: isAmount ? FontWeight.bold : FontWeight.w500,
            color: isAmount
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

  void _showReceiptOptions(BuildContext context, bool isDark) {
    final spacing = Responsive.verticalSpacing(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(spacing * 1.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: spacing * 1.5),
            Text(
              'Generate Receipt',
              style: TextStyle(
                fontSize: bodyFontSize * 1.2,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: spacing * 0.5),
            Text(
              'Choose format to generate and share',
              style: TextStyle(
                fontSize: bodyFontSize * 0.9,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            SizedBox(height: spacing * 2),
            // Image Option
            ListTile(
              onTap: () {
                Navigator.pop(context);
                _generateAndShareReceipt(context, 'image');
              },
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.image_outlined, color: AppColors.primaryGold),
              ),
              title: Text(
                'Image (PNG)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                'Best for sharing on social media',
                style: TextStyle(
                  fontSize: bodyFontSize * 0.8,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.primaryGold),
            ),
            const SizedBox(height: 8),
            // PDF Option
            ListTile(
              onTap: () {
                Navigator.pop(context);
                _generateAndShareReceipt(context, 'pdf');
              },
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
              ),
              title: Text(
                'PDF Document',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                'Best for printing or email',
                style: TextStyle(
                  fontSize: bodyFontSize * 0.8,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.red),
            ),
            SizedBox(height: spacing * 2),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAndShareReceipt(BuildContext context, String format) async {
    setState(() => _isGeneratingReceipt = true);
    
    try {
      if (format == 'image') {
        await _generateImageReceipt(context);
      } else {
        await _generatePdfReceipt(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingReceipt = false);
      }
    }
  }

  Future<void> _generateImageReceipt(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Create a receipt widget to capture
    final receiptWidget = _buildReceiptWidget(isDark);
    
    // Show the receipt in a dialog and capture it
    final Uint8List? imageBytes = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ReceiptCaptureDialog(
        receiptWidget: receiptWidget,
        onCaptured: (bytes) => Navigator.pop(dialogContext, bytes),
      ),
    );
    
    if (imageBytes != null && mounted) {
      // Save to temp file and share
      final tempDir = await getTemporaryDirectory();
      final fileName = 'TCGC_Receipt_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My ${widget.title} receipt from The CityGate Church',
        subject: 'TCGC ${widget.title} Receipt',
      );
    }
  }

  Future<void> _generatePdfReceipt(BuildContext context) async {
    // For PDF, we'll generate a simple text-based share for now
    // You can add pdf package later for proper PDF generation
    final receiptText = '''
THE CITYGATE CHURCH
━━━━━━━━━━━━━━━━━━━━━━
PAYMENT RECEIPT
━━━━━━━━━━━━━━━━━━━━━━

Type: ${widget.title}
Amount: ₦${widget.amount}
Date: ${_formatDate(DateTime.now())}
${widget.reference != null ? 'Reference: ${widget.reference}' : ''}
Recipient: The CityGate Apostolic Kingdom Ministry

━━━━━━━━━━━━━━━━━━━━━━
"Give, and it will be given to you..."
- Luke 6:38
━━━━━━━━━━━━━━━━━━━━━━

Thank you for your generosity!
God bless you abundantly.
''';
    
    await Share.share(
      receiptText,
      subject: 'TCGC ${widget.title} Receipt',
    );
  }

  Widget _buildReceiptWidget(bool isDark) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Church Logo/Header
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.church,
              size: 40,
              color: AppColors.primaryGold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'THE CITYGATE CHURCH',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Payment Receipt',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          // Divider
          Container(
            height: 1,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 20),
          // Success Icon
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              size: 36,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Payment Successful',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 24),
          // Amount
          Text(
            '₦${widget.amount}',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          // Details
          _buildReceiptDetailRow('Date', _formatDate(DateTime.now())),
          const SizedBox(height: 8),
          _buildReceiptDetailRow('To', 'The CityGate Church'),
          if (widget.reference != null) ...[
            const SizedBox(height: 8),
            _buildReceiptDetailRow('Ref', widget.reference!),
          ],
          const SizedBox(height: 24),
          // Divider
          Container(
            height: 1,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          // Quote
          Text(
            '"Give, and it will be given to you..."',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '- Luke 6:38',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Thank you for your generosity!',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[500],
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildConfettiParticle(int index) {
    final colors = [
      AppColors.primaryGold,
      AppColors.success,
      Colors.blue,
      Colors.purple,
      Colors.pink,
      Colors.orange,
    ];

    return AnimatedBuilder(
      animation: _confettiController,
      builder: (context, child) {
        final progress = _confettiController.value;
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;

        final startX = screenWidth / 2;
        final startY = screenHeight * 0.3;

        final distance = 150 + (index % 3) * 50;

        final x = startX + (distance * progress * (index.isEven ? 1 : -1) * 
            (0.5 + (index % 5) * 0.2)) * (index.isEven ? 1 : -1);
        final y = startY + (progress * 300) + (50 * progress * (index % 4));

        final opacity = (1 - progress).clamp(0.0, 1.0);
        final rotation = progress * 6.28 * (index.isEven ? 1 : -1);

        return Positioned(
          left: x,
          top: y,
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: rotation,
              child: Container(
                width: 8 + (index % 3) * 4,
                height: 8 + (index % 3) * 4,
                decoration: BoxDecoration(
                  color: colors[index % colors.length],
                  borderRadius: index % 2 == 0
                      ? BorderRadius.circular(10)
                      : BorderRadius.zero,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


class _ReceiptCaptureDialog extends StatefulWidget {
  final Widget receiptWidget;
  final Function(Uint8List) onCaptured;

  const _ReceiptCaptureDialog({
    required this.receiptWidget,
    required this.onCaptured,
  });

  @override
  State<_ReceiptCaptureDialog> createState() => _ReceiptCaptureDialogState();
}

class _ReceiptCaptureDialogState extends State<_ReceiptCaptureDialog> {
  final GlobalKey _captureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureReceipt());
  }

  Future<void> _captureReceipt() async {
    await Future.delayed(const Duration(milliseconds: 100));
    
    try {
      final boundary = _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          widget.onCaptured(byteData.buffer.asUint8List());
          return;
        }
      }
    } catch (e) {
      debugPrint('Error capturing receipt: $e');
    }
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            key: _captureKey,
            child: widget.receiptWidget,
          ),
          const SizedBox(height: 16),
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Generating receipt...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
