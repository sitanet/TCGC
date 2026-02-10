import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AnimatedPlayButton extends StatefulWidget {
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback? onTap;
  final double size;

  const AnimatedPlayButton({
    super.key,
    required this.isPlaying,
    required this.isLoading,
    this.onTap,
    this.size = 70,
  });

  @override
  State<AnimatedPlayButton> createState() => _AnimatedPlayButtonState();
}

class _AnimatedPlayButtonState extends State<AnimatedPlayButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isLoading) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedPlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _controller.repeat(reverse: true);
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isLoading ? null : widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isLoading ? _scaleAnimation.value : 1.0,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: AppColors.primaryGold,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGold.withOpacity(
                      widget.isLoading ? 0.4 * _pulseAnimation.value : 0.4,
                    ),
                    blurRadius: widget.isLoading ? 20 * _pulseAnimation.value : 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: widget.isLoading
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: widget.size * 0.5,
                          height: widget.size * 0.5,
                          child: CircularProgressIndicator(
                            color: Colors.white.withOpacity(0.9),
                            strokeWidth: 3,
                          ),
                        ),
                        Icon(
                          Icons.play_arrow,
                          color: Colors.white.withOpacity(0.5),
                          size: widget.size * 0.4,
                        ),
                      ],
                    )
                  : Icon(
                      widget.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: widget.size * 0.5,
                    ),
            ),
          );
        },
      ),
    );
  }
}
