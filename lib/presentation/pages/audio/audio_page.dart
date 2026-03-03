import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/services/data_service.dart';
import '../../../data/services/audio_cache_service.dart';
import '../../../domain/entities/sermon.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';
import 'audio_list_page.dart';
import 'favorites_page.dart';
import 'playlists_page.dart';
import 'downloads_page.dart';
import 'transcript_list_page.dart';

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

class AudioPage extends ConsumerStatefulWidget {
  const AudioPage({super.key});

  @override
  ConsumerState<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends ConsumerState<AudioPage>
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
    // Load data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _audioCacheService.initialize();
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Get user permissions for filtering
      final authProvider = ref.read(authChangeNotifierProvider);
      final user = authProvider.user;
      final isServiceTeamMember = user?.isServiceTeamMember ?? false;
      final isGeneralMarried = user?.isGeneralMarried ?? false;
      final isInHouseMarried = user?.isInHouseMarried ?? false;
      
      // Try to load from cache first for instant display
      final cachedCategories = await _audioCacheService.getCachedCategories();
      final cachedSermons = await _audioCacheService.getCachedSermons();
      
      if (cachedCategories != null && cachedSermons != null && mounted) {
        // Filter cached sermons based on user permissions
        final filteredSermons = cachedSermons.where((sermon) {
          if (sermon.isServiceTeamOnly && !isServiceTeamMember) return false;
          if (sermon.isGeneralMarriedOnly && !isGeneralMarried) return false;
          if (sermon.isInHouseMarriedOnly && !isInHouseMarried) return false;
          return true;
        }).toList();
        
        setState(() {
          _categories = cachedCategories;
          _sermons = filteredSermons;
          _isLoading = false;
        });
        debugPrint('Loaded from cache: ${cachedCategories.length} categories, ${filteredSermons.length} sermons (filtered)');
        // Fetch fresh data in background to get new transcripts
        _refreshDataInBackground();
        return;
      }
      
      // Only fetch from API if no cache exists
      final categories = await _dataService.getMessageCategories();
      
      // Small delay to let UI breathe
      await Future.delayed(const Duration(milliseconds: 50));
      
      final allSermons = await _dataService.getMessages();
      
      // Filter sermons based on user permissions
      final sermons = allSermons.where((sermon) {
        if (sermon.isServiceTeamOnly && !isServiceTeamMember) return false;
        if (sermon.isGeneralMarriedOnly && !isGeneralMarried) return false;
        if (sermon.isInHouseMarriedOnly && !isInHouseMarried) return false;
        return true;
      }).toList();
      
      // Cache the metadata in background (don't await)
      Future.microtask(() {
        _audioCacheService.cacheMetadata(categories: categories, sermons: sermons);
      });
      
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
        
