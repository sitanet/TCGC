import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_cache_manager.dart';
import '../../../data/services/download_service.dart';
import '../../../data/services/playback_position_service.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';
import 'audio_player_page.dart';
import '../../widgets/resume_playback_sheet.dart';

class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({super.key});

  @override
  ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends ConsumerState<DownloadsPage> {
  final DownloadService _downloadService = DownloadService();
  final PlaybackPositionService _positionService = PlaybackPositionService();
  int _totalSize = 0;
  
  String _formatDateTitle(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _downloadService.initialize();
    await _positionService.initialize();
    _downloadService.addListener(_onDownloadsChanged);
    _totalSize = await _downloadService.getTotalSize();
    if (mounted) setState(() {});
  }

  void _onDownloadsChanged() async {
    _totalSize = await _downloadService.getTotalSize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _downloadService.removeListener(_onDownloadsChanged);
    super.dispose();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final downloads = _downloadService.downloads;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Downloads',
        actions: downloads.isNotEmpty
            ? [
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'clear_all') {
                      _showClearAllDialog(context);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'clear_all',
                      child: Row(
                        children: [
                          Icon(Icons.delete_sweep, size: 20, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Clear All', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ]
            : null,
      ),
      body: downloads.isEmpty
          ? _buildEmptyState(context, isDark)
          : Column(
              children: [
                // Storage info
                Container(
                  padding: const EdgeInsets.all(16),
                  color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
                  child: Row(
                    children: [
                      Icon(
                        Icons.storage,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${downloads.length} downloads • ${_formatSize(_totalSize)}',
                        style: TextStyle(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: downloads.length,
                    itemBuilder: (context, index) {
                      final download = downloads[index];
                      return _buildDownloadTile(context, download, isDark);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.download_done,
            size: 64,
            color: isDark 
                ? AppColors.textSecondaryDark.withValues(alpha: 0.5)
                : AppColors.textSecondaryLight.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No downloads yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Downloaded messages will appear here for offline listening',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadTile(BuildContext context, DownloadedSermon download, bool isDark) {
    final sermon = download.sermon;
    final savedPosition = _positionService.getPosition(sermon.id);
    final hasResume = savedPosition != null && savedPosition.isSignificant;
    
    return Dismissible(
      key: Key(sermon.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        _downloadService.deleteDownload(sermon.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${sermon.title}"')),
        );
      },
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Container(
                width: 50,
                height: 50,
                color: isDark ? AppColors.cardDark : AppColors.dividerLight,
                child: sermon.imageUrl != null && sermon.imageUrl!.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: sermon.imageUrl!,
                        cacheManager: CustomImageCacheManager.instance,
                        fit: BoxFit.cover,
                        useOldImageOnUrlChange: true,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        placeholder: (_, __) => _buildPlaceholder(isDark),
                        errorWidget: (_, __, ___) => _buildPlaceholder(isDark),
                      )
                    : _buildPlaceholder(isDark),
              ),
              if (hasResume)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: savedPosition.progress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        title: Text(
          '${_formatDateTitle(sermon.date)} - ${sermon.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_formatSize(download.fileSize)} • ${sermon.speaker ?? sermon.categoryName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (hasResume)
              Text(
                'Resume at ${savedPosition.formattedPosition} / ${savedPosition.formattedDuration}',
                style: TextStyle(
                  color: AppColors.primaryGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasResume)
              IconButton(
                icon: Icon(Icons.play_circle_filled, color: AppColors.primaryGold, size: 28),
                onPressed: () {
                  ResumePlaybackHelper.handleMessageTap(
                    context: context,
                    ref: ref,
                    sermon: sermon,
                  );
                },
                tooltip: 'Resume',
              )
            else
              const Icon(Icons.download_done, color: Colors.green, size: 20),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _showDeleteDialog(context, download),
            ),
          ],
        ),
        onTap: () {
          ResumePlaybackHelper.handleMessageTap(
            context: context,
            ref: ref,
            sermon: sermon,
          );
        },
      ),
    );
  }
  
  Widget _buildPlaceholder(bool isDark) {
    return Icon(
      Icons.music_note,
      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
    );
  }

  void _showDeleteDialog(BuildContext context, DownloadedSermon download) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Download?'),
        content: Text('Delete "${download.sermon.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _downloadService.deleteDownload(download.sermon.id);
              if (mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear All Downloads?'),
        content: const Text('This will delete all downloaded messages. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _downloadService.clearAllDownloads();
              if (mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
