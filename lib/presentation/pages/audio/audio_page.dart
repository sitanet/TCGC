import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/services/data_service.dart';
import '../../../data/services/audio_cache_service.dart';
import '../../../domain/entities/sermon.dart';
import '../../widgets/custom_app_bar.dart';
import 'audio_list_page.dart';
import 'favorites_page.dart';
import 'playlists_page.dart';
import 'downloads_page.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({super.key});

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DataService _dataService = DataService();
  final AudioCacheService _audioCacheService = AudioCacheService();
  
  List<MessageCategory> _categories = [];
  List<Sermon> _sermons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _audioCacheService.initialize();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Try to load from cache first for instant display
      final cachedCategories = await _audioCacheService.getCachedCategories();
      final cachedSermons = await _audioCacheService.getCachedSermons();
      
      if (cachedCategories != null && cachedSermons != null && mounted) {
        setState(() {
          _categories = cachedCategories;
          _sermons = cachedSermons;
          _isLoading = false;
        });
        debugPrint('Loaded from cache: ${cachedCategories.length} categories, ${cachedSermons.length} sermons');
      }
      
      // Fetch fresh data from API
      final categories = await _dataService.getMessageCategories();
      final sermons = await _dataService.getMessages();
      
      // Cache the metadata for next time
      _audioCacheService.cacheMetadata(categories: categories, sermons: sermons);
      
      debugPrint('=== Audio Page Data ===');
      debugPrint('Categories loaded: ${categories.length}');
      for (var cat in categories) {
        debugPrint('  Category: ${cat.name} (ID: ${cat.id})');
      }
      debugPrint('Sermons loaded: ${sermons.length}');
      for (var s in sermons) {
        debugPrint('  Sermon: ${s.title} - Category: ${s.category}, CategoryName: ${s.categoryName}');
      }
      
      // Calculate latest message date for each category and sort
      final now = DateTime.now();
      final threeDaysAgo = now.subtract(const Duration(days: 3));
      
      final updatedCategories = categories.map((category) {
        // Find sermons in this category
        final categorySermons = sermons.where((s) => 
          s.category == category.id || s.categoryName == category.name
        ).toList();
        
        // Find the most recent message date
        DateTime? latestDate;
        for (var sermon in categorySermons) {
          if (latestDate == null || sermon.date.isAfter(latestDate)) {
            latestDate = sermon.date;
          }
        }
        
        // Check if there's a new message (within last 3 days)
        final hasNew = latestDate != null && latestDate.isAfter(threeDaysAgo);
        
        return category.copyWith(
          latestMessageDate: latestDate,
          hasNewMessage: hasNew,
        );
      }).toList();
      
      // Sort categories: those with recent messages first, then by latest message date
      updatedCategories.sort((a, b) {
        // Categories with new messages come first
        if (a.hasNewMessage && !b.hasNewMessage) return -1;
        if (!a.hasNewMessage && b.hasNewMessage) return 1;
        
        // Then sort by latest message date (most recent first)
        if (a.latestMessageDate != null && b.latestMessageDate != null) {
          return b.latestMessageDate!.compareTo(a.latestMessageDate!);
        }
        if (a.latestMessageDate != null) return -1;
        if (b.latestMessageDate != null) return 1;
        
        // Finally, sort alphabetically
        return a.name.compareTo(b.name);
      });
      
      if (mounted) {
        setState(() {
          _categories = updatedCategories;
          _sermons = sermons;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading audio data: $e');
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
      appBar: CustomAppBar(
        title: '',
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritesPage()),
            ),
            tooltip: 'Favorites',
          ),
          IconButton(
            icon: const Icon(Icons.playlist_play),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlaylistsPage()),
            ),
            tooltip: 'Playlists',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DownloadsPage()),
            ),
            tooltip: 'Downloads',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabBar(isDark),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCategoryList(context, isDark),
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

    final isTabletOrLarger = !Responsive.isMobile(context);
    final padding = Responsive.horizontalPadding(context);

    if (isTabletOrLarger) {
      return GridView.builder(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: Responsive.gridCrossAxisCount(context, mobile: 1, tablet: 2, desktop: 3),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.5,
        ),
        itemCount: _categories.length,
        itemBuilder: (context, index) => _buildCategoryCard(context, isDark, _categories[index]),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 10),
      itemCount: _categories.length,
      itemBuilder: (context, index) => _buildCategoryCard(context, isDark, _categories[index]),
    );
  }

  Widget _buildCategoryCard(BuildContext context, bool isDark, MessageCategory category) {
    return GestureDetector(
      onTap: () {
        final categoryNameToId = {
          for (var c in _categories) c.name: c.id
        };
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AudioListPage(
              category: category.name,
              categoryId: category.id,
              audioItems: _sermons,
              categories: _categories.map((c) => c.name).toList(),
              categoryNameToId: categoryNameToId,
            ),
          ),
        );
      },
      child: Container(
        margin: Responsive.isMobile(context) ? const EdgeInsets.only(bottom: 16) : EdgeInsets.zero,
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
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildCategoryImage(category, isDark),
                ),
                if (category.hasNewMessage)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      if (category.hasNewMessage)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
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
