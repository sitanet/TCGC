import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spacing = Responsive.verticalSpacing(context);
    final borderRadius = Responsive.largeBorderRadius(context);
    
    return Container(
      margin: EdgeInsets.all(spacing),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppColors.primaryGold.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing, vertical: spacing * 0.875),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, 0, 'assets/images/nav_home.png'),
            _buildNavItem(context, 1, 'assets/images/nav_audio.png'),
            _buildNavItem(context, 2, 'assets/images/nav_streaming.png'),
            _buildNavItem(context, 3, 'assets/images/nav_wallet.png'),
            _buildNavItem(context, 4, 'assets/images/nav_teens.png'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, String iconPath) {
    final isSelected = currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconSize = Responsive.navIconSize(context);
    final spacing = Responsive.verticalSpacing(context);
    
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: spacing * 0.75, vertical: spacing * 0.5),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primaryGold.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(Responsive.borderRadius(context)),
          border: isSelected
              ? Border.all(color: AppColors.primaryGold, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              iconPath,
              width: iconSize,
              height: iconSize,
              color: isSelected 
                  ? AppColors.primaryGold 
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.primaryGold,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
