import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/image_cache_manager.dart';
import '../../../core/utils/error_handler.dart';
import '../../../domain/entities/transcript.dart';
import '../../../data/services/data_service.dart';
import '../../../data/services/transcript_cache_service.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';

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

enum TranscriptFilterType { category, speaker }

class TranscriptListPage extends ConsumerStatefulWidget {
  final String category;
  final String? categoryId;
  final List<String> categories;
  final Map<String, String>? categoryNameToId;
  final TranscriptFilterType initialFilterType;
  final String? initialSpeaker;
  final String? categoryImageUrl;
  final String? categoryDescription;

  const TranscriptListPage({
    super.key,
    required this.category,
    this.categoryId,
    required this.categories,
    this.categoryNameToId,
    this.initialFilterType = TranscriptFilterType.category,
    this.initialSpeaker,
    this.categoryImageUrl,
    this.categoryDescription,
  });

  @override
  ConsumerState<TranscriptListPage> createState() => _TranscriptListPageState();
}

class _TranscriptListPageState extends ConsumerState<TranscriptListPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DataService _dataService = DataService();
  List<Transcript> _allItems = [];
  List<Transcript> _filteredItems = [];
  late String _selectedCategory;
  late String? _selectedCategoryId;
  late TranscriptFilterType _filterType;
  String? _selectedSpeaker;
  List<SpeakerModel> _speakerModels = [];
  List<String> _speakers = [];
  List<String> _displayCategories = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  
  static const String _cacheKey = 'cached_transcripts';

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.category;
    _selectedCategoryId = widget.categoryId;
    _filterType = widget.initialFilterType;
    _selectedSpeaker = widget.initialSpeaker;
    _displayCategories = List.from(widget.categories);
    _searchController.addListener(_filterTranscripts);
    _loadTranscripts();
  }

  Future<void> _loadTranscripts() async {
    setState(() => _isLoading = true);
    try {
      // Try to load from cache first
      final cachedTranscripts = await _loadCachedTranscripts();
      if (cachedTranscripts.isNotEmpty && mounted) {
        setState(() {
          _allItems = cachedTranscripts;
          _extractSpeakers();
          _extractCategories();
          _filteredItems = _getFilteredItems('');
          _isLoading = false;
        });
      }
      
      // Load speakers with photos
      final speakers = await _dataService.getSpeakers();
      if (mounted) {
        setState(() {
          _speakerModels = speakers;
        });
      }
      
      // Fetch fresh data from API
      final transcripts = await _dataService.getTranscripts(forceRefresh: true);
      if (mounted && transcripts.isNotEmpty) {
        setState(() {
          _allItems = transcripts;
          _extractSpeakers();
          _extractCategories();
          _filteredItems = _getFilteredItems('');
          _isLoading = false;
        });
        // Cache the transcripts
        _cacheTranscripts(transcripts);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<List<Transcript>> _loadCachedTranscripts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final List<dynamic> jsonList = json.decode(cached);
        return jsonList.map((j) => Transcript.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('Error loading cached transcripts: $e');
    }
    return [];
  }
  
  Future<void> _cacheTranscripts(List<Transcript> transcripts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = transcripts.map((t) => t.toJson()).toList();
      await prefs.setString(_cacheKey, json.encode(jsonList));
    } catch (e) {
      debugPrint('Error caching transcripts: $e');
    }
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    
    try {
      // Load speakers with photos
      final speakers = await _dataService.getSpeakers();
      final transcripts = await _dataService.getTranscripts(forceRefresh: true);
      if (mounted) {
        setState(() {
          _speakerModels = speakers;
          _allItems = transcripts;
          _extractSpeakers();
          _extractCategories();
          _filteredItems = _getFilteredItems(_searchController.text);
          _isRefreshing = false;
        });
        // Update cache
        _cacheTranscripts(transcripts);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshing = false);
        ErrorHandler.showError(context, e);
      }
    }
  }

  void _extractSpeakers() {
    final speakerSet = <String>{};
    for (var item in _allItems) {
      if (item.speaker != null && item.speaker!.isNotEmpty) {
        speakerSet.add(item.speaker!);
      }
    }
    _speakers = speakerSet.toList()..sort();
  }

  void _extractCategories() {
    final catSet = <String>{};
    for (var cat in widget.categories) {
      if (cat.trim().isNotEmpty) catSet.add(cat.trim());
    }
    for (var item in _allItems) {
      if (item.categoryName.trim().isNotEmpty) {
        catSet.add(item.categoryName.trim());
      }
    }
    _displayCategories = catSet.toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _filterTranscripts() {
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

  List<Transcript> _getFilteredItems(String query) {
    final filtered = _allItems.where((item) {
      bool matchesFilter = false;
      
      if (_filterType == TranscriptFilterType.speaker) {
        if (_selectedSpeaker == null || _selectedSpeaker == 'All') {
          matchesFilter = true;
        } else if (_selectedSpeaker == 'Others') {
          matchesFilter = !_isMainSpeaker(item.speaker);
        } else {
          matchesFilter = item.speaker?.toLowerCase() == _selectedSpeaker?.toLowerCase();
        }
      } else {
        matchesFilter = _selectedCategory == 'All';
        
        if (!matchesFilter) {
          if (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty) {
            matchesFilter = item.category == _selectedCategoryId;
          }
          if (!matchesFilter && item.categoryName.isNotEmpty) {
            matchesFilter = item.categoryName.toLowerCase() == _selectedCategory.toLowerCase();
          }
          if (!matchesFilter) {
            matchesFilter = item.category.toLowerCase() == _selectedCategory.toLowerCase();
          }
        }
      }
      
      final matchesSearch = query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          (item.description?.toLowerCase().contains(query) ?? false) ||
          (item.speaker?.toLowerCase().contains(query) ?? false);
      
      return matchesFilter && matchesSearch;
    }).toList();
    
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  void _selectCategory(String category) {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filterType = TranscriptFilterType.category;
      _selectedCategory = category;
      _selectedCategoryId = widget.categoryNameToId?[category];
      _selectedSpeaker = null;
      _filteredItems = _getFilteredItems(query);
    });
  }

  void _selectSpeaker(String speaker) {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filterType = TranscriptFilterType.speaker;
      _selectedSpeaker = speaker == 'All' ? null : speaker;
      _selectedCategory = 'All';
      _selectedCategoryId = null;
      _filteredItems = _getFilteredItems(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSpeakerMode = _filterType == TranscriptFilterType.speaker && _selectedSpeaker != null && _selectedSpeaker != 'All';

    String pageTitle = 'Transcripts';
    if (isSpeakerMode) {
      pageTitle = _formatSpeakerName(_selectedSpeaker!).replaceAll('\n', ' ');
    } else if (_selectedCategory != 'All') {
      pageTitle = _selectedCategory;
    }

    final audioProvider = ref.watch(audioPlayerChangeNotifierProvider);
    final hasMiniPlayer = audioProvider.currentSermon != null;
    final bottomInset = (hasMiniPlayer ? 140.0 : 90.0) + MediaQuery.of(context).padding.bottom;

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
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: AppColors.primaryGold,
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // 1. Hero Header
                        SliverToBoxAdapter(
                          child: _buildHeroHeader(isDark),
                        ),

                        // 2. Search Bar
                        SliverToBoxAdapter(
                          child: _buildSearchBar(isDark),
                        ),

                        // 3. Filter Section (Categories / Ministers)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildFilterSection(isDark),
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
                                  'Transcripts',
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

                        // 5. Transcripts List or Empty State
                        if (_filteredItems.isEmpty)
                          SliverToBoxAdapter(
                            child: _buildEmptyState(isDark),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: bottomInset,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final item = _filteredItems[index];
                                  return _TranscriptListItem(
                                    transcript: item,
                                    isDark: isDark,
                                    onTap: () => _openTranscript(context, item),
                                  );
                                },
                                childCount: _filteredItems.length,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  void _openTranscript(BuildContext context, Transcript transcript) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TranscriptViewPage(transcript: transcript),
      ),
    );
  }

  Widget _buildHeroHeader(bool isDark) {
    final isSpeakerMode = _filterType == TranscriptFilterType.speaker &&
        _selectedSpeaker != null &&
        _selectedSpeaker != 'All';

    String headerTypePill = 'TRANSCRIPT ARCHIVE';
    Color pillColor = AppColors.primaryGold;
    IconData pillIcon = Icons.menu_book_rounded;
    String displayTitle = _selectedCategory != 'All' ? _selectedCategory : 'All Transcripts';
    String subtitle = '${_filteredItems.length} Transcripts • Study & Sermon Notes';
    String? imageUrl = widget.categoryImageUrl;
    String? description = widget.categoryDescription;

    if (isSpeakerMode) {
      final selSpk = _selectedSpeaker!.toLowerCase().trim();
      final model = _speakerModels.where((s) =>
          s.fullName.toLowerCase().trim() == selSpk ||
          s.name.toLowerCase().trim() == selSpk ||
          selSpk.contains(s.fullName.toLowerCase().trim()) ||
          s.fullName.toLowerCase().trim().contains(selSpk)).firstOrNull;

      final isExternal = model?.isExternalMinister ?? false;
      final isSenior = model?.seniorPastor ?? false;
      final isMain = model?.isMainSpeaker ?? false;

      if (isExternal) {
        headerTypePill = 'GUEST MINISTER';
        pillColor = Colors.cyanAccent.shade700;
        pillIcon = Icons.public_rounded;
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
    } else if (_selectedCategory != 'All') {
      headerTypePill = 'STUDY ARCHIVE';
      pillColor = AppColors.primaryGold;
      pillIcon = Icons.auto_stories_rounded;
      displayTitle = _selectedCategory;
    }

    // Fallback image from first available item in filtered list if not already resolved
    if (!isSpeakerMode && (imageUrl == null || imageUrl.isEmpty) && _filteredItems.isNotEmpty) {
      for (final t in _filteredItems) {
        if (t.imageUrl != null && t.imageUrl!.isNotEmpty) {
          imageUrl = t.imageUrl;
          break;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSpeakerMode && (pillColor == Colors.cyanAccent.shade700)
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
              // Artwork / Avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(isSpeakerMode ? 38 : 14),
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
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          placeholder: (_, __) => _buildHeroPlaceholder(isSpeakerMode, isDark),
                          errorWidget: (_, __, ___) => _buildHeroPlaceholder(isSpeakerMode, isDark),
                        )
                      : _buildHeroPlaceholder(isSpeakerMode, isDark),
                ),
              ),
              const SizedBox(width: 14),

              // Title & Badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pill Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: pillColor.withValues(alpha: isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: pillColor.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(pillIcon, size: 10, color: pillColor),
                          const SizedBox(width: 4),
                          Text(
                            headerTypePill,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: pillColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Display Title
                    Text(
                      displayTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Subtitle / Count
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
              ),
            ),
          ],

          if (_filteredItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openTranscript(context, _filteredItems.first),
                    icon: const Icon(Icons.menu_book_rounded, size: 16),
                    label: const Text('Start Reading Latest'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGold,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroPlaceholder(bool isSpeaker, bool isDark) {
    if (isSpeaker) {
      return Container(
        color: isDark ? AppColors.cardDark : Colors.grey.shade100,
      );
    }
    return Container(
      color: isDark ? AppColors.cardDark : Colors.grey.shade100,
      child: Center(
        child: Icon(
          Icons.auto_stories_rounded,
          size: 34,
          color: AppColors.primaryGold.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
          decoration: InputDecoration(
            hintText: 'Search transcripts by title or speaker...',
            hintStyle: TextStyle(
              fontSize: 13.5,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.primaryGold,
              size: 20,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      size: 18,
                      color: isDark ? Colors.white60 : Colors.grey,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _filterTranscripts();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildFilterToggle('Category', TranscriptFilterType.category, isDark),
              const SizedBox(width: 8),
              _buildFilterToggle('Minister', TranscriptFilterType.speaker, isDark),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: _filterType == TranscriptFilterType.speaker ? 100 : 36,
          child: _filterType == TranscriptFilterType.category
              ? _buildCategoryFilterList(isDark)
              : _buildSpeakerFilterList(isDark),
        ),
      ],
    );
  }

  Widget _buildFilterToggle(String label, TranscriptFilterType type, bool isDark) {
    final isSelected = _filterType == type;
    return GestureDetector(
      onTap: () {
        if (_filterType != type) {
          setState(() {
            _filterType = type;
            if (type == TranscriptFilterType.speaker) {
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primaryGold 
              : (isDark ? AppColors.cardDark : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected 
                ? AppColors.primaryGold 
                : (isDark ? AppColors.dividerDark : Colors.grey.shade300),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              type == TranscriptFilterType.category
                  ? Icons.folder_open_rounded
                  : Icons.person_rounded,
              size: 14,
              color: isSelected 
                  ? Colors.white 
                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected 
                    ? Colors.white 
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilterList(bool isDark) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _displayCategories.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final category = _displayCategories[index];
        final isSelected = category == _selectedCategory && _filterType == TranscriptFilterType.category;
        return GestureDetector(
          onTap: () => _selectCategory(category),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryGold.withValues(alpha: isDark ? 0.35 : 0.15)
                  : (isDark ? AppColors.cardDark : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryGold
                    : (isDark ? AppColors.dividerDark : Colors.grey.shade300),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              category,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? AppColors.primaryGold
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpeakerFilterList(bool isDark) {
    final mainSpeakers = _speakerModels.where((s) => s.isMainSpeaker).toList();
    final hasOtherSpeakers = _speakers.any((speakerName) => !_isMainSpeaker(speakerName));
    
    if (mainSpeakers.isEmpty && !hasOtherSpeakers) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'No speakers available',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
      );
    }

    final itemCount = 1 + mainSpeakers.length + (hasOtherSpeakers ? 1 : 0);

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
        width: 82,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primaryGold : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primaryGold.withValues(alpha: 0.35),
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
                          size: 26,
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
                              size: 26,
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
                                memCacheWidth: 108,
                                memCacheHeight: 108,
                                fadeInDuration: const Duration(milliseconds: 0),
                                fadeOutDuration: const Duration(milliseconds: 0),
                                placeholder: (_, __) => Container(
                                  color: isDark ? AppColors.cardDark : AppColors.dividerLight,
                                  child: Icon(
                                    Icons.person,
                                    size: 26,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: isDark ? AppColors.cardDark : AppColors.dividerLight,
                                  child: Icon(
                                    Icons.person,
                                    size: 26,
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
                                      fontSize: 20,
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

    final firstLine = parts.sublist(0, parts.length - 1).join(' ');
    final secondLine = parts.last;
    return '$firstLine\n$secondLine';
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 56,
              color: isDark ? Colors.white24 : Colors.grey[400],
            ),
            const SizedBox(height: 14),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No transcripts match "${_searchController.text}"'
                  : 'No transcripts found in this collection',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Transcripts are published as sermon notes become available.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white38 : Colors.grey[500],
              ),
            ),
            if (_searchController.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  _filterTranscripts();
                },
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text('Clear search'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryGold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TranscriptListItem extends StatelessWidget {
  final Transcript transcript;
  final bool isDark;
  final VoidCallback? onTap;

  const _TranscriptListItem({
    required this.transcript,
    required this.isDark,
    this.onTap,
  });

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static String _calculateReadTime(Transcript transcript) {
    final text = transcript.content.isNotEmpty 
        ? transcript.content 
        : (transcript.description ?? '');
    if (text.isEmpty) return '3 min read';
    
    final wordCount = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final minutes = (wordCount / 200).ceil();
    final readMinutes = minutes < 1 ? 1 : minutes;
    return '$readMinutes min read';
  }

  String _getCategoryName() {
    if (transcript.categoryName.isNotEmpty) {
      return transcript.categoryName;
    } else if (transcript.category.isNotEmpty) {
      return transcript.category;
    }
    return '';
  }

  Widget _buildThumbnail(bool isDark) {
    Widget fallback = Container(
      color: isDark ? AppColors.cardDark : AppColors.dividerLight,
      child: Center(
        child: Icon(
          Icons.menu_book_rounded,
          size: 26,
          color: AppColors.primaryGold.withValues(alpha: 0.8),
        ),
      ),
    );

    if (transcript.imageUrl == null || transcript.imageUrl!.isEmpty) {
      return fallback;
    }

    if (transcript.imageUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: transcript.imageUrl!,
        cacheManager: CustomImageCacheManager.instance,
        fit: BoxFit.cover,
        memCacheWidth: 120,
        memCacheHeight: 120,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      );
    }

    return Image.asset(
      transcript.imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _stripHtml(transcript.title);
    final rawSpeaker = transcript.speaker?.trim() ?? '';
    final speaker = rawSpeaker.isNotEmpty ? rawSpeaker : 'The CityGate Church';
    final categoryName = _getCategoryName();
    final readTime = _calculateReadTime(transcript);
    final formattedDate = _formatDate(transcript.date);
    final hasPdf = transcript.pdfUrl != null && transcript.pdfUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : Colors.grey.shade200,
          width: 1.0,
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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Artwork Thumbnail
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 58,
                        height: 58,
                        color: isDark ? Colors.white10 : Colors.grey.shade100,
                        child: _buildThumbnail(isDark),
                      ),
                    ),
                    if (hasPdf)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGold,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PDF',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),

                // 2. Transcript Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 3.5),

                      // Speaker Row
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

                      // Metadata Row (Date • Reading time • Category)
                      Row(
                        children: [
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Text(
                              '•',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                          Text(
                            readTime,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primaryGold,
                            ),
                          ),
                          if (categoryName.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5),
                              child: Text(
                                '•',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                categoryName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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

                // 3. Read Pill Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primaryGold.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Read',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGold,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: AppColors.primaryGold,
                      ),
                    ],
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

class TranscriptViewPage extends ConsumerStatefulWidget {
  final Transcript? transcript;
  final String? overrideUrl;
  final String? overrideTitle;

  const TranscriptViewPage({
    super.key, 
    this.transcript,
    this.overrideUrl,
    this.overrideTitle,
  });

  @override
  ConsumerState<TranscriptViewPage> createState() => _TranscriptViewPageState();
}

class _TranscriptViewPageState extends ConsumerState<TranscriptViewPage> {
  late WebViewController _webViewController;
  final TranscriptCacheService _cacheService = TranscriptCacheService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() => _isLoading = false);
              // Inject CSS to lock content to device width
              _webViewController.runJavaScript('''
                (function() {
                  // Ensure viewport meta exists
                  var vp = document.querySelector('meta[name="viewport"]');
                  if (!vp) {
                    vp = document.createElement('meta');
                    vp.name = 'viewport';
                    document.head.appendChild(vp);
                  }
                  vp.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';

                  var style = document.createElement('style');
                  style.textContent = `
                    html, body {
                      max-width: 100vw !important;
                      overflow-x: hidden !important;
                      word-wrap: break-word !important;
                      overflow-wrap: break-word !important;
                      -webkit-text-size-adjust: 100% !important;
                    }
                    img, video, iframe, table, pre, code {
                      max-width: 100% !important;
                      height: auto !important;
                    }
                    table { table-layout: fixed !important; }
                    pre { white-space: pre-wrap !important; }
                  `;
                  document.head.appendChild(style);
                })();
              ''');
            }
          },
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      );
    
    _loadContent();
  }

  Future<void> _loadContent() async {
    if (widget.overrideUrl != null) {
      await _webViewController.loadRequest(Uri.parse(widget.overrideUrl!));
      return;
    }

    final transcriptId = widget.transcript?.id;
    if (transcriptId == null) return;
    
    final cachedHtml = await _cacheService.getCachedHtml(transcriptId);
    final baseUrl = ApiConstants.standaloneTranscriptUrl(transcriptId);
    if (cachedHtml != null && cachedHtml.isNotEmpty) {
      await _webViewController.loadHtmlString(_prepareHtml(cachedHtml), baseUrl: baseUrl);
      _cacheService.fetchAndCacheHtml(transcriptId);
    } else {
      final html = await _cacheService.fetchAndCacheHtml(transcriptId);
      if (html != null && mounted) {
        await _webViewController.loadHtmlString(_prepareHtml(html), baseUrl: baseUrl);
      } else {
        await _webViewController.loadRequest(Uri.parse(baseUrl));
      }
    }
  }

  /// Force a mobile layout before first paint so the page never renders "scattered".
  String _prepareHtml(String html) {
    const injection = '''
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  html, body { max-width: 100vw !important; overflow-x: hidden !important;
    word-wrap: break-word !important; overflow-wrap: break-word !important;
    -webkit-text-size-adjust: 100% !important; }
  img, video, iframe, table, pre, code { max-width: 100% !important; height: auto !important; }
  table { table-layout: fixed !important; }
  pre { white-space: pre-wrap !important; }
</style>
''';
    // Drop any existing viewport tag so ours wins
    final out = html.replaceAll(
      RegExp(r'<meta[^>]*name=["\x27]viewport["\x27][^>]*>', caseSensitive: false),
      '',
    );
    final headMatch = RegExp(r'<head(\s[^>]*)?>', caseSensitive: false).firstMatch(out);
    if (headMatch != null) {
      return out.replaceRange(headMatch.end, headMatch.end, injection);
    }
    return '<!DOCTYPE html><html><head>$injection</head><body>$out</body></html>';
  }

  Future<void> _shareTranscript() async {
    const playStoreLink = 'https://play.google.com/store/apps/details?id=com.tcgc.tcgc';
    final title = widget.overrideTitle ?? widget.transcript?.title ?? 'Sermon Transcript';
    final transcriptId = widget.transcript?.id ?? '';
    final imageUrl = widget.transcript?.imageUrl;
    
    final shareUrl = transcriptId.toString().isNotEmpty
        ? 'https://tcgc.thecitygatechurch.org/app/transcript/$transcriptId'
        : playStoreLink;
    
    final shareText = '''📖 "$title" - Sermon Transcript

Read the full transcript on the TCGC App:
$shareUrl

If you don't have the app installed yet, download it from Google Play Store:
$playStoreLink''';
    
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final file = await CustomImageCacheManager.instance.getSingleFile(imageUrl);
        if (await file.exists()) {
          await Share.shareXFiles(
            [XFile(file.path)],
            text: shareText,
            subject: title,
          );
          return;
        }
      } catch (e) {
        debugPrint('Error getting thumbnail for share: $e');
      }
    }

    await Share.share(shareText, subject: title);
  }

  Future<void> _openPdf() async {
    final pdfUrl = widget.transcript?.pdfUrl;
    if (pdfUrl == null || pdfUrl.isEmpty) {
      if (mounted) {
        ErrorHandler.showWarning(context, 'PDF not available for this transcript');
      }
      return;
    }

    try {
      final uri = Uri.parse(pdfUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          ErrorHandler.showError(context, 'Unable to open PDF. Please try again.');
        }
      }
    } catch (e) {
      debugPrint('Error opening PDF: $e');
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPdf = widget.transcript?.pdfUrl != null && widget.transcript!.pdfUrl!.isNotEmpty;

    final audioProvider = ref.watch(audioPlayerChangeNotifierProvider);
    final hasMiniPlayer = audioProvider.currentSermon != null;
    final bottomInset = 20.0 + MediaQuery.of(context).padding.bottom + (hasMiniPlayer ? 75.0 : 0.0);

    // For web platform, fall back to simple text display
    if (kIsWeb) {
      return _buildFallbackView(context, isDark, hasPdf, bottomInset);
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
      appBar: CustomAppBar(
        title: widget.overrideTitle ?? widget.transcript?.title ?? 'Transcript',
        showBackButton: true,
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: isDark ? Colors.white : Colors.black),
            onPressed: _shareTranscript,
          ),
        ],
      ),
      body: Stack(
        children: [
          // WebView content (full screen)
          WebViewWidget(controller: _webViewController),
          
          // Loading indicator
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGold),
            ),
          
          // Floating PDF button at bottom (if PDF exists)
          if (hasPdf)
            Positioned(
              left: 16,
              right: 16,
              bottom: bottomInset,
              child: _buildFloatingPdfButton(isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildFloatingPdfButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryGold, Color(0xFFB8860B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openPdf,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'View PDF Version',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.open_in_new,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackView(BuildContext context, bool isDark, bool hasPdf, double bottomInset) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
      appBar: CustomAppBar(
        title: widget.overrideTitle ?? widget.transcript?.title ?? 'Transcript',
        showBackButton: true,
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: isDark ? Colors.white : Colors.black),
            onPressed: _shareTranscript,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, hasPdf ? (bottomInset + 70) : (bottomInset + 10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.overrideTitle ?? widget.transcript?.title ?? 'Transcript',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  widget.transcript?.content ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.8,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
          
          // Floating PDF button
          if (hasPdf)
            Positioned(
              left: 16,
              right: 16,
              bottom: bottomInset,
              child: _buildFloatingPdfButton(isDark),
            ),
        ],
      ),
    );
  }
}
