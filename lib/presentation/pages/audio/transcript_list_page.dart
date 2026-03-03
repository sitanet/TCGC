import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../domain/entities/sermon.dart';
import '../../../data/services/data_service.dart';
import '../../widgets/custom_app_bar.dart';

String _stripHtmlTags(String htmlText) {
  // Convert block-level tags to double newlines for paragraphs
  String text = htmlText
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'</div>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<div[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</h[1-6]>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<h[1-6][^>]*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'</?ul[^>]*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</?ol[^>]*>', caseSensitive: false), '\n');
  
  // Remove remaining HTML tags
  text = text.replaceAll(RegExp(r'<[^>]*>'), '');
  
  // Decode HTML entities
  text = text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&rsquo;', "'")
      .replaceAll('&lsquo;', "'")
      .replaceAll('&rdquo;', '"')
      .replaceAll('&ldquo;', '"')
      .replaceAll('&mdash;', '—')
      .replaceAll('&ndash;', '–')
      .replaceAll('&hellip;', '...')
      .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
        final code = int.tryParse(match.group(1) ?? '');
        return code != null ? String.fromCharCode(code) : '';
      });
  
  // Normalize whitespace: collapse multiple spaces and normalize newlines
  text = text
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n[ \t]+'), '\n')
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  
  return text.trim();
}

enum TranscriptFilterType { category, speaker }

class TranscriptListPage extends StatefulWidget {
  final String category;
  final String? categoryId;
  final List<Sermon> sermons;
  final List<String> categories;
  final Map<String, String>? categoryNameToId;
  final TranscriptFilterType initialFilterType;
  final String? initialSpeaker;

  const TranscriptListPage({
    super.key,
    required this.category,
    this.categoryId,
    required this.sermons,
    required this.categories,
    this.categoryNameToId,
    this.initialFilterType = TranscriptFilterType.category,
    this.initialSpeaker,
  });

  @override
  State<TranscriptListPage> createState() => _TranscriptListPageState();
}

