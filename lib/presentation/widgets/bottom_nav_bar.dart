import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool showWallet;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.showWallet = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Account for system navigation bar (gesture bar) height on edge-to-edge
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive sizing: on phones keep compact floating pill; on tablets scale up gracefully
    final barWidth = Responsive.value(
      context,
      mobile: (screenWidth - 32).clamp(320.0, 390.0),
      tablet: 520.0,
      desktop: 580.0,
    );
    final barHeight = Responsive.value(context, mobile: 68.0, tablet: 76.0);
    final iconSize = Responsive.value(context, mobile: 28.0, tablet: 32.0);

    return Center(
      child: Container(
        width: barWidth,
        height: barHeight,
        margin: EdgeInsets.only(bottom: 14 + bottomInset),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(52),
          border: Border.all(
            color: AppColors.primaryGold.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: showWallet
              ? [
                  _buildNavItem(0, Icons.home_outlined, Icons.home, iconSize),
                  _buildNavItem(1, Icons.music_note_outlined, Icons.music_note, iconSize),
                  _buildNavItem(2, Icons.play_circle_outline, Icons.play_circle, iconSize),
                  _buildNavItem(3, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, iconSize),
                  _buildNavItem(4, Icons.groups_outlined, Icons.groups, iconSize),
                ]
              : [
                  _buildNavItem(0, Icons.home_outlined, Icons.home, iconSize),
                  _buildNavItem(1, Icons.music_note_outlined, Icons.music_note, iconSize),
                  _buildNavItem(2, Icons.play_circle_outline, Icons.play_circle, iconSize),
                  _buildNavItem(3, Icons.groups_outlined, Icons.groups, iconSize),
                ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlinedIcon, IconData filledIcon, double iconSize) {
    final isSelected = currentIndex == index;
    
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: iconSize + 22,
        height: iconSize + 22,
        decoration: isSelected
            ? BoxDecoration(
                color: AppColors.primaryGold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              )
            : null,
        child: Center(
          child: Icon(
            isSelected ? filledIcon : outlinedIcon,
            size: iconSize,
            color: AppColors.primaryGold,
          ),
        ),
      ),
    );
  }
}
