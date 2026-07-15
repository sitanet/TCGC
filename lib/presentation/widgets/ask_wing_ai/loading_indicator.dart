import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Flying eagle animation indicator for AI response
class LoadingIndicator extends StatefulWidget {
  const LoadingIndicator({Key? key}) : super(key: key);

  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _flightController;
  late AnimationController _wingController;
  late Animation<double> _flightAnimation;
  late Animation<double> _wingAnimation;

  @override
  void initState() {
    super.initState();
    
    // Flight path animation (circular motion)
    _flightController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    // Wing flapping animation
    _wingController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..repeat(reverse: true);

    _flightAnimation = _flightController.drive(
      Tween<double>(begin: 0, end: 2 * 3.14159), // Full circle in radians
    );

    _wingAnimation = _wingController.drive(
      Tween<double>(begin: 0.8, end: 1.2), // Scale for wing flapping
    );
  }

  @override
  void dispose() {
    _flightController.dispose();
    _wingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).primaryColor.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Flying Eagle Animation
            SizedBox(
              width: 40,
              height: 40,
              child: AnimatedBuilder(
                animation: Listenable.merge([_flightAnimation, _wingAnimation]),
                builder: (context, child) {
                  // Calculate circular position
                  final radius = 12.0;
                  final x = radius * (1 + 0.8 * math.cos(_flightAnimation.value));
                  final y = radius * (1 + 0.6 * math.sin(_flightAnimation.value));
                  
                  return Stack(
                    children: [
                      // Eagle with circular flight path
                      Positioned(
                        left: x,
                        top: y,
                        child: Transform.scale(
                          scale: _wingAnimation.value,
                          child: Transform.rotate(
                            angle: _flightAnimation.value * 0.5, // Slight rotation during flight
                            child: Icon(
                              Icons.flutter_dash,
                              color: Theme.of(context).primaryColor,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            
            // Church-themed loading text
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Wing AI • CityGate Family',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                AnimatedBuilder(
                  animation: _flightController,
                  builder: (context, child) {
                    // Create dots animation for "praying"
                    final dotCount = ((_flightController.value * 3) % 3).floor() + 1;
                    final dots = '.' * dotCount;
                    
                    return Text(
                      'Praying for wisdom$dots',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
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