        // Pre-buffer first 3 sermons for instant playback (reduced to prevent memory issues)
        _audioCacheService.preBufferCategory(sermons, count: 3);
      }
    } catch (e) {
      debugPrint('Error loading audio data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshDataInBackground() async {
    try {
      final authProvider = ref.read(authChangeNotifierProvider);
      final user = authProvider.user;
      final isServiceTeamMember = user?.isServiceTeamMember ?? false;
      final isGeneralMarried = user?.isGeneralMarried ?? false;
      final isInHouseMarried = user?.isInHouseMarried ?? false;

      final categories = await _dataService.getMessageCategories();
      final allSermons = await _dataService.getMessages(forceRefresh: true);

      final sermons = allSermons.where((sermon) {
        if (sermon.isServiceTeamOnly && !isServiceTeamMember) return false;
        if (sermon.isGeneralMarriedOnly && !isGeneralMarried) return false;
        if (sermon.isInHouseMarriedOnly && !isInHouseMarried) return false;
        return true;
      }).toList();

      if (mounted) {
        setState(() {
          _categories = categories;
          _sermons = sermons;
        });
        debugPrint('Background refresh complete: ${sermons.length} sermons');
      }
    } catch (e) {
      debugPrint('Background refresh error: $e');
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        appBar: CustomAppBar(
          title: '',
          showBackButton: true,
          lightBackground: true,
          onBackPressed: () => ref.read(mainTabIndexProvider.notifier).state = 0,
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

    final isTabletOrLarger = !Responsive.isMobile(context);
    final padding = Responsive.horizontalPadding(context);

    if (_categories.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primaryGold,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
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
              ),
            ),
          ],
        ),
      );
    }

    if (isTabletOrLarger) {
      return RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primaryGold,
        child: GridView.builder(
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: Responsive.gridCrossAxisCount(context, mobile: 1, tablet: 2, desktop: 3),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.5,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) => _buildCategoryCard(context, isDark, _categories[index]),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primaryGold,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 10),
        itemCount: _categories.length,
        itemBuilder: (context, index) => _buildCategoryCard(context, isDark, _categories[index]),
      ),
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
                    top: 4,
                    right: 4,
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
                  Text(
                    _stripHtmlTags(category.name),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _stripHtmlTags(category.description ?? 'It is a time for to come together to worship, hear God\'s word, and fellowship.'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                    maxLines: 3,
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
      return CachedNetworkImage(
        imageUrl: category.imageUrl!,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        placeholder: (context, url) => placeholder,
        errorWidget: (context, url, error) => placeholder,
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Filter categories that have sermons with transcripts
    final categoriesWithTranscripts = _categories.where((category) {
      return _sermons.any((sermon) =>
          (sermon.category == category.id || sermon.categoryName == category.name) &&
          sermon.transcript != null &&
          sermon.transcript!.isNotEmpty);
    }).toList();

    final padding = Responsive.horizontalPadding(context);
    final isTabletOrLarger = !Responsive.isMobile(context);

    if (categoriesWithTranscripts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primaryGold,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.article_outlined,
                          size: 64,
                          color: AppColors.primaryGold.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No Transcripts Yet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Message transcripts will be available here soon.\nStay tuned for written versions of our messages.',
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
              ),
            ),
          ],
        ),
      );
    }

    if (isTabletOrLarger) {
      return RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primaryGold,
        child: GridView.builder(
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: Responsive.gridCrossAxisCount(context, mobile: 1, tablet: 2, desktop: 3),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.5,
          ),
          itemCount: categoriesWithTranscripts.length,
          itemBuilder: (context, index) => _buildTranscriptCategoryCard(context, isDark, categoriesWithTranscripts[index]),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primaryGold,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 10),
        itemCount: categoriesWithTranscripts.length,
        itemBuilder: (context, index) => _buildTranscriptCategoryCard(context, isDark, categoriesWithTranscripts[index]),
      ),
    );
  }

  Widget _buildTranscriptCategoryCard(BuildContext context, bool isDark, MessageCategory category) {
    final transcriptCount = _sermons.where((sermon) =>
        (sermon.category == category.id || sermon.categoryName == category.name) &&
        sermon.transcript != null &&
        sermon.transcript!.isNotEmpty).length;

    // Get categories that have transcripts for filter list
    final categoriesWithTranscripts = _categories.where((cat) {
      return _sermons.any((sermon) =>
          (sermon.category == cat.id || sermon.categoryName == cat.name) &&
          sermon.transcript != null &&
          sermon.transcript!.isNotEmpty);
    }).toList();
    
    final categoryNameToId = {
      for (var c in categoriesWithTranscripts) c.name: c.id
    };

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TranscriptListPage(
              category: category.name,
              categoryId: category.id,
              sermons: _sermons,
              categories: categoriesWithTranscripts.map((c) => c.name).toList(),
              categoryNameToId: categoryNameToId,
            ),
          ),
        );
      },
      child: Container(
        margin: Responsive.isMobile(context) ? const EdgeInsets.only(bottom: 16) : EdgeInsets.zero,
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _stripHtmlTags(category.name),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$transcriptCount transcript${transcriptCount != 1 ? 's' : ''} available',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                    maxLines: 3,
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
}
