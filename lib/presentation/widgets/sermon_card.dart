import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/sermon.dart';

String _stripHtmlTags(String htmlText) {
  return htmlText
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();
}

class SermonCard extends StatelessWidget {
  final Sermon sermon;
  final VoidCallback? onTap;

  const SermonCard({
    super.key,
    required this.sermon,
    this.onTap,
  });

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark ? AppColors.cardDark : AppColors.dividerLight,
      child: Icon(
        Icons.music_note,
        size: 32,
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 80,
                height: 80,
                child: sermon.imageUrl != null && sermon.imageUrl!.startsWith('http')
                    ? Image.network(
                        sermon.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(isDark),
                      )
                    : sermon.imageUrl != null
                        ? Image.asset(
                            sermon.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(isDark),
                          )
                        : _buildPlaceholder(isDark),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sermon.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _stripHtmlTags(sermon.description),
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ],
        ),
      ),
    );
  }
}
