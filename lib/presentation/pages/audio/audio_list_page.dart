import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/sermon.dart';
import '../../../data/services/data_service.dart';
import '../../../data/services/download_service.dart';
import '../../../data/services/played_audio_service.dart';
import '../../../main.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_app_bar.dart';
import 'audio_player_page.dart';

enum FilterType { category, speaker }

class AudioListPage extends ConsumerStatefulWidget {
  final String category;
  final String? categoryId;
  final List<Sermon> audioItems;
  final List<String> categories;
  final Map<String, String>? categoryNameToId;
  final FilterType initialFilterType;
  final String? initialSpeaker;

  const AudioListPage({
    super.key,
    required this.category,
    this.categoryId,
    required this.audioItems,
    required this.categories,
    this.categoryNameToId,
    this.initialFilterType = FilterType.category,
    this.initialSpeaker,
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
          matchesFilter = audio.speaker?.toLowerCase() == _selectedSpeaker?.toLowerCase();
        }
      } else {
        // Filter by category
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Black status bar icons
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        appBar: const CustomAppBar(title: '', lightBackground: true),
        body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                ),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by title or speaker...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          // Filter type toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildFilterToggle('Category', FilterType.category, isDark),
                const SizedBox(width: 12),
                _buildFilterToggle('Minister', FilterType.speaker, isDark),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Category or Speaker filter list
          SizedBox(
            height: _filterType == FilterType.speaker ? 105 : 32,
            child: _filterType == FilterType.category
                ? _buildCategoryFilterList(isDark)
                : _buildSpeakerFilterList(isDark),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppColors.primaryGold,
              child: _filteredItems.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.4,
                          child: Center(
                            child: Text(
                              'No audio found',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Builder(
                      builder: (context) {
                        final audioProvider = ref.watch(audioPlayerChangeNotifierProvider);
                        final authProvider = ref.watch(authChangeNotifierProvider);
                        final downloadService = DownloadService();
                        final user = authProvider.user;
                        final isServiceTeamMember = user?.isServiceTeamMember ?? false;
                        final isGeneralMarried = user?.isGeneralMarried ?? false;
                        final isInHouseMarried = user?.isInHouseMarried ?? false;
                        return ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
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
                              onThumbnailTap: () {
                                if (isLocked) {
                                  _showLockedMessage(context, isDark);
                                  return;
                                }
                                audioProvider.setQueue(_filteredItems, index);
                                audioProvider.playSermon(audio);
                              },
                              onTitleTap: () {
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
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildFilterToggle(String label, FilterType type, bool isDark) {
    final isSelected = _filterType == type;
    return GestureDetector(
      onTap: () {
        if (_filterType != type) {
          setState(() {
            _filterType = type;
            if (type == FilterType.speaker) {
              _selectedSpeaker = null;
            } else {
              _selectedCategory = widget.category;
              _selectedCategoryId = widget.categoryId;
            }
            _filteredItems = _getFilteredItems(_searchController.text.toLowerCase());
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primaryGold 
              : (isDark ? AppColors.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? AppColors.primaryGold 
                : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected 
                ? Colors.white 
                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilterList(bool isDark) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: widget.categories.length,
      separatorBuilder: (_, __) => const SizedBox(width: 16),
      itemBuilder: (context, index) {
        final category = widget.categories[index];
        final isSelected = category == _selectedCategory && _filterType == FilterType.category;
        return GestureDetector(
          onTap: () => _selectCategory(category),
          child: Text(
            category,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? AppColors.maroon
                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpeakerFilterList(bool isDark) {
    // Get main speakers only
    final mainSpeakers = _speakerModels.where((s) => s.isMainSpeaker).toList();
    
    // Check if there are any non-main speakers in the content
    final hasOtherSpeakers = _speakers.any((speakerName) => !_isMainSpeaker(speakerName));
    
    if (mainSpeakers.isEmpty && !hasOtherSpeakers) {
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

    // Total count: All + main speakers + Others (if exists)
    final itemCount = 1 + mainSpeakers.length + (hasOtherSpeakers ? 1 : 0);

    return SizedBox(
      height: 105,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
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
          
          // Main speakers
          if (index <= mainSpeakers.length) {
            final speaker = mainSpeakers[index - 1];
            final isSelected = speaker.fullName == _selectedSpeaker;
            return _buildSpeakerChip(
              name: speaker.fullName,
              photoUrl: speaker.photoUrl,
              isSelected: isSelected,
              isDark: isDark,
              onTap: () => _selectSpeaker(speaker.fullName),
              isFullName: true,
            );
          }
          
          // "Others" option (last item if hasOtherSpeakers)
          final isSelected = _selectedSpeaker == 'Others';
          return _buildSpeakerChip(
            name: 'Others',
            photoUrl: null,
            isSelected: isSelected,
            isDark: isDark,
            onTap: () => _selectSpeaker('Others'),
            isOthers: true,
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 88,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primaryGold : Colors.transparent,
                  width: 3,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primaryGold.withValues(alpha: 0.3),
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
                                fit: BoxFit.cover,
                                memCacheWidth: 112,
                                memCacheHeight: 112,
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
            const SizedBox(height: 6),
            Text(
              name == 'All' || isOthers ? name : _formatSpeakerName(name),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? AppColors.primaryGold
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
  final VoidCallback? onThumbnailTap;
  final VoidCallback? onTitleTap;
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
    this.onThumbnailTap,
    this.onTitleTap,
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

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  String _getCategoryName() {
    if (sermon.categoryName.isNotEmpty) {
      return sermon.categoryName;
    } else if (sermon.category.isNotEmpty) {
      return sermon.category;
    }
    return '';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  String _getSpeakerAndTime() {
    final parts = <String>[];
    if (sermon.speaker != null && sermon.speaker!.isNotEmpty) {
      parts.add(sermon.speaker!);
    }
    parts.add(_formatTimeAgo(sermon.date));
    return parts.join(' - ');
  }

  Widget _buildImage(bool isDark) {
    if (sermon.imageUrl == null || sermon.imageUrl!.isEmpty) {
      return Icon(
        Icons.music_note,
        size: 20,
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      );
    }
    
    return CachedNetworkImage(
      imageUrl: sermon.imageUrl!,
      fit: BoxFit.cover,
      memCacheWidth: 100,
      memCacheHeight: 100,
      placeholder: (_, __) => Icon(
        Icons.music_note,
        size: 20,
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      ),
      errorWidget: (_, __, ___) => Icon(
        Icons.music_note,
        size: 20,
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Thumbnail - tap to play/pause without opening player
          GestureDetector(
            onTap: onThumbnailTap,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 50,
                    height: 50,
                    color: isDark ? AppColors.cardDark : AppColors.dividerLight,
                    child: _buildImage(isDark),
                  ),
                ),
                // Wave animation when playing
                if (isPlaying && !_isLocked)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const _WaveAnimation(),
                    ),
                  ),
                // Ready indicator (pre-buffered or downloaded) - only show when not playing
                if (isReadyToPlay && !_isLocked && !isPlaying)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                // Buffering progress indicator
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
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: bufferProgress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primaryGold,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Lock icon for service team only content
                if (_isLocked)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.lock,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Title area - tap to open player
          Expanded(
            child: GestureDetector(
              onTap: onTitleTap,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category (bold dark) - Title (regular dark)
                  RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        if (_getCategoryName().isNotEmpty) ...[
                          TextSpan(
                            text: _getCategoryName(),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          TextSpan(
                            text: ' - ',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ],
                        TextSpan(
                          text: '${_formatDate(sermon.date)} - ${sermon.title}',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Speaker - Time ago
                  Text(
                    _getSpeakerAndTime(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark.withValues(alpha: 0.7)
                              : AppColors.textSecondaryLight.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          if (isNew)
            Container(
              margin: const EdgeInsets.only(left: 8),
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
        ],
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
