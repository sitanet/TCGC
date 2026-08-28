import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Flying eagle animation indicator for AI response with moving wings
class LoadingIndicator extends StatefulWidget {
  const LoadingIndicator({Key? key}) : super(key: key);

  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _flightController;
  late AnimationController _wingFlapController;
  late AnimationController _glowController;
  late Animation<double> _flightAnimation;
  late Animation<double> _wingScaleX;
  late Animation<double> _wingScaleY;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    // Gentle soaring vertical motion (smooth floating oscillation)
    _flightController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    // Realistic wing flapping motion
    _wingFlapController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..repeat(reverse: true);

    // Subtle golden glow pulse
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _flightAnimation = CurvedAnimation(
      parent: _flightController,
      curve: Curves.easeInOutSine,
    );

    // Wing flapping curves (expands and contracts wings rhythmically)
    _wingScaleX = Tween<double>(begin: 0.88, end: 1.15).animate(
      CurvedAnimation(parent: _wingFlapController, curve: Curves.easeInOut),
    );
    _wingScaleY = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _wingFlapController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flightController.dispose();
    _wingFlapController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222A) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: primaryColor.withOpacity(0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Moving Golden Eagle Wings Animation
            AnimatedBuilder(
              animation: Listenable.merge([_flightAnimation, _wingScaleX, _wingScaleY, _glowAnimation]),
              builder: (context, child) {
                final verticalOffset = (_flightAnimation.value - 0.5) * 6.0;
                
                return Transform.translate(
                  offset: Offset(0, verticalOffset),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE5A93C).withOpacity(_glowAnimation.value * 0.4),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..scale(_wingScaleX.value, _wingScaleY.value),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/wing_ai_eagle.jpg',
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: primaryColor.withOpacity(0.1),
                            child: Icon(
                              Icons.flight,
                              color: primaryColor,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 14),
            
            // Text indicator
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Wing AI',
                      style: TextStyle(
                        fontSize: 13,
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                AnimatedBuilder(
                  animation: _flightController,
                  builder: (context, child) {
                    final dotCount = ((_flightController.value * 3.9)).floor() % 3 + 1;
                    final dots = '.' * dotCount;
                    
                    return Text(
                      'Soaring in the Word$dots',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
