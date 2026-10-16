import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_cache_manager.dart';
import '../../../domain/entities/sermon.dart';
import '../../../domain/entities/beginner_category.dart';
import '../../../data/services/data_service.dart';
import '../../../data/services/download_service.dart';
import '../../../data/services/played_audio_service.dart';
import '../../../main.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_app_bar.dart';
import 'audio_player_page.dart';

enum FilterType { category, speaker, date }

String _stripHtml(String text) {
  return text
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();
}

class AudioListPage extends ConsumerStatefulWidget {
  final String category;
  final String? categoryId;
  final List<Sermon> audioItems;
  final List<String> categories;
  final Map<String, String>? categoryNameToId;
  final FilterType initialFilterType;
  final String? initialSpeaker;
  final List<BeginnerCategory>? beginnerCategories;
  final bool isDirectCollection;
  final String? headerImageUrl;
  final String? headerDescription;

  const AudioListPage({
    super.key,
    required this.category,
    this.categoryId,
    required this.audioItems,
    required this.categories,
    this.categoryNameToId,
    this.initialFilterType = FilterType.category,
    this.initialSpeaker,
    this.beginnerCategories,
    this.isDirectCollection = false,
    this.headerImageUrl,
    this.headerDescription,
  });

  @override
  ConsumerState<AudioListPage> createState() => _AudioListPageState();
}

