import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/youtube_video.dart';

class VideoPlayerPage extends StatefulWidget {
  final YouTubeVideo video;

  const VideoPlayerPage({super.key, required this.video});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage>
    with WidgetsBindingObserver {
  late YoutubePlayerController _controller;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _controller = YoutubePlayerController(
      initialVideoId: widget.video.id,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
        hideControls: false,
        controlsVisibleAtStart: true,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WakelockPlus.enable();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      WakelockPlus.disable();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _controller.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    if (_isFullScreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Future<void> _openInYouTube() async {
    final url = 'https://www.youtube.com/watch?v=${widget.video.id}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return YoutubePlayerBuilder(
      onExitFullScreen: () {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      },
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppColors.primaryGold,
        progressColors: const ProgressBarColors(
          playedColor: AppColors.primaryGold,
          handleColor: AppColors.primaryGold,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white10,
        ),
        onReady: () {
          _controller.addListener(() {});
        },
        bottomActions: [
          const SizedBox(width: 14.0),
          CurrentPosition(),
          const SizedBox(width: 8.0),
          ProgressBar(
            isExpanded: true,
            colors: const ProgressBarColors(
              playedColor: AppColors.primaryGold,
              handleColor: AppColors.primaryGold,
              bufferedColor: Colors.white24,
              backgroundColor: Colors.white10,
            ),
          ),
          RemainingDuration(),
          const PlaybackSpeedButton(),
          IconButton(
            icon: const Icon(Icons.fullscreen, color: Colors.white),
            onPressed: _toggleFullScreen,
          ),
        ],
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          body: _isFullScreen
              ? player
              : CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      backgroundColor: Colors.black,
                      expandedHeight: MediaQuery.of(context).size.width * 9 / 16,
                      pinned: true,
                      flexibleSpace: FlexibleSpaceBar(
                        background: player,
                      ),
                      leading: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      actions: [
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.open_in_new, color: Colors.white),
                          ),
                          onPressed: _openInYouTube,
                        ),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: _buildVideoDetails(isDark),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildVideoDetails(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.video.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.church, size: 16, color: AppColors.primaryGold),
                    const SizedBox(width: 6),
                    Text(
                      widget.video.channelTitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primaryGold,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.calendar_today,
                size: 14,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 4),
              Text(
                _formatDate(widget.video.publishedAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.video.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        height: 1.5,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildTranscriptSection(isDark),
          const SizedBox(height: 20),
          _buildActionButtons(isDark),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTranscriptSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.subtitles_outlined,
                size: 18,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 8),
              Text(
                'Transcript',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Transcript not available for this video.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: () async {
              final url = 'https://www.youtube.com/watch?v=${widget.video.id}';
              await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
            },
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.open_in_new,
            label: 'Open in YouTube',
            onTap: _openInYouTube,
            isDark: isDark,
            isPrimary: true,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary
              ? AppColors.primaryGold
              : (isDark ? AppColors.cardDark : Colors.grey[200]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isPrimary ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
