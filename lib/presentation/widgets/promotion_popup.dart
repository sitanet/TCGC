import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/promotion.dart';

class PromotionPopup extends StatefulWidget {
  final List<Promotion> promotions;
  final VoidCallback onClose;

  const PromotionPopup({
    super.key,
    required this.promotions,
    required this.onClose,
  });

  @override
  State<PromotionPopup> createState() => _PromotionPopupState();
}

class _PromotionPopupState extends State<PromotionPopup> with TickerProviderStateMixin {
  int _currentIndex = 0;
  Timer? _autoSlideTimer;
  final PageController _pageController = PageController();
  
  // Breaking effect controllers
  late AnimationController _breakController;
  late AnimationController _contentController;
  late Animation<double> _contentFadeAnimation;
  late Animation<double> _contentScaleAnimation;
  bool _showBreakEffect = true;
  final List<_ShardData> _shards = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initBreakingEffect();
    if (widget.promotions.length > 1) {
      _startAutoSlide();
    }
  }
  
  void _initBreakingEffect() {
    _generateShards();
    
    _breakController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _contentFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );
    
    _contentScaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOutBack),
    );
    
    _breakController.forward().then((_) {
      if (mounted) {
        setState(() => _showBreakEffect = false);
      }
    });
    
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _contentController.forward();
      }
    });
  }
  
  void _generateShards() {
    const int rows = 6;
    const int cols = 5;
    
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        _shards.add(_ShardData(
          row: i,
          col: j,
          rows: rows,
          cols: cols,
          velocityX: (_random.nextDouble() - 0.5) * 800,
          velocityY: _random.nextDouble() * 600 + 200,
          rotation: (_random.nextDouble() - 0.5) * 4,
          delay: _random.nextDouble() * 0.3,
        ));
      }
    }
  }

  void _startAutoSlide() {
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (mounted) {
        final nextIndex = (_currentIndex + 1) % widget.promotions.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    _breakController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Main content with fade/scale animation
          SafeArea(
            child: AnimatedBuilder(
              animation: _contentController,
              builder: (context, child) {
                return Opacity(
                  opacity: _contentFadeAnimation.value,
                  child: Transform.scale(
                    scale: _contentScaleAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: widget.promotions.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return _buildPromotionImage(widget.promotions[index]);
                    },
                  ),
                  
                  // Close button
                  Positioned(
                    top: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  
                  // Page indicators
                  if (widget.promotions.length > 1)
                    Positioned(
                      bottom: 100,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.promotions.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentIndex == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentIndex == index
                                  ? AppColors.primaryGold
                                  : Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  
                  // Link button
                  if (widget.promotions[_currentIndex].linkUrl != null &&
                      widget.promotions[_currentIndex].linkUrl!.isNotEmpty)
                    Positioned(
                      bottom: 32,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: () => _onLinkTap(widget.promotions[_currentIndex]),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGold,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryGold.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.touch_app, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Tap to learn more',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Breaking glass effect overlay
          if (_showBreakEffect)
            ..._shards.map((shard) => _BreakingShard(
              data: shard,
              animation: _breakController,
              screenSize: screenSize,
            )),
        ],
      ),
    );
  }

  Widget _buildPromotionImage(Promotion promotion) {
    return GestureDetector(
      onTap: () => _onLinkTap(promotion),
      child: CachedNetworkImage(
        imageUrl: promotion.imageUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGold),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[900],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported_outlined, size: 64, color: Colors.grey[600]),
              const SizedBox(height: 16),
              Text(
                promotion.title,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              if (promotion.description != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    promotion.description!,
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onLinkTap(Promotion promotion) async {
    if (promotion.linkUrl != null && promotion.linkUrl!.isNotEmpty) {
      final uri = Uri.parse(promotion.linkUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}

class _ShardData {
  final int row;
  final int col;
  final int rows;
  final int cols;
  final double velocityX;
  final double velocityY;
  final double rotation;
  final double delay;

  _ShardData({
    required this.row,
    required this.col,
    required this.rows,
    required this.cols,
    required this.velocityX,
    required this.velocityY,
    required this.rotation,
    required this.delay,
  });
}

class _BreakingShard extends StatelessWidget {
  final _ShardData data;
  final AnimationController animation;
  final Size screenSize;

  const _BreakingShard({
    required this.data,
    required this.animation,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    final shardWidth = screenSize.width / data.cols;
    final shardHeight = screenSize.height / data.rows;
    final startX = data.col * shardWidth;
    final startY = data.row * shardHeight;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = ((animation.value - data.delay) / (1.0 - data.delay)).clamp(0.0, 1.0);
        final eased = Curves.easeIn.transform(progress);
        
        final dx = data.velocityX * eased;
        final dy = data.velocityY * eased + (500 * eased * eased);
        final opacity = (1.0 - eased).clamp(0.0, 1.0);
        final rotationAngle = data.rotation * eased;

        return Positioned(
          left: startX + dx,
          top: startY + dy,
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: rotationAngle,
              child: Container(
                width: shardWidth + 2,
                height: shardHeight + 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.9),
                      Colors.grey[300]!.withOpacity(0.8),
                      Colors.white.withOpacity(0.7),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
                child: CustomPaint(painter: _CrackPainter()),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CrackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.3);
    path.lineTo(size.width * 0.4, size.height * 0.5);
    path.lineTo(size.width, size.height * 0.7);
    
    path.moveTo(size.width * 0.6, 0);
    path.lineTo(size.width * 0.5, size.height * 0.5);
    path.lineTo(size.width * 0.3, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
