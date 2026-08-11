import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/image_cache_manager.dart';
import '../../../data/services/data_service.dart';
import '../../../data/services/audio_cache_service.dart';
import '../../../data/services/played_audio_service.dart';
import '../../../domain/entities/sermon.dart';
import '../../../domain/entities/transcript.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';
import 'audio_list_page.dart';
import 'audio_player_page.dart';
import 'favorites_page.dart';
import 'playlists_page.dart';
import 'downloads_page.dart';
import 'transcript_list_page.dart';
import 'ebook_list_page.dart';

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
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final DataService _dataService = DataService();
  final AudioCacheService _audioCacheService = AudioCacheService();

  static List<MessageCategory> _staticCategories = [];
  static List<Sermon> _staticSermons = [];
  static List<Transcript> _staticTranscripts = [];
  static List<SpeakerModel> _staticSpeakers = [];

  List<MessageCategory> _categories = [];
  List<Sermon> _sermons = [];
  List<Transcript> _transcripts = [];
  List<SpeakerModel> _speakerModels = [];
  bool _isLoading = true;
  bool _initialLoadDone = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (_staticCategories.isNotEmpty) {
      _categories = _staticCategories;
      _sermons = _staticSermons;
      _transcripts = _staticTranscripts;
      _speakerModels = _staticSpeakers;
      _isLoading = false;
      _initialLoadDone = true;
    }
    // Load cached data immediately, then refresh in background
    _audioCacheService.initialize();
    _loadCachedDataFirst();
  }

  /// Load cached data first for instant display, then refresh from server
  Future<void> _loadCachedDataFirst() async {
    try {
      // Get user permissions
      final authProvider = ref.read(authChangeNotifierProvider);
      final user = authProvider.user;
      final isServiceTeamMember = user?.isServiceTeamMember ?? false;
      final isGeneralMarried = user?.isGeneralMarried ?? false;
      final isInHouseMarried = user?.isInHouseMarried ?? false;

      // Load categories, sermons, transcripts AND speakers from cache FIRST (instant)
      final results = await Future.wait([
        _dataService.getMessageCategories(), // Uses cache-first
        _dataService.getMessages(), // Uses cache-first
        _dataService.getTranscripts(), // Uses cache-first (instant display)
        _dataService.getSpeakers(), // Uses cache-first
      ]);

      final categories = results[0] as List<MessageCategory>;
      final allSermons = results[1] as List<Sermon>;
      final transcripts = results[2] as List<Transcript>;
      final speakers = results[3] as List<SpeakerModel>;

      // Filter based on permissions
      final filteredCategories = categories.where((category) {
        if (category.isServiceTeamOnly && !isServiceTeamMember) return false;
        return true;
      }).toList();

      final sermons = allSermons.where((sermon) {
        if (sermon.isServiceTeamOnly && !isServiceTeamMember) return false;
        if (sermon.isGeneralMarriedOnly && !isGeneralMarried) return false;
        if (sermon.isInHouseMarriedOnly && !isInHouseMarried) return false;
        return true;
      }).toList();

      // Process and sort categories
      final processedCategories = _processCategories(
        filteredCategories,
        sermons,
      );

      if (mounted) {
        setState(() {
          _categories = processedCategories;
          _sermons = sermons;
          _transcripts = transcripts;
          _speakerModels = speakers;
          _isLoading = false;
          _initialLoadDone = true;
        });
        _staticCategories = processedCategories;
        _staticSermons = sermons;
        _staticTranscripts = transcripts;
        _staticSpeakers = speakers;

        // Pre-buffer in background
        _audioCacheService.preBufferCategory(sermons, count: 3);
      }

      // Refresh from server in background (non-blocking)
      _refreshDataInBackground();
    } catch (e) {
      debugPrint('Error loading cached data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Refresh data from server in background without blocking UI
  Future<void> _refreshDataInBackground() async {
    try {
      final authProvider = ref.read(authChangeNotifierProvider);
      final user = authProvider.user;
      final isServiceTeamMember = user?.isServiceTeamMember ?? false;
      final isGeneralMarried = user?.isGeneralMarried ?? false;
      final isInHouseMarried = user?.isInHouseMarried ?? false;

      // Fetch fresh data from server
      final results = await Future.wait([
        _dataService.getMessageCategories(forceRefresh: true),
        _dataService.getMessages(forceRefresh: true),
        _dataService.getTranscripts(forceRefresh: true),
      ]);

      final categories = results[0] as List<MessageCategory>;
      final allSermons = results[1] as List<Sermon>;
      final transcripts = results[2] as List<Transcript>;

      // Filter based on permissions
      final filteredCategories = categories.where((category) {
        if (category.isServiceTeamOnly && !isServiceTeamMember) return false;
        return true;
      }).toList();

      final sermons = allSermons.where((sermon) {
        if (sermon.isServiceTeamOnly && !isServiceTeamMember) return false;
        if (sermon.isGeneralMarriedOnly && !isGeneralMarried) return false;
        if (sermon.isInHouseMarriedOnly && !isInHouseMarried) return false;
        return true;
      }).toList();

      final processedCategories = _processCategories(
        filteredCategories,
        sermons,
      );

      if (mounted) {
        setState(() {
          _categories = processedCategories;
          _sermons = sermons;
          _transcripts = transcripts;
        });
      }

      debugPrint('Background refresh completed - ${transcripts.length} transcripts loaded');
    } catch (e) {
      debugPrint('Error refreshing data in background: $e');
    }
  }

  /// Process categories with latest message dates and sorting
  List<MessageCategory> _processCategories(
    List<MessageCategory> categories,
    List<Sermon> sermons,
  ) {
    final now = DateTime.now();
    final threeDaysAgo = now.subtract(const Duration(days: 3));
    final playedAudioService = PlayedAudioService();

    final updatedCategories = categories.map((category) {
      final categorySermons = sermons.where((s) {
        final matchById =
            s.category == category.id ||
            s.category.toString() == category.id.toString();
        final matchByName =
            s.categoryName.toLowerCase() == category.name.toLowerCase();
        return matchById || matchByName;
      }).toList();

      DateTime? latestDate;
      for (var sermon in categorySermons) {
        if (latestDate == null || sermon.date.isAfter(latestDate)) {
          latestDate = sermon.date;
        }
      }

      // Only show NEW if there are recent messages AND category hasn't been viewed
      final hasRecentMessages =
          latestDate != null && latestDate.isAfter(threeDaysAgo);
      final isCategoryViewed = playedAudioService.isCategoryViewed(category.id);
      final hasNew = hasRecentMessages && !isCategoryViewed;

      return category.copyWith(
        latestMessageDate: latestDate,
        hasNewMessage: hasNew,
      );
    }).toList();

    updatedCategories.sort((a, b) {
      if (a.hasNewMessage && !b.hasNewMessage) return -1;
      if (!a.hasNewMessage && b.hasNewMessage) return 1;
      if (a.latestMessageDate != null && b.latestMessageDate != null) {
        return b.latestMessageDate!.compareTo(a.latestMessageDate!);
      }
      if (a.latestMessageDate != null) return -1;
      if (b.latestMessageDate != null) return 1;
      return a.name.compareTo(b.name);
    });

    return updatedCategories;
  }

  /// Force refresh from server (for pull-to-refresh)
  Future<void> _loadData() async {
    // Don't show loading spinner on refresh - keep existing content visible
    try {
      final authProvider = ref.read(authChangeNotifierProvider);
      final user = authProvider.user;
      final isServiceTeamMember = user?.isServiceTeamMember ?? false;
      final isGeneralMarried = user?.isGeneralMarried ?? false;
      final isInHouseMarried = user?.isInHouseMarried ?? false;

      final results = await Future.wait([
        _dataService.getMessageCategories(forceRefresh: true),
        _dataService.getMessages(forceRefresh: true),
        _dataService.getTranscripts(forceRefresh: true),
      ]);

      final categories = results[0] as List<MessageCategory>;
      final allSermons = results[1] as List<Sermon>;
      final transcripts = results[2] as List<Transcript>;

      final filteredCategories = categories.where((category) {
        if (category.isServiceTeamOnly && !isServiceTeamMember) return false;
        return true;
      }).toList();

      final sermons = allSermons.where((sermon) {
        if (sermon.isServiceTeamOnly && !isServiceTeamMember) return false;
        if (sermon.isGeneralMarriedOnly && !isGeneralMarried) return false;
        if (sermon.isInHouseMarriedOnly && !isInHouseMarried) return false;
        return true;
      }).toList();

      Future.microtask(() {
        _audioCacheService.cacheMetadata(
          categories: filteredCategories,
          sermons: sermons,
        );
      });

      final processedCategories = _processCategories(
        filteredCategories,
        sermons,
      );

      if (mounted) {
        setState(() {
          _categories = processedCategories;
          _sermons = sermons;
          _transcripts = transcripts;
        });
        _audioCacheService.preBufferCategory(sermons, count: 3);
      }
    } catch (e) {
      debugPrint('Error refreshing audio data: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
          onBackPressed: () =>
              ref.read(mainTabIndexProvider.notifier).state = 0,
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
                  const EbookListPage(),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
        unselectedLabelColor: isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12.5,
        ),
        tabs: const [
          Tab(text: 'Audio'),
          Tab(text: 'Transcripts'),
          Tab(text: 'Library'),
        ],
      ),
    );
  }

  Widget _buildCategoryList(BuildContext context, bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final padding = Responsive.horizontalPadding(context);

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primaryGold,
      child: _buildCategoryGrid(context, isDark, padding),
    );
  }

  Widget _buildCategoryGrid(BuildContext context, bool isDark, double padding) {
    if (_categories.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: Center(
              child: Text(
                'No audio categories available',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final audioProvider = ref.watch(audioPlayerChangeNotifierProvider);
    final hasMiniPlayer = audioProvider.currentSermon != null;
    final bottomInset = (hasMiniPlayer ? 140.0 : 90.0) + MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(top: 8, bottom: bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Recently Added 15 Messages Section
          _buildRecentlyAddedSection(isDark, padding),

          // 2. Categories Section Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: Text(
              'Categories',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
            ),
          ),
          const SizedBox(height: 14),

          // 3. Category Cards Grid
          if (_categories.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 30),
              child: Center(
                child: Text(
                  'No categories available',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: padding),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: Responsive.isMobile(context) ? 2 : 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 18,
                childAspectRatio: 0.73,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                return _buildCategoryGridCard(context, isDark, _categories[index]);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecentlyAddedSection(bool isDark, double padding) {
    if (_sermons.isEmpty) return const SizedBox.shrink();

    final recentSermons = List<Sermon>.from(_sermons)
      ..sort((a, b) => b.date.compareTo(a.date));
    final top15 = recentSermons.take(15).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row: "Recently Added" | "See All"
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recently Added',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
              ),
              GestureDetector(
                onTap: () {
                  final categoryNameToId = {for (var c in _categories) c.name: c.id};
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AudioListPage(
                        category: 'All',
                        audioItems: _sermons,
                        categories: _categories.map((c) => c.name).toList(),
                        categoryNameToId: categoryNameToId,
                      ),
                    ),
                  );
                },
                child: const Text(
                  'See All',
                  style: TextStyle(
                    color: AppColors.primaryGold,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Horizontal Carousel of 15 Recent Messages
        SizedBox(
          height: 185,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: padding),
            itemCount: (top15.length / 3).ceil(),
            itemBuilder: (context, colIndex) {
              final startIndex = colIndex * 3;
              final colItems = top15.skip(startIndex).take(3).toList();

              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 16),
                child: Column(
                  children: colItems.map((sermon) {
                    return _buildRecentMessageTile(sermon, isDark, top15);
                  }).toList(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _buildRecentMessageTile(Sermon sermon, bool isDark, List<Sermon> queue) {
    final audioProvider = ref.watch(audioPlayerChangeNotifierProvider);
    final isPlaying = audioProvider.currentSermon?.id == sermon.id && audioProvider.isPlaying;
    final speakerName = _formatSpeakerName(sermon.speaker ?? 'TCGC');

    return GestureDetector(
      onTap: () {
        final index = queue.indexOf(sermon);
        audioProvider.setQueue(queue, index >= 0 ? index : 0);
        audioProvider.playSermon(sermon);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AudioPlayerPage(sermon: sermon),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            // Thumbnail Image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: sermon.imageUrl != null && sermon.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: sermon.imageUrl!,
                      cacheManager: CustomImageCacheManager.instance,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      memCacheWidth: 96,
                      memCacheHeight: 96,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      placeholder: (_, __) => Container(
                        width: 48,
                        height: 48,
                        color: isDark ? AppColors.cardDark : AppColors.dividerLight,
                        child: const Icon(Icons.music_note, size: 22, color: AppColors.primaryGold),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 48,
                        height: 48,
                        color: isDark ? AppColors.cardDark : AppColors.dividerLight,
                        child: const Icon(Icons.music_note, size: 22, color: AppColors.primaryGold),
                      ),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : AppColors.dividerLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.music_note, size: 22, color: AppColors.primaryGold),
                    ),
            ),
            const SizedBox(width: 12),

            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _stripHtmlTags(sermon.title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isPlaying
                          ? AppColors.primaryGold
                          : (isDark ? Colors.white : AppColors.textPrimaryLight),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$speakerName • ${sermon.categoryName.isNotEmpty ? sermon.categoryName : 'Messages'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeakerGrid(BuildContext context, bool isDark, double padding) {
    List<SpeakerModel> speakers = _speakerModels.where((s) => s.isMainSpeaker || s.isActive).toList();

    // Offline fallback: synthesize speaker cards from cached _sermons if no speakers loaded
    if (speakers.isEmpty && _sermons.isNotEmpty) {
      final Map<String, SpeakerModel> synthMap = {};
      int synthId = 2000;
      for (var sermon in _sermons) {
        if (sermon.speaker != null && sermon.speaker!.trim().isNotEmpty) {
          final name = sermon.speaker!.trim();
          final key = name.toLowerCase();
          if (!synthMap.containsKey(key)) {
            synthMap[key] = SpeakerModel(
              id: synthId++,
              name: name,
              fullName: name,
              isMainSpeaker: true,
              isActive: true,
            );
          }
        }
      }
      speakers = synthMap.values.toList();
    }

    if (speakers.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: Center(
              child: Text(
                'No ministers available',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final audioProvider = ref.watch(audioPlayerChangeNotifierProvider);
    final hasMiniPlayer = audioProvider.currentSermon != null;
    final bottomInset = (hasMiniPlayer ? 140.0 : 90.0) + MediaQuery.of(context).padding.bottom;

    return GridView.builder(
      padding: EdgeInsets.only(
        left: padding,
        right: padding,
        top: 8,
        bottom: bottomInset,
      ),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.isMobile(context) ? 2 : 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 18,
        childAspectRatio: 0.73,
      ),
      itemCount: speakers.length,
      itemBuilder: (context, index) {
        return _buildSpeakerCard(context, isDark, speakers[index]);
      },
    );
  }

  Widget _buildCategoryGridCard(
    BuildContext context,
    bool isDark,
    MessageCategory category,
  ) {
    final count = _sermons.where((s) =>
      s.category == category.id ||
      s.category.toString() == category.id.toString() ||
      s.categoryName.toLowerCase() == category.name.toLowerCase()
    ).length;

    return GestureDetector(
      onTap: () async {
        final categoryNameToId = {for (var c in _categories) c.name: c.id};
        await Navigator.push(
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
        if (mounted) {
          setState(() {
            _categories = _processCategories(_categories, _sermons);
          });
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Square Artwork Card with rounded corners and elevation
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _buildCategoryImage(category, isDark),
                    ),
                    if (category.hasNewMessage)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ],
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
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 2. Category Title directly below the artwork card
          Text(
            _stripHtmlTags(category.name),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              height: 1.2,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),

          const SizedBox(height: 2),

          // 3. Message Count
          Text(
            '$count messages',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.primaryGold,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakerCard(
    BuildContext context,
    bool isDark,
    SpeakerModel speaker,
  ) {
    final count = _sermons.where((s) {
      if (s.speaker == null || s.speaker!.trim().isEmpty) return false;
      final spk = s.speaker!.toLowerCase().trim();
      final spkName = speaker.name.toLowerCase().trim();
      final spkFullName = speaker.fullName.toLowerCase().trim();
      return spk == spkFullName || spk == spkName || spk.contains(spkName) || spkFullName.contains(spk);
    }).length;

    final formattedName = _formatSpeakerName(speaker.fullName);

    // Check for sample sermon image if speaker photo is missing
    String? sampleSermonImage;
    if (speaker.photoUrl == null || speaker.photoUrl!.isEmpty) {
      for (var s in _sermons) {
        if (s.speaker != null &&
            (s.speaker!.toLowerCase().contains(speaker.name.toLowerCase()) ||
             speaker.fullName.toLowerCase().contains(s.speaker!.toLowerCase())) &&
            s.imageUrl != null &&
            s.imageUrl!.isNotEmpty) {
          sampleSermonImage = s.imageUrl;
          break;
        }
      }
    }

    return GestureDetector(
      onTap: () async {
        final categoryNameToId = {for (var c in _categories) c.name: c.id};
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AudioListPage(
              category: 'All',
              audioItems: _sermons,
              categories: _categories.map((c) => c.name).toList(),
              categoryNameToId: categoryNameToId,
              initialFilterType: FilterType.speaker,
              initialSpeaker: speaker.fullName,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Square 1:1 Artwork Card
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    if (speaker.photoUrl != null && speaker.photoUrl!.isNotEmpty)
                      Positioned.fill(
                        child: CachedNetworkImage(
                          imageUrl: speaker.photoUrl!,
                          cacheManager: CustomImageCacheManager.instance,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          memCacheWidth: 400,
                          memCacheHeight: 400,
                          useOldImageOnUrlChange: true,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          errorWidget: (_, __, ___) => _buildSpeakerFallbackImage(speaker, sampleSermonImage, isDark),
                        ),
                      )
                    else
                      _buildSpeakerFallbackImage(speaker, sampleSermonImage, isDark),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 2. Minister Name directly below artwork card
          Text(
            formattedName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              height: 1.2,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),

          const SizedBox(height: 2),

          // 3. Message Count
          Text(
            '$count messages',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.primaryGold,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakerFallbackImage(SpeakerModel speaker, String? sampleSermonImage, bool isDark) {
    if (sampleSermonImage != null && sampleSermonImage.isNotEmpty) {
      return Stack(
        children: [
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: sampleSermonImage,
              cacheManager: CustomImageCacheManager.instance,
              fit: BoxFit.cover,
              memCacheWidth: 400,
              memCacheHeight: 400,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
            ),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGold.withValues(alpha: 0.7),
            isDark ? AppColors.cardDark : const Color(0xFF1E293B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person, size: 36, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              speaker.name.isNotEmpty ? speaker.name[0].toUpperCase() : 'M',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateGrid(BuildContext context, bool isDark, double padding) {
    if (_sermons.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: Center(
              child: Text(
                'No dated messages available',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Group sermons by year
    final Map<int, List<Sermon>> yearMap = {};
    for (var sermon in _sermons) {
      final year = sermon.date.year;
      yearMap.putIfAbsent(year, () => []).add(sermon);
    }

    final sortedYears = yearMap.keys.toList()..sort((a, b) => b.compareTo(a));

    final audioProvider = ref.watch(audioPlayerChangeNotifierProvider);
    final hasMiniPlayer = audioProvider.currentSermon != null;
    final bottomInset = (hasMiniPlayer ? 140.0 : 90.0) + MediaQuery.of(context).padding.bottom;

    return GridView.builder(
      padding: EdgeInsets.only(
        left: padding,
        right: padding,
        top: 8,
        bottom: bottomInset,
      ),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.isMobile(context) ? 2 : 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 18,
        childAspectRatio: 0.73,
      ),
      itemCount: sortedYears.length,
      itemBuilder: (context, index) {
        final year = sortedYears[index];
        final yearSermons = yearMap[year] ?? [];
        return _buildDateGridCard(context, isDark, year, yearSermons);
      },
    );
  }

  Widget _buildDateGridCard(
    BuildContext context,
    bool isDark,
    int year,
    List<Sermon> yearSermons,
  ) {
    final count = yearSermons.length;
    String? sampleImage;
    for (var s in yearSermons) {
      if (s.imageUrl != null && s.imageUrl!.isNotEmpty) {
        sampleImage = s.imageUrl;
        break;
      }
    }

    return GestureDetector(
      onTap: () {
        final categoryNameToId = {for (var c in _categories) c.name: c.id};
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AudioListPage(
              category: '$year Messages',
              audioItems: yearSermons,
              categories: _categories.map((c) => c.name).toList(),
              categoryNameToId: categoryNameToId,
              initialFilterType: FilterType.date,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Square Artwork / Year Card
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryGold.withValues(alpha: 0.8),
                    isDark ? AppColors.cardDark : const Color(0xFF1E293B),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    if (sampleImage != null && sampleImage.isNotEmpty)
                      Positioned.fill(
                        child: CachedNetworkImage(
                          imageUrl: sampleImage,
                          cacheManager: CustomImageCacheManager.instance,
                          fit: BoxFit.cover,
                          memCacheWidth: 400,
                          memCacheHeight: 400,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                        ),
                      ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.35),
                              Colors.black.withValues(alpha: 0.75),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 32,
                            color: AppColors.primaryGold,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$year',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 2. Title
          Text(
            '$year Messages',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),

          const SizedBox(height: 2),

          // 3. Message Count
          Text(
            '$count messages',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.primaryGold,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSpeakerName(String fullName) {
    if (fullName.isEmpty) return fullName;

    return fullName
        .replaceAll(RegExp(r'\bPastor\b', caseSensitive: false), 'Pst.')
        .replaceAll(RegExp(r'\bApostle\b', caseSensitive: false), 'Apst.')
        .replaceAll(RegExp(r'\bReverend\b', caseSensitive: false), 'Rev.')
        .replaceAll(RegExp(r'\bBishop\b', caseSensitive: false), 'Bsp.');
  }

  Widget _buildCategoryImage(MessageCategory category, bool isDark) {
    Widget placeholder = Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.dividerLight,
      ),
      child: Center(
        child: Icon(
          Icons.music_note,
          size: 36,
          color: AppColors.primaryGold.withValues(alpha: 0.5),
        ),
      ),
    );

    if (category.imageUrl == null || category.imageUrl!.isEmpty) {
      return placeholder;
    }

    if (category.imageUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: category.imageUrl!,
        cacheManager: CustomImageCacheManager.instance,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        memCacheWidth: 400,
        memCacheHeight: 400,
        useOldImageOnUrlChange: true,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) => placeholder,
        errorWidget: (context, url, error) => placeholder,
      );
    }

    return Image.asset(
      category.imageUrl!,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }

  Widget _buildTranscriptList(BuildContext context, bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final padding = Responsive.horizontalPadding(context);
    final audioProvider = ref.watch(audioPlayerChangeNotifierProvider);
    final hasMiniPlayer = audioProvider.currentSermon != null;
    final bottomInset = (hasMiniPlayer ? 140.0 : 90.0) + MediaQuery.of(context).padding.bottom;

    // Filter categories to only include those that have 1 or more transcripts
    final categoriesToDisplay = _categories.where((category) {
      final count = _transcripts.where((t) {
        if (category.id == 'all') return true;
        return t.category == category.id ||
            t.category.toString() == category.id.toString() ||
            t.categoryName.toLowerCase() == category.name.toLowerCase();
      }).length;
      return count > 0;
    }).toList();

    if (categoriesToDisplay.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primaryGold,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4,
              child: Center(
                child: Text(
                  'No transcript categories available',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primaryGold,
      child: GridView.builder(
        padding: EdgeInsets.only(
          left: padding,
          right: padding,
          top: 12,
          bottom: bottomInset,
        ),
        physics: const BouncingScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: Responsive.isMobile(context) ? 2 : 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 18,
          childAspectRatio: 0.73,
        ),
        itemCount: categoriesToDisplay.length,
        itemBuilder: (context, index) {
          return _buildTranscriptCategoryCard(
            context,
            isDark,
            categoriesToDisplay[index],
          );
        },
      ),
    );
  }

  Widget _buildTranscriptCategoryCard(
    BuildContext context,
    bool isDark,
    MessageCategory category,
  ) {
    // Count transcripts for this category
    final count = _transcripts.where((t) {
      if (category.id == 'all') return true;
      return t.category == category.id ||
          t.category.toString() == category.id.toString() ||
          t.categoryName.toLowerCase() == category.name.toLowerCase();
    }).length;

    final categoryNameToId = {for (var c in _categories) c.name: c.id};

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TranscriptListPage(
              category: category.name,
              categoryId: category.id,
              categories: _categories.map((c) => c.name).toList(),
              categoryNameToId: categoryNameToId,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Square Artwork Card
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _buildCategoryImage(category, isDark),
                    ),
                    // Transcript Badge Icon
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.article, size: 10, color: Colors.white),
                            SizedBox(width: 3),
                            Text(
                              'TEXT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 2. Category Title directly below artwork
          Text(
            _stripHtmlTags(category.name),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              height: 1.2,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),

          const SizedBox(height: 2),

          // 3. Transcript Count
          Text(
            '$count transcript${count != 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.primaryGold,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
