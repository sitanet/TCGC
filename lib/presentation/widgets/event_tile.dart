import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/event.dart';

class EventTile extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;

  const EventTile({
    super.key,
    required this.event,
    this.onTap,
  });

  Color _getIconColor() {
    switch (event.iconColor) {
      case 'gold':
        return AppColors.primaryGold;
      case 'maroon':
        return const Color(0xFF8B0000);
      case 'blue':
        return const Color(0xFF3B82F6);
      case 'orange':
        return AppColors.orange;
      case 'teal':
        return AppColors.teal;
      default:
        return AppColors.primaryGold;
    }
  }

  IconData _getIcon() {
    switch (event.iconColor) {
      case 'gold':
        return Icons.church;
      case 'maroon':
        return Icons.menu_book;
      case 'blue':
        return Icons.school;
      case 'orange':
        return Icons.auto_stories;
      case 'teal':
        return Icons.groups;
      default:
        return Icons.church;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = _getIconColor();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIcon(),
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.schedule,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (event.isLive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.liveRed,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              Icon(
                Icons.access_time_outlined,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
