import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/audio_player_provider.dart';
import '../../../domain/entities/sermon.dart';
import '../../widgets/custom_app_bar.dart';
import 'audio_player_page.dart';

enum FilterType { category, speaker }

class AudioListPage extends StatefulWidget {
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
  State<AudioListPage> createState() => _AudioListPageState();
}

class _AudioListPageState extends State<AudioListPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Sermon> _filteredItems = [];
  late String _selectedCategory;
  late String? _selectedCategoryId;
  late FilterType _filterType;
  String? _selectedSpeaker;
  List<String> _speakers = [];
  int _preBufferedUpTo = 0; // Track how many items have been pre-buffered

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.category;
    _selectedCategoryId = widget.categoryId;
    _filterType = widget.initialFilterType;
    _selectedSpeaker = widget.initialSpeaker;
    _extractSpeakers();
    _filteredItems = _getFilteredItems('');
    _searchController.addListener(_filterAudio);
    _scrollController.addListener(_onScroll);
    
    // Pre-buffer audio files for instant playback immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preBufferInitial();
    });
  }
  
  void _preBufferInitial() {
    final audioProvider = Provider.of<AudioPlayerProvider>(context, listen: false);
    // Pre-buffer first 20 items (~3 min each) for instant playback
    audioProvider.preBufferSermons(_filteredItems, count: 20);
    _preBufferedUpTo = 20;
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
    
    final audioProvider = Provider.of<AudioPlayerProvider>(context, listen: false);
    // Pre-buffer next 10 items when user scrolls near the end
    audioProvider.preBufferMore(_filteredItems, _preBufferedUpTo, count: 10);
    _preBufferedUpTo += 10;
  }

  void _extractSpeakers() {
    final speakerSet = <String>{};
    for (var audio in widget.audioItems) {
      if (audio.speaker != null && audio.speaker!.isNotEmpty) {
        speakerSet.add(audio.speaker!);
      }
    }
    _speakers = speakerSet.toList()..sort();
  }

  @override
  void dispose() {
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

  List<Sermon> _getFilteredItems(String query) {
    debugPrint('Filtering: filterType=$_filterType, category=$_selectedCategory, speaker=$_selectedSpeaker');
    debugPrint('Total audio items: ${widget.audioItems.length}');
    
    final filtered = widget.audioItems.where((audio) {
      bool matchesFilter = false;
      
      if (_filterType == FilterType.speaker) {
        // Filter by speaker
        if (_selectedSpeaker == null || _selectedSpeaker == 'All') {
          matchesFilter = true;
        } else {
          matchesFilter = audio.speaker?.toLowerCase() == _selectedSpeaker?.toLowerCase();
        }
      } else {
        // Filter by category
        matchesFilter = _selectedCategory == 'All';
        
        if (!matchesFilter) {
          // Try matching by category ID first
          if (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty) {
            matchesFilter = audio.category == _selectedCategoryId;
          }
          // Also try matching by category name
          if (!matchesFilter && audio.categoryName.isNotEmpty) {
            matchesFilter = audio.categoryName.toLowerCase() == _selectedCategory.toLowerCase();
          }
          // Last resort: try matching category field against name
          if (!matchesFilter) {
            matchesFilter = audio.category.toLowerCase() == _selectedCategory.toLowerCase();
          }
        }
      }
      
      final matchesSearch = query.isEmpty ||
          audio.title.toLowerCase().contains(query) ||
          audio.description.toLowerCase().contains(query) ||
          (audio.speaker?.toLowerCase().contains(query) ?? false);
      
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

    return Scaffold(
      appBar: const CustomAppBar(title: ''),
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
                _buildFilterToggle('Speaker', FilterType.speaker, isDark),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Category or Speaker filter list
          SizedBox(
            height: 32,
            child: _filterType == FilterType.category
                ? _buildCategoryFilterList(isDark)
                : _buildSpeakerFilterList(isDark),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(
                    child: Text(
                      'No audio found',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                    ),
                  )
                : Consumer<AudioPlayerProvider>(
                    builder: (context, audioProvider, child) {
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final audio = _filteredItems[index];
                          final isPreBuffered = audioProvider.isPreBuffered(audio.id);
                          final isBuffering = audioProvider.isBuffering(audio.id);
                          final bufferProgress = audioProvider.getBufferProgress(audio.id);
                          return _AudioListItem(
                            sermon: audio,
                            isDark: isDark,
                            isPreBuffered: isPreBuffered,
                            isBuffering: isBuffering,
                            bufferProgress: bufferProgress,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AudioPlayerPage(sermon: audio),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
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
    if (_speakers.isEmpty) {
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

    final speakersWithAll = ['All', ..._speakers];
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: speakersWithAll.length,
      separatorBuilder: (_, __) => const SizedBox(width: 16),
      itemBuilder: (context, index) {
        final speaker = speakersWithAll[index];
        final isSelected = (speaker == 'All' && _selectedSpeaker == null) ||
            speaker == _selectedSpeaker;
        return GestureDetector(
          onTap: () => _selectSpeaker(speaker == 'All' ? 'All' : speaker),
          child: Text(
            speaker,
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
}

class _AudioListItem extends StatelessWidget {
  final Sermon sermon;
  final bool isDark;
  final VoidCallback? onTap;
  final bool isPreBuffered;
  final bool isBuffering;
  final double bufferProgress;

  const _AudioListItem({
    required this.sermon,
    required this.isDark,
    this.onTap,
    this.isPreBuffered = false,
    this.isBuffering = false,
    this.bufferProgress = 0.0,
  });

  Widget _buildImage(bool isDark) {
    if (sermon.imageUrl == null || sermon.imageUrl!.isEmpty) {
      return Container(
        color: isDark ? AppColors.cardDark : AppColors.dividerLight,
        child: Icon(
          Icons.music_note,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
      );
    }
    if (sermon.imageUrl!.startsWith('http')) {
      return Image.network(
        sermon.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: isDark ? AppColors.cardDark : AppColors.dividerLight,
        ),
      );
    }
    return Image.asset(
      sermon.imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: isDark ? AppColors.cardDark : AppColors.dividerLight,
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Stack(
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
                // Buffering progress indicator
                if (isBuffering && !isPreBuffered)
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
                // Ready indicator for pre-buffered audio (3 min ready)
                if (isPreBuffered)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.bolt,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sermon.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sermon.speaker != null && sermon.speaker!.isNotEmpty
                        ? '${sermon.speaker} - ${_formatTimeAgo(sermon.date)}'
                        : _formatTimeAgo(sermon.date),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
}