class _TranscriptListPageState extends State<TranscriptListPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DataService _dataService = DataService();
  List<Sermon> _allItems = [];
  List<Sermon> _filteredItems = [];
  late String _selectedCategory;
  late String? _selectedCategoryId;
  late TranscriptFilterType _filterType;
  String? _selectedSpeaker;
  List<String> _speakers = [];
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _allItems = widget.sermons; // Show all sermons, not just those with transcripts
    _selectedCategory = widget.category;
    _selectedCategoryId = widget.categoryId;
    _filterType = widget.initialFilterType;
    _selectedSpeaker = widget.initialSpeaker;
    _extractSpeakers();
    _filteredItems = _getFilteredItems('');
    _searchController.addListener(_filterTranscripts);
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    
    try {
      final sermons = await _dataService.getMessages(forceRefresh: true);
      if (mounted) {
        setState(() {
          _allItems = sermons;
          _extractSpeakers();
          _filteredItems = _getFilteredItems(_searchController.text);
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to refresh')),
        );
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

  List<Sermon> _getFilteredItems(String query) {
    final filtered = _allItems.where((item) {
      bool matchesFilter = false;
      
      if (_filterType == TranscriptFilterType.speaker) {
        if (_selectedSpeaker == null || _selectedSpeaker == 'All') {
          matchesFilter = true;
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
          item.description.toLowerCase().contains(query) ||
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildFilterToggle('Category', TranscriptFilterType.category, isDark),
                  const SizedBox(width: 12),
                  _buildFilterToggle('Speaker', TranscriptFilterType.speaker, isDark),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 32,
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
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          return _TranscriptListItem(
                            sermon: item,
                            isDark: isDark,
                            onTap: () => _openTranscript(context, item),
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
      itemCount: widget.categories.length,
      separatorBuilder: (_, __) => const SizedBox(width: 16),
      itemBuilder: (context, index) {
        final category = widget.categories[index];
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

  void _openTranscript(BuildContext context, Sermon sermon) {
    if (sermon.transcript == null || sermon.transcript!.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 12),
              const Text('Not Available'),
            ],
          ),
          content: const Text(
            'The transcript for this message is not yet available. Please check back later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'OK',
                style: TextStyle(color: AppColors.primaryGold),
              ),
            ),
          ],
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TranscriptViewPage(sermon: sermon),
      ),
    );
  }
}

class _TranscriptListItem extends StatelessWidget {
  final Sermon sermon;
  final bool isDark;
  final VoidCallback? onTap;

  const _TranscriptListItem({
    required this.sermon,
    required this.isDark,
    this.onTap,
  });

  bool get _hasTranscript => sermon.transcript != null && sermon.transcript!.isNotEmpty;

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
      return Container(
        color: isDark ? AppColors.cardDark : AppColors.dividerLight,
        child: Icon(
          Icons.article,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
      );
    }
    if (sermon.imageUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: sermon.imageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: isDark ? AppColors.cardDark : AppColors.dividerLight,
        ),
        errorWidget: (context, url, error) => Container(
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: _hasTranscript ? 1.0 : 0.6,
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
                            text: sermon.title,
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
                    if (_hasTranscript)
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
                      )
                    else
                      Text(
                        'Not available yet',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.orange,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
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
}

class TranscriptViewPage extends StatefulWidget {
  final Sermon sermon;

  const TranscriptViewPage({super.key, required this.sermon});

  @override
  State<TranscriptViewPage> createState() => _TranscriptViewPageState();
}

class _TranscriptViewPageState extends State<TranscriptViewPage> {
  double _fontSize = 16.0;
  final ScrollController _scrollController = ScrollController();
  double _scrollProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollProgress);
  }

  void _updateScrollProgress() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0) {
        setState(() {
          _scrollProgress = _scrollController.offset / maxScroll;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollProgress);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = Responsive.horizontalPadding(context);
    final rawTranscript = widget.sermon.transcript ?? '';
    final plainText = _stripHtmlTags(rawTranscript);
    final wordCount = plainText.split(RegExp(r'\s+')).length;
    final readTime = (wordCount / 200).ceil();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFFAFAFA),
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildSliverAppBar(context, isDark),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, isDark, padding, readTime, wordCount),
                  _buildTranscriptContent(context, isDark, padding, rawTranscript),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: _buildFontSizeControls(isDark),
        bottomNavigationBar: _buildProgressBar(isDark),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.share, color: Colors.white, size: 20),
          ),
          onPressed: () => _shareTranscript(context),
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.copy, color: Colors.white, size: 20),
          ),
          onPressed: () => _copyTranscript(context),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.sermon.imageUrl != null && widget.sermon.imageUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: widget.sermon.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.primaryGold.withOpacity(0.2),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.primaryGold.withOpacity(0.2),
                  child: Icon(
                    Icons.description,
                    size: 60,
                    color: AppColors.primaryGold.withOpacity(0.5),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryGold.withOpacity(0.8),
                      AppColors.primaryGold.withOpacity(0.4),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.article,
                    size: 60,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, double padding, int readTime, int wordCount) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'MESSAGE TRANSCRIPT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryGold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.sermon.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                  height: 1.3,
                ),
          ),
          const SizedBox(height: 12),
          if (widget.sermon.speaker != null && widget.sermon.speaker!.isNotEmpty)
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primaryGold.withOpacity(0.2),
                  child: Icon(
                    Icons.person,
                    size: 18,
                    color: AppColors.primaryGold,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.sermon.speaker!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Divider(color: isDark ? AppColors.dividerDark : AppColors.dividerLight),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(Icons.calendar_today_outlined, _formatDate(widget.sermon.date), isDark),
              const SizedBox(width: 16),
              _buildInfoChip(Icons.schedule_outlined, '$readTime min read', isDark),
              const SizedBox(width: 16),
              _buildInfoChip(Icons.text_fields, '$wordCount words', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark ? Colors.grey[500] : Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTranscriptContent(BuildContext context, bool isDark, double padding, String transcript) {
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final bgColor = isDark ? AppColors.cardDark : Colors.grey[100];
    
    return Container(
      margin: EdgeInsets.all(padding),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Html(
        data: transcript,
        style: {
          "body": Style(
            fontSize: FontSize(_fontSize),
            lineHeight: LineHeight(1.8),
            color: secondaryColor,
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            letterSpacing: 0.3,
          ),
          "h1": Style(
            fontSize: FontSize(_fontSize + 12),
            fontWeight: FontWeight.bold,
            color: textColor,
            margin: Margins.only(bottom: 16, top: 24),
          ),
          "h2": Style(
            fontSize: FontSize(_fontSize + 8),
            fontWeight: FontWeight.bold,
            color: textColor,
            margin: Margins.only(bottom: 12, top: 20),
          ),
          "h3": Style(
            fontSize: FontSize(_fontSize + 4),
            fontWeight: FontWeight.bold,
            color: textColor,
            margin: Margins.only(bottom: 10, top: 16),
          ),
          "p": Style(
            fontSize: FontSize(_fontSize),
            lineHeight: LineHeight(1.8),
            color: secondaryColor,
            margin: Margins.only(bottom: 12),
          ),
          "strong": Style(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
          "b": Style(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
          "em": Style(
            fontStyle: FontStyle.italic,
          ),
          "i": Style(
            fontStyle: FontStyle.italic,
          ),
          "u": Style(
            textDecoration: TextDecoration.underline,
          ),
          "blockquote": Style(
            backgroundColor: bgColor,
            padding: HtmlPaddings.all(16),
            margin: Margins.symmetric(vertical: 16),
            border: Border(
              left: BorderSide(
                color: AppColors.primaryGold,
                width: 4,
              ),
            ),
            fontStyle: FontStyle.italic,
            color: textColor,
          ),
          "ul": Style(
            margin: Margins.only(bottom: 12, left: 8),
          ),
          "ol": Style(
            margin: Margins.only(bottom: 12, left: 8),
          ),
          "li": Style(
            margin: Margins.only(bottom: 6),
            lineHeight: LineHeight(1.6),
          ),
          "a": Style(
            color: AppColors.primaryGold,
            textDecoration: TextDecoration.underline,
          ),
        },
        onLinkTap: (url, _, __) async {
          if (url != null) {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        },
      ),
    );
  }

  Widget _buildFontSizeControls(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.text_decrease, size: 20),
            onPressed: _fontSize > 12
                ? () => setState(() => _fontSize -= 2)
                : null,
            color: AppColors.primaryGold,
          ),
          Text(
            '${_fontSize.toInt()}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.text_increase, size: 20),
            onPressed: _fontSize < 28
                ? () => setState(() => _fontSize += 2)
                : null,
            color: AppColors.primaryGold,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(bool isDark) {
    return Container(
      height: 4,
      color: isDark ? AppColors.cardDark : Colors.grey[200],
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: _scrollProgress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryGold,
                AppColors.primaryGold.withOpacity(0.7),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _shareTranscript(BuildContext context) {
    final transcript = _stripHtmlTags(widget.sermon.transcript ?? '');
    final title = widget.sermon.title;
    final speaker = widget.sermon.speaker ?? '';
    
    final shareText = '''$title
${speaker.isNotEmpty ? 'By $speaker\n' : ''}
$transcript''';
    
    Share.share(shareText, subject: title);
  }

  void _copyTranscript(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _stripHtmlTags(widget.sermon.transcript ?? '')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transcript copied to clipboard'),
        backgroundColor: AppColors.primaryGold,
      ),
    );
  }
}
