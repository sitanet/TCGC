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
  FilterType _filterType = FilterType.category;
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
      child: Column(
        children: [
          // Filter Toggle Row (Categories | Ministers)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: 12),
            child: Row(
              children: [
                _buildToggleChip('Categories', FilterType.category, isDark),
                const SizedBox(width: 12),
                _buildToggleChip('Ministers', FilterType.speaker, isDark),
              ],
            ),
          ),

          // Grid Body
          Expanded(
            child: _filterType == FilterType.category
                ? _buildCategoryGrid(context, isDark, padding)
                : _buildSpeakerGrid(context, isDark, padding),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleChip(String label, FilterType type, bool isDark) {
    final isSelected = _filterType == type;

    return GestureDetector(
      onTap: () {
        if (_filterType != type) {
          setState(() {
            _filterType = type;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGold
              : (isDark ? AppColors.cardDark : AppColors.surfaceLight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGold
                : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryGold.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
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
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.15,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        return _buildCategoryGridCard(context, isDark, _categories[index]);
      },
    );
  }

  Widget _buildSpeakerGrid(BuildContext context, bool isDark, double padding) {
    final speakers = _speakerModels.where((s) => s.isMainSpeaker || s.isActive).toList();

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
        crossAxisCount: Responsive.isMobile(context) ? 2 : 4,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.95,
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
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.dividerLight.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Artwork Header
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _buildCategoryImage(category, isDark),
                    ),
                    // Gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.5),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    // NEW Badge
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
              // Category Title & Count
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _stripHtmlTags(category.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$count messages',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primaryGold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeakerCard(
    BuildContext context,
    bool isDark,
    SpeakerModel speaker,
  ) {
    final count = _sermons.where((s) =>
      s.speaker != null &&
      (s.speaker!.toLowerCase() == speaker.fullName.toLowerCase() ||
       s.speaker!.toLowerCase() == speaker.name.toLowerCase())
    ).length;

    final formattedName = _formatSpeakerName(speaker.fullName);

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
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.dividerLight.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Speaker Circular Photo with Gold Ring Border
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryGold,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGold.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: speaker.photoUrl != null && speaker.photoUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: speaker.photoUrl!,
                        cacheManager: CustomImageCacheManager.instance,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        memCacheWidth: 128,
                        memCacheHeight: 128,
                        useOldImageOnUrlChange: true,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        placeholder: (_, __) => Container(
                          width: 64,
                          height: 64,
                          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                          child: const Icon(Icons.person, size: 32, color: AppColors.primaryGold),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 64,
                          height: 64,
                          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                          child: const Icon(Icons.person, size: 32, color: AppColors.primaryGold),
                        ),
                      )
                    : Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryGold.withValues(alpha: 0.4),
                              isDark ? const Color(0xFF2A2A2A) : Colors.grey[300]!,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            speaker.name.isNotEmpty ? speaker.name[0].toUpperCase() : 'M',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),

            // Formatted Speaker Name
            Text(
              formattedName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                height: 1.15,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 4),

            // Messages Count Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count messages',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGold,
                ),
              ),
            ),
          ],
        ),
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

    // Filter categories that have standalone transcripts
    final categoriesWithTranscripts = _categories.where((category) {
      return _transcripts.any(
        (transcript) =>
            transcript.category == category.id ||
            transcript.categoryName == category.name,
      );
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
            crossAxisCount: Responsive.gridCrossAxisCount(
              context,
              mobile: 1,
              tablet: 2,
              desktop: 3,
            ),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.5,
          ),
          itemCount: categoriesWithTranscripts.length,
          itemBuilder: (context, index) => _buildTranscriptCategoryCard(
            context,
            isDark,
            categoriesWithTranscripts[index],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primaryGold,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 10),
        itemCount: categoriesWithTranscripts.length,
        itemBuilder: (context, index) => _buildTranscriptCategoryCard(
          context,
          isDark,
          categoriesWithTranscripts[index],
        ),
      ),
    );
  }

  Widget _buildTranscriptCategoryCard(
    BuildContext context,
    bool isDark,
    MessageCategory category,
  ) {
    // Count standalone transcripts in this category
    final transcriptCount = _transcripts
        .where(
          (transcript) =>
              transcript.category == category.id ||
              transcript.categoryName == category.name,
        )
        .length;

    // Get categories that have transcripts for filter list
    final categoriesWithTranscripts = _categories.where((cat) {
      return _transcripts.any(
        (transcript) =>
            transcript.category == cat.id ||
            transcript.categoryName == cat.name,
      );
    }).toList();

    final categoryNameToId = {
      for (var c in categoriesWithTranscripts) c.name: c.id,
    };

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TranscriptListPage(
              category: category.name,
              categoryId: category.id,
              categories: categoriesWithTranscripts.map((c) => c.name).toList(),
              categoryNameToId: categoryNameToId,
            ),
          ),
        );
      },
      child: Container(
        margin: Responsive.isMobile(context)
            ? const EdgeInsets.only(bottom: 16)
            : EdgeInsets.zero,
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
