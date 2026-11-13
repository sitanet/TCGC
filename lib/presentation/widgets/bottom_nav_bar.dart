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
      mobile: (screenWidth - 20).clamp(320.0, 420.0),
      tablet: 560.0,
      desktop: 620.0,
    );
    final barHeight = Responsive.value(context, mobile: 68.0, tablet: 76.0);
    final iconSize = Responsive.value(context, mobile: showWallet ? 24.0 : 26.0, tablet: 30.0);

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
                  _buildNavItem(0, Icons.home_outlined, Icons.home, iconSize, showWallet),
                  _buildNavItem(1, Icons.music_note_outlined, Icons.music_note, iconSize, showWallet),
                  _buildNavItem(2, Icons.play_circle_outline, Icons.play_circle, iconSize, showWallet),
                  _buildNavItem(3, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, iconSize, showWallet),
                  _buildNavItem(4, Icons.groups_outlined, Icons.groups, iconSize, showWallet),
                  _buildNavItem(5, Icons.forum_outlined, Icons.forum, iconSize, showWallet),
                ]
              : [
                  _buildNavItem(0, Icons.home_outlined, Icons.home, iconSize, showWallet),
                  _buildNavItem(1, Icons.music_note_outlined, Icons.music_note, iconSize, showWallet),
                  _buildNavItem(2, Icons.play_circle_outline, Icons.play_circle, iconSize, showWallet),
                  _buildNavItem(3, Icons.groups_outlined, Icons.groups, iconSize, showWallet),
                  _buildNavItem(4, Icons.forum_outlined, Icons.forum, iconSize, showWallet),
                ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlinedIcon, IconData filledIcon, double iconSize, bool showWallet) {
    final isSelected = currentIndex == index;
    final itemPadding = showWallet ? 16.0 : 20.0;
    
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: iconSize + itemPadding,
        height: iconSize + itemPadding,
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
