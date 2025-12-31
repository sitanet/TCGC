import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/data_service.dart';
import '../../../domain/entities/sermon.dart';
import '../../widgets/custom_app_bar.dart';
import 'audio_list_page.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({super.key});

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DataService _dataService = DataService();
  
  List<MessageCategory> _categories = [];
  List<Sermon> _sermons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _dataService.getMessageCategories();
      final sermons = await _dataService.getMessages();
      if (mounted) {
        setState(() {
          _categories = categories;
          _sermons = sermons;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading audio data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
        showBackButton: false,
      ),
      body: Column(
        children: [
          _buildTabBar(isDark),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCategoryList(context, isDark),
                _buildVideoList(context, isDark),
                _buildTranscriptList(context, isDark),
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
          Tab(text: 'Transcript'),
        ],
      ),
    );
  }

  Widget _buildCategoryList(BuildContext context, bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off,
              size: 64,
              color: isDark
                  ? AppColors.textSecondaryDark.withValues(alpha: 0.5)
                  : AppColors.textSecondaryLight.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No audio categories available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AudioListPage(
                  category: category.name,
                  audioItems: _sermons,
                  categories: _categories.map((c) => c.name).toList(),
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildCategoryImage(category, isDark),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category.description ?? 'Listen to messages from this category',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryImage(MessageCategory category, bool isDark) {
    Widget placeholder = Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.dividerLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.music_note,
        size: 32,
        color: AppColors.primaryGold.withValues(alpha: 0.5),
      ),
    );

    if (category.imageUrl == null || category.imageUrl!.isEmpty) {
      return placeholder;
    }

    if (category.imageUrl!.startsWith('http')) {
      return Image.network(
        category.imageUrl!,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }

    return Image.asset(
      category.imageUrl!,
      width: 80,
      height: 80,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }

  Widget _buildVideoList(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Video Sermons',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Watch sermon videos from D-City Gate Church',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
          ),
          const SizedBox(height: 24),
          _buildYouTubeCard(context, isDark),
        ],
      ),
    );
  }

  Widget _buildYouTubeCard(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse('https://www.youtube.com/@dcitygatechurch/videos');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(
                  colors: [
                    Colors.red.shade700,
                    Colors.red.shade500,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'YouTube',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'D-City Gate Church',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Watch all our video sermons on YouTube',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.open_in_new,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscriptList(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 80,
              color: isDark
                  ? AppColors.textSecondaryDark.withValues(alpha: 0.5)
                  : AppColors.textSecondaryLight.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Transcripts',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sermon transcripts will be available here soon. Stay tuned for written versions of our messages.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
