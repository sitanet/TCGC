import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/teens_content.dart';
import '../../widgets/custom_app_bar.dart';

class TeensContentDetailPage extends StatelessWidget {
  final TeensContent content;
  final Color accentColor;

  const TeensContentDetailPage({
    super.key,
    required this.content,
    required this.accentColor,
  });

  void _shareContent() {
    final shareText = '''
${content.title}

${content.description}

Category: ${content.category}
''';
    Share.share(shareText, subject: content.title);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        title: content.category,
        showBackButton: true,
        actions: [
          IconButton(
            onPressed: _shareContent,
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThumbnail(context),
            _buildContent(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailImage() {
    Widget placeholder = Container(
      height: 220,
      width: double.infinity,
      color: accentColor.withValues(alpha: 0.2),
      child: Icon(
        Icons.image_outlined,
        size: 64,
        color: accentColor,
      ),
    );

    if (content.thumbnailUrl == null || content.thumbnailUrl!.isEmpty) {
      return placeholder;
    }
    if (content.thumbnailUrl!.startsWith('http')) {
      return Image.network(
        content.thumbnailUrl!,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }
    return Image.asset(
      content.thumbnailUrl!,
      height: 220,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    return Stack(
      children: [
        _buildThumbnailImage(),
        Container(
          height: 220,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  content.category,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                content.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetaInfo(context, isDark),
          const SizedBox(height: 24),
          Text(
            'About',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            content.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  height: 1.6,
                ),
          ),
          const SizedBox(height: 32),
          _buildActionButtons(context, isDark),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildMetaInfo(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetaItem(
            context,
            isDark,
            Icons.calendar_today_outlined,
            'Date',
            _formatDate(content.date),
          ),
          Container(
            height: 40,
            width: 1,
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
          _buildMetaItem(
            context,
            isDark,
            Icons.access_time_outlined,
            'Duration',
            content.duration != null
                ? _formatDuration(content.duration!)
                : 'N/A',
          ),
          Container(
            height: 40,
            width: 1,
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
          _buildMetaItem(
            context,
            isDark,
            Icons.category_outlined,
            'Type',
            _getContentType(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(BuildContext context, bool isDark, IconData icon,
      String label, String value) {
    return Column(
      children: [
        Icon(
          icon,
          color: accentColor,
          size: 20,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isDark) {
    return Column(
      children: [
        if (content.videoUrl != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Video playback coming soon'),
                    backgroundColor: AppColors.primaryGold,
                  ),
                );
              },
              icon: const Icon(Icons.play_circle_filled, color: Colors.white),
              label: const Text(
                'Watch Video',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (content.videoUrl != null && content.audioUrl != null)
          const SizedBox(height: 12),
        if (content.audioUrl != null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Audio playback coming soon'),
                    backgroundColor: AppColors.primaryGold,
                  ),
                );
              },
              icon: Icon(Icons.headphones, color: accentColor),
              label: Text(
                'Listen to Audio',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accentColor),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (content.videoUrl == null && content.audioUrl == null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Content details viewed'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              icon: const Icon(Icons.bookmark_add_outlined, color: Colors.white),
              label: const Text(
                'Save for Later',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _shareContent,
            icon: Icon(Icons.share_outlined, color: accentColor),
            label: Text(
              'Share Content',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: accentColor),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      final minutes = duration.inMinutes % 60;
      return '${duration.inHours}h ${minutes}m';
    }
    return '${duration.inMinutes} min';
  }

  String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _getContentType() {
    if (content.videoUrl != null) return 'Video';
    if (content.audioUrl != null) return 'Audio';
    return 'Article';
  }
}
