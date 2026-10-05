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
import '../../../core/providers/audio_player_provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/image_cache_manager.dart';
import '../../../core/utils/error_handler.dart';
import '../../../domain/entities/transcript.dart';
import '../../../data/services/data_service.dart';
import '../../../data/services/transcript_cache_service.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';

enum TranscriptFilterType { category, speaker }

class TranscriptListPage extends ConsumerStatefulWidget {
  final String category;
  final String? categoryId;
  final List<String> categories;
  final Map<String, String>? categoryNameToId;
  final TranscriptFilterType initialFilterType;
  final String? initialSpeaker;

  const TranscriptListPage({
    super.key,
    required this.category,
    this.categoryId,
    required this.categories,
    this.categoryNameToId,
    this.initialFilterType = TranscriptFilterType.category,
    this.initialSpeaker,
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        appBar: const CustomAppBar(title: '', lightBackground: true),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
            : Column(
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildFilterToggle('Category', TranscriptFilterType.category, isDark),
                  const SizedBox(width: 12),
                  _buildFilterToggle('Minister', TranscriptFilterType.speaker, isDark),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: _filterType == TranscriptFilterType.speaker ? 105 : 32,
              child: _filterType == TranscriptFilterType.category
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
                                'No transcripts found',
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
                          final hasMiniPlayer = audioProvider.currentSermon != null;
                          final bottomInset = (hasMiniPlayer ? 140.0 : 90.0) + MediaQuery.of(context).padding.bottom;
                          return ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.only(
                              left: 20,
                              right: 20,
                              top: 8,
                              bottom: bottomInset,
                            ),
                            itemCount: _filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = _filteredItems[index];
                              return _TranscriptListItem(
                                transcript: item,
                                isDark: isDark,
                                onTap: () => _openTranscript(context, item),
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

  void _openTranscript(BuildContext context, Transcript transcript) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TranscriptViewPage(transcript: transcript),
      ),
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
      itemCount: _displayCategories.length,
      separatorBuilder: (_, __) => const SizedBox(width: 16),
      itemBuilder: (context, index) {
        final category = _displayCategories[index];
        final isSelected = category == _selectedCategory && _filterType == TranscriptFilterType.category;
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
            // "All" option
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
                                cacheManager: CustomImageCacheManager.instance,
                                fit: BoxFit.cover,
                                memCacheWidth: 112,
                                memCacheHeight: 112,
                                fadeInDuration: const Duration(milliseconds: 0),
                                fadeOutDuration: const Duration(milliseconds: 0),
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

class _TranscriptListItem extends StatelessWidget {
  final Transcript transcript;
  final bool isDark;
  final VoidCallback? onTap;

  const _TranscriptListItem({
    required this.transcript,
    required this.isDark,
    this.onTap,
  });

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
    if (transcript.categoryName.isNotEmpty) {
      return transcript.categoryName;
    } else if (transcript.category.isNotEmpty) {
      return transcript.category;
    }
    return '';
  }

  String _getSpeakerAndTime() {
    final parts = <String>[];
    if (transcript.speaker != null && transcript.speaker!.isNotEmpty) {
      parts.add(transcript.speaker!);
    }
    parts.add(_formatTimeAgo(transcript.date));
    return parts.join(' - ');
  }

  Widget _buildImage(bool isDark) {
    if (transcript.imageUrl == null || transcript.imageUrl!.isEmpty) {
      return Container(
        color: isDark ? AppColors.cardDark : AppColors.dividerLight,
        child: Icon(
          Icons.article,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
      );
    }
    if (transcript.imageUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: transcript.imageUrl!,
        cacheManager: CustomImageCacheManager.instance,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 0),
        fadeOutDuration: const Duration(milliseconds: 0),
        placeholder: (context, url) => Container(
          color: isDark ? AppColors.cardDark : AppColors.dividerLight,
        ),
        errorWidget: (context, url, error) => Container(
          color: isDark ? AppColors.cardDark : AppColors.dividerLight,
        ),
      );
    }
    return Image.asset(
      transcript.imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: isDark ? AppColors.cardDark : AppColors.dividerLight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
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
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          text: transcript.title,
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
          ],
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
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() => _isLoading = false);
              // Inject CSS to ensure proper rendering
              _webViewController.runJavaScript('''
                document.body.style.overflowX = 'hidden';
                document.body.style.wordWrap = 'break-word';
                document.body.style.overflowWrap = 'break-word';
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
    if (cachedHtml != null && cachedHtml.isNotEmpty) {
      await _webViewController.loadHtmlString(cachedHtml);
      _cacheService.fetchAndCacheHtml(transcriptId);
    } else {
      final html = await _cacheService.fetchAndCacheHtml(transcriptId);
      if (html != null && mounted) {
        await _webViewController.loadHtmlString(html);
      } else {
        final transcriptUrl = ApiConstants.standaloneTranscriptUrl(transcriptId);
        await _webViewController.loadRequest(Uri.parse(transcriptUrl));
      }
    }
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
