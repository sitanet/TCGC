import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

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
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, 0, Icons.home_outlined, Icons.home_rounded),
            _buildNavItem(context, 1, Icons.music_note_outlined, Icons.music_note_rounded),
            _buildNavItem(context, 2, Icons.stream_outlined, Icons.stream),
            _buildNavItem(context, 3, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded),
            _buildNavItem(context, 4, Icons.groups_outlined, Icons.groups),
            _buildNavItem(context, 5, Icons.settings_outlined, Icons.settings),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, IconData activeIcon) {
    final isSelected = currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primaryGold.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected 
              ? AppColors.primaryGold 
              : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
          size: 26,
        ),
      ),
    );
  }
}
