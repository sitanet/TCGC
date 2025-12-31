import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/custom_app_bar.dart';

class VideoItem {
  final String title;
  final String imageUrl;
  bool isPlaying;

  VideoItem({
    required this.title,
    required this.imageUrl,
    this.isPlaying = false,
  });
}

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<VideoItem> _videoItems = [
    VideoItem(
      title: 'Pre-Conference Service - The Son of God and The Reign of Righteousness',
      imageUrl: 'assets/images/video_thumbnail.png',
    ),
  ];

  final List<VideoItem> _audioItems = [
    VideoItem(
      title: "Believers' Meeting - Questions and Answers",
      imageUrl: 'assets/images/believers_meeting.png',
    ),
    VideoItem(
      title: 'Morning Devotion - Grace and Mercy',
      imageUrl: 'assets/images/morning_devotion.png',
    ),
    VideoItem(
      title: 'Evening Prayer - Seeking His Face',
      imageUrl: 'assets/images/evening_prayer.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(
        title: '',
        showBackButton: true,
      ),
      body: Column(
        children: [
          _buildTabBar(isDark),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAudioTab(isDark),
                _buildVideoTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: Colors.transparent,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.primaryGold,
        unselectedLabelColor:
            isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Audio'),
          Tab(text: 'Video'),
        ],
      ),
    );
  }

  Widget _buildVideoTab(bool isDark) {
    final item = _videoItems.first;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: _buildMediaCard(item, isDark),
      ),
    );
  }

  Widget _buildAudioTab(bool isDark) {
    return _buildMediaList(_audioItems, isDark);
  }

  Widget _buildMediaList(List<VideoItem> items, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildMediaCard(items[index], isDark);
      },
    );
  }

  Widget _buildMediaCard(VideoItem item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.asset(
                  item.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryGold.withValues(alpha: 0.3),
                            AppColors.primaryGold.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.video_library,
                              size: 48,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                item.title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildPlaybackControls(item, isDark),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls(VideoItem item, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () {},
          icon: Icon(
            Icons.fast_rewind,
            size: 28,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            setState(() {
              item.isPlaying = !item.isPlaying;
            });
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.isPlaying ? Icons.pause : Icons.play_arrow,
              color: isDark
                  ? AppColors.textPrimaryLight
                  : AppColors.surfaceLight,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {},
          icon: Icon(
            Icons.fast_forward,
            size: 28,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }

}
