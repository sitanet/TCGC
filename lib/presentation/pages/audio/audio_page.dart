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
import '../../widgets/resume_playback_sheet.dart';
import 'favorites_page.dart';
import 'playlists_page.dart';
import 'downloads_page.dart';
import 'transcript_list_page.dart';
import 'ebook_list_page.dart';

enum AudioBrowseFilter { category, minister }
enum MinisterCategoryFilter { all, resident, external, songs }

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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  AudioBrowseFilter _selectedBrowseFilter = AudioBrowseFilter.category;
  MinisterCategoryFilter _selectedMinisterCategory = MinisterCategoryFilter.all;

  static List<MessageCategory> _staticCategories = [];
  static List<Sermon> _staticSermons = [];
  static List<Transcript> _staticTranscripts = [];
  static List<SpeakerModel> _staticSpeakers = [];

  List<MessageCategory> _categories = [];
  List<Sermon> _sermons = [];
  List<Transcript> _transcripts = [];
  List<SpeakerModel> _speakerModels = [];
  bool _isLoading = true;

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

      // Load categories, sermons, transcripts, and speakers from cache FIRST (instant)
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
        _dataService.getSpeakers(forceRefresh: true),
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
        });
        _staticCategories = processedCategories;
        _staticSermons = sermons;
        _staticTranscripts = transcripts;
        _staticSpeakers = speakers;
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
        _dataService.getSpeakers(forceRefresh: true),
      ]);

      final categories = results[0] as List<MessageCategory>;
      final allSermons = results[1] as List<Sermon>;
      final transcripts = results[2] as List<Transcript>;
      final speakers = results[3] as List<SpeakerModel>;

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
          _speakerModels = speakers;
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
    _searchController.dispose();
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
          title: 'Audio Messages',
          showBackButton: false,
          lightBackground: true,
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.grey[200],
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : Colors.grey[300]!,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: AppColors.primaryGold,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
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
      child: _buildAudioTabContent(context, isDark, padding),
    );
  }

  Widget _buildAudioTabContent(BuildContext context, bool isDark, double padding) {
    final audioProvider = ref.watch(audioPlayerChangeNotifierProvider);
    final hasMiniPlayer = audioProvider.currentSermon != null;
    final bottomInset = (hasMiniPlayer ? 140.0 : 90.0) + MediaQuery.of(context).padding.bottom;

    final categoriesWithSermons = _categories.where((category) {
      final count = _sermons.where((s) =>
        s.category == category.id ||
        s.category.toString() == category.id.toString() ||
        s.categoryName.toLowerCase() == category.name.toLowerCase()
      ).length;
      return count > 0;
    }).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(top: 8, bottom: bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Search Bar for instant title/speaker filtering
          _buildSearchBar(context, isDark),

          // 2. Active Search Results OR 3-Way Filter Navigation
          if (_searchQuery.isNotEmpty)
            _buildSearchResults(context, isDark, padding)
          else ...[
            // 3. Simple Browse Filter Pill Bar: By Category, By Minister
            _buildBrowseFilterBar(isDark),
            const SizedBox(height: 10),

            // 4. Filter Content View
            if (_selectedBrowseFilter == AudioBrowseFilter.category)
              _buildCategorySection(context, isDark, padding, categoriesWithSermons)
            else
              _buildMinisterSection(context, isDark, padding),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.grey[100],
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _searchQuery.isNotEmpty
                ? AppColors.primaryGold
                : (isDark ? AppColors.dividerDark : Colors.grey[300]!),
            width: _searchQuery.isNotEmpty ? 1.4 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(
              Icons.search_rounded,
              size: 22,
              color: _searchQuery.isNotEmpty
                  ? AppColors.primaryGold
                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  hintText: 'Search messages by title, minister...',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowseFilterBar(bool isDark) {
    final speakers = _getAvailableSpeakers();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _buildBrowseFilterPill(
            label: 'By Category',
            filter: AudioBrowseFilter.category,
            icon: Icons.category_outlined,
            count: _categories.length,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildBrowseFilterPill(
            label: 'By Minister',
            filter: AudioBrowseFilter.minister,
            icon: Icons.person_outline_rounded,
            count: speakers.length,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildBrowseFilterPill({
    required String label,
    required AudioBrowseFilter filter,
    required IconData icon,
    required int count,
    required bool isDark,
  }) {
    final isSelected = _selectedBrowseFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedBrowseFilter = filter;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryGold
                : (isDark ? AppColors.cardDark : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryGold
                  : (isDark ? AppColors.dividerDark : Colors.grey[300]!),
              width: isSelected ? 1.4 : 1.0,
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : AppColors.textPrimaryLight),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white : AppColors.textPrimaryLight),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, bool isDark, double padding) {
    final query = _searchQuery.toLowerCase();
    final matchingSermons = _sermons.where((s) {
      final titleMatch = s.title.toLowerCase().contains(query);
      final speakerMatch = s.speaker != null && s.speaker!.toLowerCase().contains(query);
      final catMatch = s.categoryName.toLowerCase().contains(query);
      return titleMatch || speakerMatch || catMatch;
    }).toList();

    if (matchingSermons.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 40),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 56,
                color: isDark ? Colors.white38 : Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'No messages found for "$_searchQuery"',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Try searching with another message title or minister name',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
          child: Text(
            'Found ${matchingSermons.length} message${matchingSermons.length == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryGold,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: padding),
          itemCount: matchingSermons.length,
          itemBuilder: (context, index) {
            final sermon = matchingSermons[index];
            return _buildSearchResultTile(sermon, isDark, matchingSermons);
          },
        ),
      ],
    );
  }

  Widget _buildSearchResultTile(Sermon sermon, bool isDark, List<Sermon> searchResults) {
    final audioProvider = ref.watch(audioPlayerChangeNotifierProvider);
    final isPlaying = audioProvider.currentSermon?.id == sermon.id && audioProvider.isPlaying;
    final speakerName = _formatSpeakerName(sermon.speaker ?? 'TCGC');
    final durationStr = sermon.duration.inMinutes > 0 ? '${sermon.duration.inMinutes} mins' : '';

    return GestureDetector(
      onTap: () {
        final index = searchResults.indexOf(sermon);
        ResumePlaybackHelper.handleMessageTap(
          context: context,
          ref: ref,
          sermon: sermon,
          queue: searchResults,
          queueIndex: index >= 0 ? index : 0,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPlaying
                ? AppColors.primaryGold
                : (isDark ? AppColors.dividerDark : Colors.grey[200]!),
            width: isPlaying ? 1.2 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail Image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: sermon.imageUrl != null && sermon.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: sermon.imageUrl!,
                      cacheManager: CustomImageCacheManager.instance,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      memCacheWidth: 104,
                      memCacheHeight: 104,
                      placeholder: (_, __) => Container(
                        width: 52,
                        height: 52,
                        color: isDark ? AppColors.cardDark : AppColors.dividerLight,
                        child: const Icon(Icons.music_note, size: 24, color: AppColors.primaryGold),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 52,
                        height: 52,
                        color: isDark ? AppColors.cardDark : AppColors.dividerLight,
                        child: const Icon(Icons.music_note, size: 24, color: AppColors.primaryGold),
                      ),
                    )
                  : Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : AppColors.dividerLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.music_note, size: 24, color: AppColors.primaryGold),
                    ),
            ),
            const SizedBox(width: 12),

            // Title & Details
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
                      fontSize: 13.5,
                      color: isPlaying
                          ? AppColors.primaryGold
                          : (isDark ? Colors.white : AppColors.textPrimaryLight),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$speakerName • ${sermon.categoryName.isNotEmpty ? sermon.categoryName : 'Messages'}${durationStr.isNotEmpty ? ' • $durationStr' : ''}',
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
            const SizedBox(width: 8),

            // Play action circle
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isPlaying
                    ? AppColors.primaryGold
                    : AppColors.primaryGold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 18,
                  color: isPlaying ? Colors.white : AppColors.primaryGold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    bool isDark,
    double padding,
    List<MessageCategory> categoriesWithSermons,
  ) {
    final crossAxisCount = Responsive.value(context, mobile: 2, tablet: 3, desktop: 4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Recently Added Carousel
        _buildRecentlyAddedSection(isDark, padding),

        // 2. Categories Header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Categories',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
              ),
              Text(
                '${categoriesWithSermons.length} Categories',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Category Grid
        if (categoriesWithSermons.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: 30),
            child: Center(
              child: Text(
                'No categories available',
                style: TextStyle(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 18,
              childAspectRatio: 0.73,
            ),
            itemCount: categoriesWithSermons.length,
            itemBuilder: (context, index) {
              return _buildCategoryGridCard(context, isDark, categoriesWithSermons[index]);
            },
          ),
      ],
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
        ResumePlaybackHelper.handleMessageTap(
          context: context,
          ref: ref,
          sermon: sermon,
          queue: queue,
          queueIndex: index >= 0 ? index : 0,
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

  List<SpeakerModel> _getAvailableSpeakers() {
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
    return speakers;
  }

  Widget _buildMinisterSection(BuildContext context, bool isDark, double padding) {
    final allSpeakers = _getAvailableSpeakers();
    if (allSpeakers.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 30),
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
      );
    }

    // Filter into groups
    final residentMinisters = allSpeakers.where((s) => !s.isExternalMinister && !s.isSongMinister).toList();
    final externalMinisters = allSpeakers.where((s) => s.isExternalMinister).toList();
    final songMinisters = allSpeakers.where((s) => s.isSongMinister).toList();

    List<SpeakerModel> displayedSpeakers;
    switch (_selectedMinisterCategory) {
      case MinisterCategoryFilter.all:
        displayedSpeakers = allSpeakers;
        break;
      case MinisterCategoryFilter.resident:
        displayedSpeakers = residentMinisters;
        break;
      case MinisterCategoryFilter.external:
        displayedSpeakers = externalMinisters;
        break;
      case MinisterCategoryFilter.songs:
        displayedSpeakers = songMinisters;
        break;
    }

    final crossAxisCount = Responsive.value(context, mobile: 2, tablet: 3, desktop: 4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header Row
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ministers of the Gospel',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
              ),
              Text(
                '${displayedSpeakers.length} of ${allSpeakers.length}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Sub-filter category chips: All, Resident, External, Songs
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: padding),
            children: [
              _buildMinisterSubChip(
                label: 'All Ministers',
                icon: Icons.people_outline_rounded,
                count: allSpeakers.length,
                isSelected: _selectedMinisterCategory == MinisterCategoryFilter.all,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedMinisterCategory = MinisterCategoryFilter.all);
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildMinisterSubChip(
                label: 'Resident',
                icon: Icons.church_outlined,
                count: residentMinisters.length,
                isSelected: _selectedMinisterCategory == MinisterCategoryFilter.resident,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedMinisterCategory = MinisterCategoryFilter.resident);
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildMinisterSubChip(
                label: 'Guest Ministers',
                icon: Icons.public_outlined,
                count: externalMinisters.length,
                isSelected: _selectedMinisterCategory == MinisterCategoryFilter.external,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedMinisterCategory = MinisterCategoryFilter.external);
                },
                isDark: isDark,
                accentColor: Colors.cyanAccent.shade700,
              ),
              const SizedBox(width: 8),
              _buildMinisterSubChip(
                label: 'Songs Ministers',
                icon: Icons.music_note_outlined,
                count: songMinisters.length,
                isSelected: _selectedMinisterCategory == MinisterCategoryFilter.songs,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedMinisterCategory = MinisterCategoryFilter.songs);
                },
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Ministers Grid or Empty State
        if (displayedSpeakers.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: 36),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    _selectedMinisterCategory == MinisterCategoryFilter.external
                        ? Icons.public_off_outlined
                        : (_selectedMinisterCategory == MinisterCategoryFilter.songs
                            ? Icons.music_off_outlined
                            : Icons.person_search_outlined),
                    size: 48,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _selectedMinisterCategory == MinisterCategoryFilter.external
                        ? 'No external / guest ministers yet'
                        : (_selectedMinisterCategory == MinisterCategoryFilter.songs
                            ? 'No songs ministers registered yet'
                            : 'No ministers in this category'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _selectedMinisterCategory = MinisterCategoryFilter.all);
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.primaryGold),
                    label: const Text('Show All Ministers', style: TextStyle(color: AppColors.primaryGold)),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: padding),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 18,
              childAspectRatio: 0.70,
            ),
            itemCount: displayedSpeakers.length,
            itemBuilder: (context, index) {
              return _buildSpeakerCard(context, isDark, displayedSpeakers[index]);
            },
          ),
      ],
    );
  }

  Widget _buildMinisterSubChip({
    required String label,
    required IconData icon,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    Color? accentColor,
  }) {
    final activeBgColor = accentColor != null && isSelected
        ? accentColor
        : (isSelected ? AppColors.primaryGold : (isDark ? AppColors.cardDark : Colors.white));
    final activeTextColor = isSelected
        ? Colors.white
        : (isDark ? Colors.white70 : AppColors.textPrimaryLight);
    final borderColor = isSelected
        ? (accentColor ?? AppColors.primaryGold)
        : (isDark ? AppColors.dividerDark : Colors.grey[300]!);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: activeBgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: isSelected ? 1.4 : 1.0),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (accentColor ?? AppColors.primaryGold).withValues(alpha: 0.28),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : (accentColor ?? (isDark ? Colors.white70 : AppColors.primaryGold)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: activeTextColor,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : (isDark ? Colors.white12 : Colors.grey[200]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : AppColors.textSecondaryLight),
                ),
              ),
            ),
          ],
        ),
      ),
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
              headerImageUrl: category.imageUrl,
              headerDescription: category.description,
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
              headerImageUrl: speaker.photoUrl,
              headerDescription: speaker.bio,
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
                          errorWidget: (_, __, ___) => _buildSpeakerFallbackImage(isDark),
                        ),
                      )
                    else
                      Positioned.fill(
                        child: _buildSpeakerFallbackImage(isDark),
                      ),

                    // External Minister Badge
                    if (speaker.isExternalMinister)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.cyanAccent.withValues(alpha: 0.7),
                              width: 0.8,
                            ),
                          ),
                          child: const Text(
                            'EXTERNAL',
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 9.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),

                    // Songs Minister Badge
                    if (speaker.isSongMinister)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.primaryGold.withValues(alpha: 0.7),
                              width: 0.8,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.music_note, size: 10, color: AppColors.primaryGold),
                              SizedBox(width: 2),
                              Text(
                                'SONGS',
                                style: TextStyle(
                                  color: AppColors.primaryGold,
                                  fontSize: 9.0,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.4,
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

          // 2. Minister Name directly below artwork card
          Text(
            formattedName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              height: 1.2,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 2),

          // Role Tag
          Text(
            speaker.isExternalMinister
                ? (speaker.isSongMinister ? 'Guest Worship Minister' : 'Guest Minister')
                : (speaker.isSongMinister
                    ? 'Songs Minister'
                    : (speaker.seniorPastor ? 'Senior Pastor' : 'Resident Minister')),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: speaker.isExternalMinister
                  ? (isDark ? Colors.cyanAccent : Colors.teal.shade700)
                  : (speaker.isSongMinister
                      ? AppColors.primaryGold
                      : (isDark ? Colors.white54 : AppColors.textSecondaryLight)),
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

  Widget _buildSpeakerFallbackImage(bool isDark) {
    return Container(
      color: isDark ? AppColors.cardDark : AppColors.dividerLight,
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
    final List<MessageCategory> categoriesToDisplay = _categories.where((category) {
      final count = _transcripts.where((t) {
        if (category.id == 'all') return true;
        return t.category == category.id ||
            t.category.toString() == category.id.toString() ||
            t.categoryName.toLowerCase() == category.name.toLowerCase();
      }).length;
      return count > 0;
    }).toList();

    // Dynamically include any category found on transcripts that isn't already in categoriesToDisplay
    final Set<String> existingCategoryIds =
        categoriesToDisplay.map((c) => c.id.toString()).toSet();
    final Set<String> existingCategoryNames =
        categoriesToDisplay.map((c) => c.name.toLowerCase()).toSet();

    for (final t in _transcripts) {
      final catId = t.category.toString().trim();
      final catName = t.categoryName.trim();
      if (catName.isNotEmpty &&
          !existingCategoryNames.contains(catName.toLowerCase()) &&
          (catId.isEmpty || !existingCategoryIds.contains(catId))) {
        existingCategoryNames.add(catName.toLowerCase());
        if (catId.isNotEmpty) existingCategoryIds.add(catId);
        categoriesToDisplay.add(
          MessageCategory(
            id: catId.isNotEmpty ? catId : catName,
            name: catName,
            description: '',
            imageUrl: t.imageUrl,
            isActive: true,
          ),
        );
      }
    }

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
          crossAxisCount: Responsive.value(context, mobile: 2, tablet: 3, desktop: 4),
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
            categoriesToDisplay,
          );
        },
      ),
    );
  }

  Widget _buildTranscriptCategoryCard(
    BuildContext context,
    bool isDark,
    MessageCategory category,
    List<MessageCategory> allCategories,
  ) {
    // Count transcripts for this category
    final count = _transcripts.where((t) {
      if (category.id == 'all') return true;
      return t.category == category.id ||
          t.category.toString() == category.id.toString() ||
          t.categoryName.toLowerCase() == category.name.toLowerCase();
    }).length;

    final categoryNameToId = {for (var c in allCategories) c.name: c.id};

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TranscriptListPage(
              category: category.name,
              categoryId: category.id,
              categories: allCategories.map((c) => c.name).toList(),
              categoryNameToId: categoryNameToId,
              categoryImageUrl: category.imageUrl,
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
