import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/sermon.dart';
import '../../widgets/custom_app_bar.dart';
import 'audio_player_page.dart';

class AudioListPage extends StatefulWidget {
  final String category;
  final String? categoryId;
  final List<Sermon> audioItems;
  final List<String> categories;
  final Map<String, String>? categoryNameToId;

  const AudioListPage({
    super.key,
    required this.category,
    this.categoryId,
    required this.audioItems,
    required this.categories,
    this.categoryNameToId,
  });

  @override
  State<AudioListPage> createState() => _AudioListPageState();
}

class _AudioListPageState extends State<AudioListPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Sermon> _filteredItems = [];
  late String _selectedCategory;
  late String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.category;
    _selectedCategoryId = widget.categoryId;
    _filteredItems = _getFilteredItems('');
    _searchController.addListener(_filterAudio);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterAudio() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _getFilteredItems(query);
    });
  }

  List<Sermon> _getFilteredItems(String query) {
    debugPrint('Filtering: category=$_selectedCategory, categoryId=$_selectedCategoryId');
    debugPrint('Total audio items: ${widget.audioItems.length}');
    
    final filtered = widget.audioItems.where((audio) {
      bool matchesCategory = _selectedCategory == 'All';
      
      if (!matchesCategory) {
        // Try matching by category ID first
        if (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty) {
          matchesCategory = audio.category == _selectedCategoryId;
        }
        // Also try matching by category name
        if (!matchesCategory && audio.categoryName.isNotEmpty) {
          matchesCategory = audio.categoryName.toLowerCase() == _selectedCategory.toLowerCase();
        }
        // Last resort: try matching category field against name
        if (!matchesCategory) {
          matchesCategory = audio.category.toLowerCase() == _selectedCategory.toLowerCase();
        }
      }
      
      final matchesSearch = query.isEmpty ||
          audio.title.toLowerCase().contains(query) ||
          audio.description.toLowerCase().contains(query);
      
      return matchesCategory && matchesSearch;
    }).toList();
    
    debugPrint('Filtered items: ${filtered.length}');
    return filtered;
  }

  void _selectCategory(String category) {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _selectedCategory = category;
      _selectedCategoryId = widget.categoryNameToId?[category];
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
                  hintText: '',
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
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: widget.categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final category = widget.categories[index];
                final isSelected = category == _selectedCategory;
                return GestureDetector(
                  onTap: () => _selectCategory(category),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? AppColors.maroon
                          : (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight),
                    ),
                  ),
                );
              },
            ),
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
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final audio = _filteredItems[index];
                      return _AudioListItem(
                        sermon: audio,
                        isDark: isDark,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AudioPlayerPage(sermon: audio),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AudioListItem extends StatelessWidget {
  final Sermon sermon;
  final bool isDark;
  final VoidCallback? onTap;

  const _AudioListItem({
    required this.sermon,
    required this.isDark,
    this.onTap,
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
                    'Pastor Dimeji Elugbadebo - ${_formatTimeAgo(sermon.date)}',
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
