import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/audio_player_provider.dart';
import '../../../domain/entities/sermon.dart';
import '../../../data/services/favorites_service.dart';
import '../../../data/services/playlist_service.dart';
import '../../../data/services/download_service.dart';
import '../../../data/services/data_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../wallet/give_page.dart';

class AudioPlayerPage extends StatefulWidget {
  final Sermon sermon;

  const AudioPlayerPage({super.key, required this.sermon});

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> {
  final FavoritesService _favoritesService = FavoritesService();
  final PlaylistService _playlistService = PlaylistService();
  final DownloadService _downloadService = DownloadService();
  final DataService _dataService = DataService();

  @override
  void initState() {
    super.initState();
    _initializeServices();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audioProvider = Provider.of<AudioPlayerProvider>(context, listen: false);
      if (audioProvider.currentSermon?.id != widget.sermon.id) {
        audioProvider.playSermon(widget.sermon);
      }
    });
  }

  Future<void> _initializeServices() async {
    await _favoritesService.initialize();
    await _playlistService.initialize();
    await _downloadService.initialize();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<AudioPlayerProvider>(
      builder: (context, audioProvider, child) {
        final errorMessage = audioProvider.errorMessage;

        return Scaffold(
          appBar: CustomAppBar(
            title: widget.sermon.categoryName.isNotEmpty
                ? widget.sermon.categoryName
                : widget.sermon.category,
            actions: [
              IconButton(
                onPressed: () => _showGivingBottomSheet(context, isDark),
                icon: Icon(
                  Icons.volunteer_activism,
                  color: AppColors.primaryGold,
                ),
                tooltip: 'Give an Offering',
              ),
              IconButton(
                onPressed: () => _showActionsBottomSheet(context, isDark),
                icon: const Icon(Icons.more_vert),
                tooltip: 'More options',
              ),
            ],
          ),
          body: errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.withOpacity(0.7),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => audioProvider.playSermon(widget.sermon),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Spacer(),
                      _buildAlbumArt(isDark),
                      const SizedBox(height: 32),
                      _buildSongInfo(context),
                      const SizedBox(height: 32),
                      _buildProgressBar(isDark, audioProvider),
                      const SizedBox(height: 24),
                      _buildControls(isDark, audioProvider),
                      const SizedBox(height: 32),
                      _buildGivingButton(context, isDark),
                      const Spacer(flex: 2),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildAlbumArt(bool isDark) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? AppColors.cardDark : AppColors.dividerLight,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _buildAlbumImage(isDark),
      ),
    );
  }

  Widget _buildAlbumImage(bool isDark) {
    if (widget.sermon.imageUrl == null || widget.sermon.imageUrl!.isEmpty) {
      return _buildPlaceholderArt(isDark);
    }
    if (widget.sermon.imageUrl!.startsWith('http')) {
      return Image.network(
        widget.sermon.imageUrl!,
        fit: BoxFit.cover,
        width: 280,
        height: 280,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderArt(isDark),
      );
    }
    return Image.asset(
      widget.sermon.imageUrl!,
      fit: BoxFit.cover,
      width: 280,
      height: 280,
      errorBuilder: (context, error, stackTrace) => _buildPlaceholderArt(isDark),
    );
  }

  Widget _buildPlaceholderArt(bool isDark) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryGold.withOpacity(0.3),
                isDark ? AppColors.cardDark : AppColors.surfaceLight,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Center(
          child: Icon(
            Icons.music_note,
            size: 80,
            color: AppColors.primaryGold.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildSongInfo(BuildContext context) {
    return Column(
      children: [
        Text(
          widget.sermon.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          widget.sermon.categoryName.isNotEmpty
              ? widget.sermon.categoryName
              : widget.sermon.category,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildProgressBar(bool isDark, AudioPlayerProvider audioProvider) {
    final duration = audioProvider.duration;
    final position = audioProvider.position;
    final durationMs = duration.inMilliseconds.toDouble();
    final positionMs = position.inMilliseconds.toDouble();
    final sliderValue = durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: AppColors.primaryGold,
            inactiveTrackColor: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            thumbColor: AppColors.primaryGold,
            overlayColor: AppColors.primaryGold.withOpacity(0.2),
          ),
          child: Slider(
            value: sliderValue,
            onChanged: (value) {
              final newPosition = Duration(
                milliseconds: (value * durationMs).toInt(),
              );
              audioProvider.seek(newPosition);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: TextStyle(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  fontSize: 12,
                ),
              ),
              Text(
                _formatDuration(duration),
                style: TextStyle(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControls(bool isDark, AudioPlayerProvider audioProvider) {
    final isPlaying = audioProvider.isPlaying;
    final isLoading = audioProvider.isLoading;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: isLoading ? null : () => audioProvider.seekBackward(),
          icon: Icon(
            Icons.replay_10,
            size: 36,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(width: 24),
        GestureDetector(
          onTap: isLoading ? null : () {
            if (isPlaying) {
              audioProvider.pause();
            } else {
              audioProvider.play();
            }
          },
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.primaryGold,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGold.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 36,
                  ),
          ),
        ),
        const SizedBox(width: 24),
        IconButton(
          onPressed: isLoading ? null : () => audioProvider.seekForward(),
          icon: Icon(
            Icons.forward_10,
            size: 36,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showActionsBottomSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final isFavorite = _favoritesService.isFavorite(widget.sermon.id);
          final isDownloaded = _downloadService.isDownloaded(widget.sermon.id);
          final isDownloading = _downloadService.isDownloading(widget.sermon.id);
          final downloadProgress = _downloadService.getProgress(widget.sermon.id);

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    widget.sermon.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Divider(),
                // Favorite
                ListTile(
                  leading: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : null,
                  ),
                  title: Text(isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
                  onTap: () async {
                    await _favoritesService.toggleFavorite(widget.sermon);
                    // Track favorite action to backend
                    _trackMessageStat('favorite', !isFavorite);
                    setModalState(() {});
                    setState(() {});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isFavorite ? 'Removed from favorites' : 'Added to favorites',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                // Playlist
                ListTile(
                  leading: const Icon(Icons.playlist_add),
                  title: const Text('Add to Playlist'),
                  onTap: () {
                    Navigator.pop(context);
                    _showPlaylistBottomSheet(context, isDark);
                  },
                ),
                // Download
                ListTile(
                  leading: Icon(
                    isDownloaded
                        ? Icons.download_done
                        : (isDownloading ? Icons.downloading : Icons.download),
                    color: isDownloaded ? Colors.green : null,
                  ),
                  title: Text(
                    isDownloaded
                        ? 'Downloaded'
                        : (isDownloading
                            ? 'Downloading ${(downloadProgress * 100).toInt()}%'
                            : 'Download'),
                  ),
                  onTap: isDownloading
                      ? null
                      : () async {
                          if (isDownloaded) {
                            Navigator.pop(context);
                            _showDeleteDownloadDialog(context, isDark);
                          } else {
                            Navigator.pop(context);
                            final success = await _downloadService.downloadSermon(widget.sermon);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success ? 'Download started' : 'Download failed',
                                  ),
                                ),
                              );
                              setState(() {});
                            }
                          }
                        },
                ),
                // Share
                ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text('Share'),
                  onTap: () {
                    Navigator.pop(context);
                    _shareSermon();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _trackMessageStat(String action, bool added) async {
    try {
      await _dataService.trackMessageStat(
        messageId: widget.sermon.id,
        action: action,
        added: added,
      );
    } catch (e) {
      debugPrint('Failed to track message stat: $e');
    }
  }

  void _shareSermon() {
    final sermon = widget.sermon;
    final shareText = '''
Check out this message: "${sermon.title}"

${sermon.description}

Listen on TCGC App
''';
    Share.share(shareText, subject: sermon.title);
    // Track share action to backend
    _trackMessageStat('share', true);
  }

  void _showDeleteDownloadDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Download?'),
        content: const Text('This will remove the downloaded file from your device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _downloadService.deleteDownload(widget.sermon.id);
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Download deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showPlaylistBottomSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add to Playlist',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showCreatePlaylistDialog(context, isDark, setModalState),
                    icon: const Icon(Icons.add),
                    label: const Text('New'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_playlistService.playlists.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.playlist_play,
                          size: 48,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No playlists yet',
                          style: TextStyle(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _showCreatePlaylistDialog(context, isDark, setModalState),
                          child: const Text('Create your first playlist'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _playlistService.playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = _playlistService.playlists[index];
                      final isInPlaylist = _playlistService.isInPlaylist(
                        playlist.id, 
                        widget.sermon.id,
                      );
                      return ListTile(
                        leading: Icon(
                          isInPlaylist ? Icons.playlist_add_check : Icons.playlist_play,
                          color: isInPlaylist ? AppColors.primaryGold : null,
                        ),
                        title: Text(playlist.name),
                        subtitle: Text('${playlist.count} songs'),
                        trailing: isInPlaylist
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        onTap: () async {
                          if (isInPlaylist) {
                            await _playlistService.removeFromPlaylist(
                              playlist.id, 
                              widget.sermon.id,
                            );
                          } else {
                            await _playlistService.addToPlaylist(
                              playlist.id, 
                              widget.sermon,
                            );
                          }
                          setModalState(() {});
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isInPlaylist 
                                      ? 'Removed from ${playlist.name}'
                                      : 'Added to ${playlist.name}',
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, bool isDark, StateSetter setModalState) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final playlist = await _playlistService.createPlaylist(name);
                await _playlistService.addToPlaylist(playlist.id, widget.sermon);
                if (mounted) {
                  Navigator.pop(dialogContext);
                  setModalState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added to "$name"')),
                  );
                }
              }
            },
            child: const Text('Create & Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildGivingButton(BuildContext context, bool isDark) {
    return TextButton.icon(
      onPressed: () => _showGivingBottomSheet(context, isDark),
      icon: Icon(
        Icons.volunteer_activism,
        color: AppColors.primaryGold,
        size: 20,
      ),
      label: Text(
        'Blessed? Give an Offering',
        style: TextStyle(
          color: AppColors.primaryGold,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showGivingBottomSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(
              Icons.volunteer_activism,
              size: 64,
              color: AppColors.primaryGold,
            ),
            const SizedBox(height: 16),
            Text(
              'Are you blessed by this ministration?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Give an offering by clicking below',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GivePage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Give Special Offering',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Maybe Later',
                style: TextStyle(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