class _AudioListPageState extends ConsumerState<AudioListPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DataService _dataService = DataService();
  List<Sermon> _allItems = [];
  List<Sermon> _filteredItems = [];
  late String _selectedCategory;
  late String? _selectedCategoryId;
  late FilterType _filterType;
  String? _selectedSpeaker;
  List<String> _speakers = [];
  List<SpeakerModel> _speakerModels = [];
  int _preBufferedUpTo = 0;
  bool _isRefreshing = false;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _allItems = widget.audioItems;
    _selectedCategory = widget.category;
    _selectedCategoryId = widget.categoryId;
    _filterType = widget.initialFilterType;
    _selectedSpeaker = widget.initialSpeaker;
    _extractSpeakers();
    _filteredItems = _getFilteredItems('');
    _searchController.addListener(_filterAudio);
    _scrollController.addListener(_onScroll);
    
    // Mark category as viewed immediately when page opens
    if (widget.categoryId != null && widget.categoryId!.isNotEmpty) {
      PlayedAudioService().markCategoryViewed(widget.categoryId!);
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preBufferInitial();
      _loadSpeakers();
    });
    
    // Auto-refresh every 5 minutes
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _onRefresh();
    });
  }
  
  Future<void> _loadSpeakers() async {
    try {
      final speakers = await _dataService.getSpeakers();
      if (mounted) {
        setState(() {
          _speakerModels = speakers;
        });
      }
    } catch (e) {
      debugPrint('Error loading speakers: $e');
    }
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    
    try {
      // Fetch fresh data from server (with forceRefresh to bypass cache)
      final sermons = await _dataService.getMessages(forceRefresh: true);
      debugPrint('Refresh got ${sermons.length} sermons');
      if (mounted) {
        setState(() {
          _allItems = sermons;
          _extractSpeakers();
          _filteredItems = _getFilteredItems(_searchController.text);
          _isRefreshing = false;
        });
        _preBufferInitial();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Refreshed ${sermons.length} messages')),
        );
      }
    } catch (e) {
      debugPrint('Refresh error: $e');
      if (mounted) {
        setState(() => _isRefreshing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to refresh')),
        );
      }
    }
  }
  
  void _preBufferInitial() {
    final audioProvider = ref.read(audioPlayerChangeNotifierProvider);
    // Pre-buffer first 3 items for instant playback (reduced to prevent memory issues)
    audioProvider.preBufferSermons(_filteredItems, count: 3);
    _preBufferedUpTo = 3;
  }
  
  void _onScroll() {
    // Check if we're near the end of the list
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _preBufferMore();
    }
  }
  
  void _preBufferMore() {
    if (_preBufferedUpTo >= _filteredItems.length) return;
    
    final audioProvider = ref.read(audioPlayerChangeNotifierProvider);
    // Pre-buffer next 2 items when user scrolls near the end (reduced to prevent memory issues)
    audioProvider.preBufferMore(_filteredItems, _preBufferedUpTo, count: 2);
    _preBufferedUpTo += 2;
  }

  void _extractSpeakers() {
    final speakerSet = <String>{};
    for (var audio in _allItems) {
      if (audio.speaker != null && audio.speaker!.isNotEmpty) {
        speakerSet.add(audio.speaker!);
      }
    }
    _speakers = speakerSet.toList()..sort();
  }
  
  void _showLockedMessage(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock, color: AppColors.primaryGold),
            const SizedBox(width: 8),
            const Text('Restricted Content'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 48,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'This message is only available for Service Team members.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _filterAudio() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _getFilteredItems(query);
    });
  }

  bool _isMainSpeaker(String? speakerName) {
    if (speakerName == null) return false;
    return _speakerModels.any((s) => 
        s.isMainSpeaker && 
        (s.fullName.toLowerCase() == speakerName.toLowerCase() || 
         s.name.toLowerCase() == speakerName.toLowerCase()));
  }

  List<Sermon> _getFilteredItems(String query) {
    debugPrint('Filtering: filterType=$_filterType, category=$_selectedCategory, categoryId=$_selectedCategoryId, speaker=$_selectedSpeaker');
    debugPrint('Total audio items: ${_allItems.length}');
    
    // Get user permissions
    final authProvider = ref.read(authChangeNotifierProvider);
    final user = authProvider.user;
    final isServiceTeamMember = user?.isServiceTeamMember ?? false;
    final isGeneralMarried = user?.isGeneralMarried ?? false;
    final isInHouseMarried = user?.isInHouseMarried ?? false;
    
    final filtered = _allItems.where((audio) {
      // Filter out restricted messages that user cannot access
      if (audio.isServiceTeamOnly && !isServiceTeamMember) return false;
      if (audio.isGeneralMarriedOnly && !isGeneralMarried) return false;
      if (audio.isInHouseMarriedOnly && !isInHouseMarried) return false;
      
      bool matchesFilter = false;
      
      if (_filterType == FilterType.speaker) {
        // Filter by speaker
        if (_selectedSpeaker == null || _selectedSpeaker == 'All') {
          matchesFilter = true;
        } else if (_selectedSpeaker == 'Others') {
          matchesFilter = !_isMainSpeaker(audio.speaker);
        } else {
          final selSpk = _selectedSpeaker!.toLowerCase().trim();
          final audioSpk = (audio.speaker ?? '').toLowerCase().trim();
          if (audioSpk == selSpk) {
            matchesFilter = true;
          } else {
            final matchedModel = _speakerModels.where((s) =>
                s.fullName.toLowerCase().trim() == selSpk ||
                s.name.toLowerCase().trim() == selSpk).firstOrNull;
            if (matchedModel != null) {
              final mName = matchedModel.name.toLowerCase().trim();
              final mFull = matchedModel.fullName.toLowerCase().trim();
              matchesFilter = audioSpk == mName ||
                  audioSpk == mFull ||
                  (mName.isNotEmpty && audioSpk.contains(mName)) ||
                  (mFull.isNotEmpty && audioSpk.contains(mFull)) ||
                  (audioSpk.isNotEmpty && mFull.contains(audioSpk));
            } else {
              matchesFilter = (audioSpk.isNotEmpty && selSpk.contains(audioSpk)) ||
                  (selSpk.isNotEmpty && audioSpk.contains(selSpk));
            }
          }
        }
      } else {
        // Direct collection / Beginner Category mode
        if (widget.isDirectCollection || widget.beginnerCategories != null) {
          matchesFilter = true;
        } else {
          // Filter by standard category
          matchesFilter = _selectedCategory == 'All';
          
          if (!matchesFilter) {
            // Try matching by category ID (audio.category could be ID)
            if (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty) {
              matchesFilter = audio.category == _selectedCategoryId ||
                  audio.category.toString() == _selectedCategoryId.toString();
            }
            // Try matching by category name (case-insensitive)
            if (!matchesFilter && audio.categoryName.isNotEmpty) {
              matchesFilter = audio.categoryName.toLowerCase() == _selectedCategory.toLowerCase();
            }
            // Try matching category field against name (case-insensitive)
            if (!matchesFilter && audio.category.isNotEmpty) {
              matchesFilter = audio.category.toLowerCase() == _selectedCategory.toLowerCase();
            }
            // Also check if audio.category matches the name via categoryNameToId lookup
            if (!matchesFilter && widget.categoryNameToId != null) {
              final categoryIdFromName = widget.categoryNameToId![_selectedCategory];
              if (categoryIdFromName != null) {
                matchesFilter = audio.category == categoryIdFromName ||
                    audio.category.toString() == categoryIdFromName.toString();
              }
            }
          }
        }
      }
      
      final matchesSearch = query.isEmpty ||
          audio.title.toLowerCase().contains(query) ||
          audio.description.toLowerCase().contains(query) ||
          (audio.speaker?.toLowerCase().contains(query) ?? false);
      
      if (!matchesFilter && _filterType == FilterType.category && _selectedCategory != 'All') {
        debugPrint('No match for: ${audio.title}, category=${audio.category}, categoryName=${audio.categoryName}, selectedCategoryId=$_selectedCategoryId, selectedCategory=$_selectedCategory');
      }
      
      return matchesFilter && matchesSearch;
    }).toList();
    
    debugPrint('Filtered items: ${filtered.length}');
    return filtered;
  }

  void _selectCategory(String category) {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filterType = FilterType.category;
      _selectedCategory = category;
      _selectedCategoryId = widget.categoryNameToId?[category];
      _selectedSpeaker = null;

      // When in beginner category mode, switch the active sermon list to the selected beginner category
      if (widget.beginnerCategories != null) {
        final match = widget.beginnerCategories!.firstWhere(
          (c) => c.name.toLowerCase() == category.toLowerCase(),
          orElse: () => BeginnerCategory(id: '', name: category, sermons: []),
        );
        if (match.sermons.isNotEmpty) {
          _allItems = match.sermons;
        } else if (category == 'All') {
          _allItems = widget.beginnerCategories!.expand((c) => c.sermons).toList();
        }
      }

      _filteredItems = _getFilteredItems(query);
    });
  }

  void _selectSpeaker(String speaker) {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filterType = FilterType.speaker;
      _selectedSpeaker = speaker == 'All' ? null : speaker;
      _selectedCategory = 'All';
      _selectedCategoryId = null;
      _filteredItems = _getFilteredItems(query);
    });
  }

  void _playAll() {
    if (_filteredItems.isEmpty) return;
    final audioProvider = ref.read(audioPlayerChangeNotifierProvider);
    audioProvider.setQueue(_filteredItems, 0);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AudioPlayerPage(sermon: _filteredItems.first),
      ),
    );
  }

  void _shuffleAndPlay() {
    if (_filteredItems.isEmpty) return;
    final shuffled = List<Sermon>.from(_filteredItems)..shuffle();
    final audioProvider = ref.read(audioPlayerChangeNotifierProvider);
    audioProvider.setQueue(shuffled, 0);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AudioPlayerPage(sermon: shuffled.first),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isSeries = widget.isDirectCollection || widget.beginnerCategories != null;
    final isSpeakerMode = _filterType == FilterType.speaker;

    String pageTitle = 'Audio Messages';
    if (isSeries) {
      pageTitle = _selectedCategory != 'All' ? _selectedCategory : widget.category;
    } else if (isSpeakerMode && _selectedSpeaker != null && _selectedSpeaker != 'All') {
      pageTitle = _formatSpeakerName(_selectedSpeaker!).replaceAll('\n', ' ');
    } else if (widget.category != 'All') {
      pageTitle = widget.category;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        appBar: CustomAppBar(
          title: pageTitle,
          showBackButton: Navigator.canPop(context),
          lightBackground: !isDark,
        ),
        body: Builder(
          builder: (context) {
            final audioProvider = ref.watch(audioPlayerChangeNotifierProvider);
            final authProvider = ref.watch(authChangeNotifierProvider);
            final downloadService = DownloadService();
            final user = authProvider.user;
            final isServiceTeamMember = user?.isServiceTeamMember ?? false;
            final isGeneralMarried = user?.isGeneralMarried ?? false;
            final isInHouseMarried = user?.isInHouseMarried ?? false;
            final hasMiniPlayer = audioProvider.currentSermon != null;
            final bottomInset = (hasMiniPlayer ? 140.0 : 90.0) + MediaQuery.of(context).padding.bottom;

            return RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppColors.primaryGold,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. Hero Header Card
                  SliverToBoxAdapter(
                    child: _buildHeroHeader(isDark),
                  ),

                  // 2. In-Page Search Bar
                  SliverToBoxAdapter(
                    child: _buildSearchBar(isDark),
                  ),

                  // 3. Sibling Filters (Ministers, Series, or Categories)
                  if (isSpeakerMode)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildSpeakerFilterList(isDark),
                      ),
                    )
                  else if (isSeries && (widget.beginnerCategories?.length ?? 0) > 1)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildSeriesFilterList(isDark),
                      ),
                    )
                  else if (widget.categories.length > 1)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildCategoryFilterList(isDark),
                      ),
                    ),

                  // 4. Section Header with count
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Messages',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            ),
                          ),
                          Text(
                            '${_filteredItems.length} available',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 5. Messages List or Empty State
                  if (_filteredItems.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 54,
                                color: isDark ? Colors.white30 : Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'No messages found for "${_searchController.text}"'
                                    : 'No audio messages in this collection',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                                ),
                              ),
                              if (_searchController.text.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => _searchController.clear(),
                                  child: const Text('Clear search', style: TextStyle(color: AppColors.primaryGold)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.only(left: 16, right: 16, bottom: bottomInset),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final audio = _filteredItems[index];
                            final isPreBuffered = audioProvider.isPreBuffered(audio.id);
                            final isDownloaded = downloadService.isDownloaded(audio.id);
                            final isReadyToPlay = isPreBuffered || isDownloaded;
                            final isBuffering = audioProvider.isBuffering(audio.id);
                            final bufferProgress = audioProvider.getBufferProgress(audio.id);
                            final isLocked = (audio.isServiceTeamOnly && !isServiceTeamMember) ||
                                (audio.isGeneralMarriedOnly && !isGeneralMarried) ||
                                (audio.isInHouseMarriedOnly && !isInHouseMarried);
                            final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
                            final isNew = audio.date.isAfter(threeDaysAgo) && !audioProvider.isAudioPlayed(audio.id);
                            final isCurrentlyPlaying = audioProvider.currentSermon?.id == audio.id && audioProvider.isPlaying;

                            return _AudioListItem(
                              sermon: audio,
                              isDark: isDark,
                              isReadyToPlay: isReadyToPlay,
                              isBuffering: isBuffering,
                              bufferProgress: bufferProgress,
                              isServiceTeamMember: isServiceTeamMember,
                              isGeneralMarried: isGeneralMarried,
                              isInHouseMarried: isInHouseMarried,
                              isNew: isNew,
                              isPlaying: isCurrentlyPlaying,
                              onPlayTap: () {
                                if (isLocked) {
                                  _showLockedMessage(context, isDark);
                                  return;
                                }
                                if (isCurrentlyPlaying) {
                                  audioProvider.pause();
                                } else {
                                  audioProvider.setQueue(_filteredItems, index);
                                  audioProvider.playSermon(audio);
                                }
                              },
                              onCardTap: () {
                                if (isLocked) {
                                  _showLockedMessage(context, isDark);
                                  return;
                                }
                                audioProvider.setQueue(_filteredItems, index);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AudioPlayerPage(sermon: audio),
                                  ),
                                );
                              },
                            );
                          },
                          childCount: _filteredItems.length,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroHeader(bool isDark) {
    final isSeries = widget.isDirectCollection || widget.beginnerCategories != null;
    final isMinister = _filterType == FilterType.speaker && _selectedSpeaker != null && _selectedSpeaker != 'All';
    final isCategory = !isSeries && !isMinister && _selectedCategory != 'All';

    String headerTypePill = 'ALL MESSAGES';
    Color pillColor = AppColors.primaryGold;
    IconData pillIcon = Icons.library_music_rounded;
    String displayTitle = widget.category != 'All' ? widget.category : 'Audio Messages';
    String subtitle = '${_filteredItems.length} Messages • The CityGate Church';
    String? imageUrl = widget.headerImageUrl;
    String? description = widget.headerDescription;

    if (isSeries) {
      headerTypePill = 'TEACHING SERIES';
      pillColor = AppColors.primaryGold;
      pillIcon = Icons.auto_stories_rounded;
      displayTitle = _selectedCategory != 'All' ? _selectedCategory : widget.category;
      if (imageUrl == null || imageUrl.isEmpty) {
        final matchSeries = widget.beginnerCategories?.where((c) => c.name.toLowerCase() == displayTitle.toLowerCase()).firstOrNull;
        imageUrl = matchSeries?.imageUrl;
        description ??= matchSeries?.description;
      }
    } else if (isMinister) {
      final selSpk = _selectedSpeaker!.toLowerCase().trim();
      final model = _speakerModels.where((s) =>
          s.fullName.toLowerCase().trim() == selSpk ||
          s.name.toLowerCase().trim() == selSpk ||
          selSpk.contains(s.fullName.toLowerCase().trim()) ||
          s.fullName.toLowerCase().trim().contains(selSpk)).firstOrNull;

      final isExternal = model?.isExternalMinister ?? false;
      final isSong = model?.isSongMinister ?? false;
      final isSenior = model?.seniorPastor ?? false;
      final isMain = model?.isMainSpeaker ?? false;

      if (isExternal && isSong) {
        headerTypePill = 'GUEST WORSHIP MINISTER';
        pillColor = Colors.cyanAccent.shade700;
        pillIcon = Icons.public_rounded;
      } else if (isExternal) {
        headerTypePill = 'GUEST MINISTER';
        pillColor = Colors.cyanAccent.shade700;
        pillIcon = Icons.public_rounded;
      } else if (isSong) {
        headerTypePill = 'SONGS MINISTER';
        pillColor = AppColors.primaryGold;
        pillIcon = Icons.music_note_rounded;
      } else if (isSenior) {
        headerTypePill = 'SENIOR PASTOR';
        pillColor = AppColors.primaryGold;
        pillIcon = Icons.church_rounded;
      } else if (isMain) {
        headerTypePill = 'RESIDENT PASTOR';
        pillColor = AppColors.primaryGold;
        pillIcon = Icons.church_rounded;
      } else {
        headerTypePill = 'MINISTER';
        pillColor = AppColors.primaryGold;
        pillIcon = Icons.person_rounded;
      }

      displayTitle = _formatSpeakerName(_selectedSpeaker!).replaceAll('\n', ' ');
      imageUrl = model?.photoUrl ?? imageUrl;
      description ??= model?.bio;
    } else if (isCategory) {
      headerTypePill = 'MESSAGE CATEGORY';
      pillColor = AppColors.primaryGold;
      pillIcon = Icons.category_rounded;
      displayTitle = _selectedCategory;
    }

    if (!isMinister && (imageUrl == null || imageUrl.isEmpty) && _filteredItems.isNotEmpty) {
      for (final s in _filteredItems) {
        if (s.imageUrl != null && s.imageUrl!.isNotEmpty) {
          imageUrl = s.imageUrl;
          break;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMinister && (pillColor == Colors.cyanAccent.shade700)
              ? (isDark ? Colors.cyanAccent.withValues(alpha: 0.35) : Colors.cyan.shade200)
              : (isDark ? AppColors.dividerDark : Colors.grey.shade200),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(isMinister ? 40 : 14),
                child: Container(
                  width: 76,
                  height: 76,
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          cacheManager: CustomImageCacheManager.instance,
                          fit: BoxFit.cover,
                          memCacheWidth: 152,
                          memCacheHeight: 152,
                          useOldImageOnUrlChange: true,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          placeholder: (_, __) => isMinister
                              ? const SizedBox.shrink()
                              : Icon(
                                  Icons.music_note_rounded,
                                  size: 32,
                                  color: pillColor,
                                ),
                          errorWidget: (_, __, ___) => isMinister
                              ? const SizedBox.shrink()
                              : Icon(
                                  Icons.music_note_rounded,
                                  size: 32,
                                  color: pillColor,
                                ),
                        )
                      : (isMinister
                          ? null
                          : Icon(
                              Icons.music_note_rounded,
                              size: 32,
                              color: pillColor,
                            )),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: pillColor.withValues(alpha: isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: pillColor.withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(pillIcon, size: 11, color: pillColor),
                          const SizedBox(width: 4),
                          Text(
                            headerTypePill,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: pillColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _stripHtml(description),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _playAll,
                  icon: const Icon(Icons.play_arrow_rounded, size: 20, color: Colors.white),
                  label: const Text(
                    'Play All',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _shuffleAndPlay,
                icon: Icon(
                  Icons.shuffle_rounded,
                  size: 18,
                  color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                ),
                label: Text(
                  'Shuffle',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isDark ? AppColors.dividerDark : Colors.grey.shade300,
                    width: 1.2,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.grey[100],
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _searchController.text.isNotEmpty
                ? AppColors.primaryGold
                : (isDark ? AppColors.dividerDark : Colors.grey[300]!),
            width: _searchController.text.isNotEmpty ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(
              Icons.search_rounded,
              size: 20,
              color: _searchController.text.isNotEmpty
                  ? AppColors.primaryGold
                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  hintText: 'Search in this collection...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeriesFilterList(bool isDark) {
    if (widget.beginnerCategories == null || widget.beginnerCategories!.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.beginnerCategories!.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final s = widget.beginnerCategories![index];
          final isSelected = s.name.toLowerCase() == _selectedCategory.toLowerCase();
          return _buildChipPill(
            label: s.name,
            isSelected: isSelected,
            isDark: isDark,
            onTap: () => _selectCategory(s.name),
          );
        },
      ),
    );
  }

  Widget _buildCategoryFilterList(bool isDark) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = widget.categories[index];
          final isSelected = cat.toLowerCase() == _selectedCategory.toLowerCase();
          return _buildChipPill(
            label: cat,
            isSelected: isSelected,
            isDark: isDark,
            onTap: () => _selectCategory(cat),
          );
        },
      ),
    );
  }

  Widget _buildChipPill({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGold
              : (isDark ? AppColors.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGold
                : (isDark ? AppColors.dividerDark : Colors.grey.shade300),
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryGold.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : AppColors.textPrimaryLight),
          ),
        ),
      ),
    );
  }

  Widget _buildSpeakerFilterList(bool isDark) {
    // Show active speakers from models (ordered: main/senior speakers first, then external ministers, then song ministers, then others)
    final activeSpeakers = List<SpeakerModel>.from(_speakerModels.where((s) => s.isActive))
      ..sort((a, b) {
        if (a.isMainSpeaker && !b.isMainSpeaker) return -1;
        if (!a.isMainSpeaker && b.isMainSpeaker) return 1;
        if (a.isExternalMinister && !b.isExternalMinister) return -1;
        if (!a.isExternalMinister && b.isExternalMinister) return 1;
        if (a.isSongMinister && !b.isSongMinister) return -1;
        if (!a.isSongMinister && b.isSongMinister) return 1;
        return a.fullName.compareTo(b.fullName);
      });

    // Check if there are speakers from messages not present in models
    final knownNames = activeSpeakers.map((s) => s.fullName.toLowerCase()).toSet();
    final otherSpeakers = _speakers.where((spk) => !knownNames.contains(spk.toLowerCase())).toList();

    if (activeSpeakers.isEmpty && otherSpeakers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'No speakers available',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
      );
    }

    // Total count: "All" + activeSpeakers + otherSpeakers
    final itemCount = 1 + activeSpeakers.length + otherSpeakers.length;

    return SizedBox(
      height: 105,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _selectedSpeaker == null || _selectedSpeaker == 'All';
            return _buildSpeakerChip(
              name: 'All',
              photoUrl: null,
              isSelected: isSelected,
              isDark: isDark,
              onTap: () => _selectSpeaker('All'),
            );
          }

          if (index <= activeSpeakers.length) {
            final speaker = activeSpeakers[index - 1];
            final isSelected = speaker.fullName == _selectedSpeaker;
            return _buildSpeakerChip(
              name: speaker.fullName,
              photoUrl: speaker.photoUrl,
              isSelected: isSelected,
              isDark: isDark,
              onTap: () => _selectSpeaker(speaker.fullName),
              isFullName: true,
              isExternal: speaker.isExternalMinister,
              isSong: speaker.isSongMinister,
            );
          }

          final otherName = otherSpeakers[index - 1 - activeSpeakers.length];
          final isSelected = otherName == _selectedSpeaker;
          return _buildSpeakerChip(
            name: otherName,
            photoUrl: null,
            isSelected: isSelected,
            isDark: isDark,
            onTap: () => _selectSpeaker(otherName),
            isFullName: true,
          );
        },
      ),
    );
  }

  Widget _buildSpeakerChip({
    required String name,
    String? photoUrl,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
    bool isFullName = false,
    bool isOthers = false,
    bool isExternal = false,
    bool isSong = false,
  }) {
    Color borderColor = Colors.transparent;
    if (isSelected) {
      borderColor = isExternal ? Colors.cyanAccent.shade700 : AppColors.primaryGold;
    } else if (isExternal) {
      borderColor = isDark ? Colors.cyanAccent.withValues(alpha: 0.5) : Colors.cyan.shade300;
    } else if (isSong) {
      borderColor = isDark ? AppColors.primaryGold.withValues(alpha: 0.5) : AppColors.primaryGold.withValues(alpha: 0.3);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 88,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: borderColor,
                      width: isSelected ? 3 : (isExternal || isSong ? 1.5 : 0),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: (isExternal ? Colors.cyanAccent.shade700 : AppColors.primaryGold).withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: ClipOval(
                    child: name == 'All'
                        ? Container(
                            color: isSelected
                                ? AppColors.primaryGold
                                : (isDark ? AppColors.cardDark : AppColors.dividerLight),
                            child: Icon(
                              Icons.people,
                              size: 28,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                            ),
                          )
                        : isOthers
                            ? Container(
                                color: isSelected
                                    ? AppColors.primaryGold
                                    : (isDark ? AppColors.cardDark : AppColors.dividerLight),
                                child: Icon(
                                  Icons.more_horiz,
                                  size: 28,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                ),
                              )
                            : photoUrl != null && photoUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: photoUrl,
                                    cacheManager: CustomImageCacheManager.instance,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 112,
                                    memCacheHeight: 112,
                                    useOldImageOnUrlChange: true,
                                    fadeInDuration: Duration.zero,
                                    fadeOutDuration: Duration.zero,
                                    placeholder: (_, __) => Container(
                                      color: isDark ? AppColors.cardDark : AppColors.dividerLight,
                                      child: Icon(
                                        Icons.person,
                                        size: 28,
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: isDark ? AppColors.cardDark : AppColors.dividerLight,
                                      child: Icon(
                                        Icons.person,
                                        size: 28,
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: isDark ? AppColors.cardDark : AppColors.dividerLight,
                                    child: Center(
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? AppColors.primaryGold
                                              : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                        ),
                                      ),
                                    ),
                                  ),
                  ),
                ),
                // Mini badge indicator for External & Songs ministers
                if (isExternal)
                  Positioned(
                    bottom: -1,
                    right: -1,
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.shade700,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppColors.cardDark : Colors.white,
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(Icons.public, size: 9, color: Colors.white),
                    ),
                  )
                else if (isSong)
                  Positioned(
                    bottom: -1,
                    right: -1,
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppColors.cardDark : Colors.white,
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(Icons.music_note, size: 9, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              name == 'All' || isOthers ? name : _formatSpeakerName(name),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? (isExternal ? Colors.cyanAccent.shade700 : AppColors.primaryGold)
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatSpeakerName(String fullName) {
    if (fullName.isEmpty) return fullName;

    // Abbreviate common religious titles to save horizontal space and reveal full names
    String formatted = fullName
        .replaceAll(RegExp(r'\bPastor\b', caseSensitive: false), 'Pst.')
        .replaceAll(RegExp(r'\bApostle\b', caseSensitive: false), 'Apst.')
        .replaceAll(RegExp(r'\bReverend\b', caseSensitive: false), 'Rev.')
        .replaceAll(RegExp(r'\bBishop\b', caseSensitive: false), 'Bsp.')
        .replaceAll(RegExp(r'\bEvangelist\b', caseSensitive: false), 'Evg.')
        .replaceAll(RegExp(r'\bDeaconess\b', caseSensitive: false), 'Dcns.')
        .replaceAll(RegExp(r'\bDeacon\b', caseSensitive: false), 'Dcn.')
        .replaceAll(RegExp(r'\bMinister\b', caseSensitive: false), 'Min.');

    final parts = formatted.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

    if (parts.length <= 1) {
      return formatted;
    }

    if (parts.length == 2) {
      return '${parts[0]}\n${parts[1]}';
    }

    // 3 or more parts e.g. ["Pst.", "John", "Doe"] -> "Pst. John\nDoe"
    final firstLine = parts.sublist(0, parts.length - 1).join(' ');
    final secondLine = parts.last;
    return '$firstLine\n$secondLine';
  }
}

class _AudioListItem extends StatelessWidget {
  final Sermon sermon;
  final bool isDark;
  final VoidCallback? onPlayTap;
  final VoidCallback? onCardTap;
  final bool isReadyToPlay;
  final bool isBuffering;
  final double bufferProgress;
  final bool isServiceTeamMember;
  final bool isGeneralMarried;
  final bool isInHouseMarried;
  final bool isNew;
  final bool isPlaying;

  const _AudioListItem({
    required this.sermon,
    required this.isDark,
    this.onPlayTap,
    this.onCardTap,
    this.isReadyToPlay = false,
    this.isBuffering = false,
    this.bufferProgress = 0.0,
    this.isServiceTeamMember = false,
    this.isGeneralMarried = false,
    this.isInHouseMarried = false,
    this.isNew = false,
    this.isPlaying = false,
  });

  bool get _isLocked =>
      (sermon.isServiceTeamOnly && !isServiceTeamMember) ||
      (sermon.isGeneralMarriedOnly && !isGeneralMarried) ||
      (sermon.isInHouseMarriedOnly && !isInHouseMarried);

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes <= 0) return '';
    final hours = d.inHours;
    final mins = d.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins > 0 ? '$mins m' : ''}';
    }
    return '$mins mins';
  }

  @override
  Widget build(BuildContext context) {
    final title = _stripHtml(sermon.title);
    final rawSpeaker = sermon.speaker?.trim() ?? '';
    final speaker = rawSpeaker.isNotEmpty ? rawSpeaker : 'The City Gate Church';
    final categoryName = sermon.categoryName.isNotEmpty ? sermon.categoryName : sermon.category;
    final durationStr = _formatDuration(sermon.duration);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPlaying
              ? AppColors.primaryGold
              : (isDark ? AppColors.dividerDark : Colors.grey.shade200),
          width: isPlaying ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onCardTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Artwork Thumbnail
                GestureDetector(
                  onTap: onPlayTap,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 58,
                          height: 58,
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                          child: sermon.imageUrl != null && sermon.imageUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: sermon.imageUrl!,
                                  cacheManager: CustomImageCacheManager.instance,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 116,
                                  memCacheHeight: 116,
                                  useOldImageOnUrlChange: true,
                                  fadeInDuration: Duration.zero,
                                  fadeOutDuration: Duration.zero,
                                  placeholder: (_, __) => Container(
                                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                                    child: const Icon(Icons.music_note_rounded, size: 24, color: AppColors.primaryGold),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                                    child: const Icon(Icons.music_note_rounded, size: 24, color: AppColors.primaryGold),
                                  ),
                                )
                              : const Icon(Icons.music_note_rounded, size: 24, color: AppColors.primaryGold),
                        ),
                      ),

                      // Animated wave when playing
                      if (isPlaying && !_isLocked)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const _WaveAnimation(),
                          ),
                        ),

                      // Locked icon
                      if (_isLocked)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Icon(Icons.lock_rounded, size: 20, color: Colors.white),
                            ),
                          ),
                        ),

                      // Ready / Prebuffered icon
                      if (isReadyToPlay && !_isLocked && !isPlaying)
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(Icons.play_arrow_rounded, size: 10, color: Colors.white),
                          ),
                        ),

                      // Buffering progress bar
                      if (isBuffering && !isReadyToPlay && !isPlaying)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.3),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(10),
                                bottomRight: Radius.circular(10),
                              ),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: bufferProgress,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryGold,
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // 2. Sermon Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: isPlaying
                              ? AppColors.primaryGold
                              : (isDark ? Colors.white : AppColors.textPrimaryLight),
                        ),
                      ),
                      const SizedBox(height: 3.5),

                      // Speaker Row (always present for uniform alignment)
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 13,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              speaker,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 3.5),

                      // Metadata Row (Date • Duration • Category pill • NEW badge)
                      Row(
                        children: [
                          Text(
                            _formatDate(sermon.date),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),

                          if (durationStr.isNotEmpty) ...[
                            const SizedBox(width: 5),
                            Text(
                              '• $durationStr',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.primaryGold,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],

                          if (categoryName.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  categoryName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ],

                          if (isNew) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Play Action Button
                GestureDetector(
                  onTap: onPlayTap,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isPlaying
                          ? AppColors.primaryGold
                          : AppColors.primaryGold.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 20,
                        color: isPlaying ? Colors.white : AppColors.primaryGold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Wave animation widget for playing indicator
class _WaveAnimation extends StatefulWidget {
  const _WaveAnimation();

  @override
  State<_WaveAnimation> createState() => _WaveAnimationState();
}

class _WaveAnimationState extends State<_WaveAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (index) {
            final delay = index * 0.15;
            final animValue = ((_controller.value + delay) % 1.0);
            final height = 8 + (animValue * 12);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: AppColors.primaryGold,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
