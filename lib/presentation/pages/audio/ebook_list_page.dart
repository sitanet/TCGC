import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_cache_manager.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/services/api_service.dart';
import '../../../domain/entities/ebook.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point — shown as the "Library" tab in AudioPage
// Shows ebook categories. Tap a category → EbookCategoryPage
// ─────────────────────────────────────────────────────────────────────────────
class EbookListPage extends StatefulWidget {
  const EbookListPage({super.key});

  @override
  State<EbookListPage> createState() => _EbookListPageState();
}

class _EbookListPageState extends State<EbookListPage> {
  final ApiService _api = ApiService();
  static const String _cacheKey = 'cached_ebooks';

  List<Ebook> _allEbooks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEbooks();
  }

  Future<void> _loadEbooks() async {
    setState(() => _isLoading = true);
    try {
      final cached = await _loadCached();
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _allEbooks = cached;
          _isLoading = false;
        });
      }
      final fresh = await _fetchFromServer();
      if (fresh != null && mounted) {
        setState(() {
          _allEbooks = fresh;
          _isLoading = false;
        });
        await _saveCache(fresh);
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('EbookListPage: error loading: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Ebook>?> _fetchFromServer() async {
    try {
      final res = await _api.get(ApiConstants.ebooks);
      if (res.isSuccess) {
        final list = res.data is List
            ? res.data as List
            : (res.data['results'] ?? res.data['data'] ?? []) as List;
        return list.map((e) => Ebook.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('EbookListPage: server fetch error: $e');
    }
    return null;
  }

  Future<List<Ebook>> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final List<dynamic> jsonList = json.decode(cached);
        return jsonList.map((j) => Ebook.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('EbookListPage: cache load error: $e');
    }
    return [];
  }

  Future<void> _saveCache(List<Ebook> ebooks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        json.encode(ebooks.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('EbookListPage: cache save error: $e');
    }
  }

  List<_EbookCategory> _buildCategories() {
    final Map<String, _EbookCategory> map = {};
    for (final ebook in _allEbooks) {
      final key = ebook.category;
      if (map.containsKey(key)) {
        map[key]!.count++;
        if (ebook.coverImageUrl != null && map[key]!.coverUrl == null) {
          map[key]!.coverUrl = ebook.coverImageUrl;
        }
      } else {
        map[key] = _EbookCategory(
          id: key,
          name: ebook.categoryName.isNotEmpty ? ebook.categoryName : 'General',
          coverUrl: ebook.coverImageUrl,
          count: 1,
        );
      }
    }
    final list = map.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading && _allEbooks.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      );
    }

    final categories = _buildCategories();

    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: AppColors.primaryGold.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No eBooks available yet',
              style: TextStyle(
                fontSize: 16,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadEbooks,
              icon: const Icon(Icons.refresh, color: AppColors.primaryGold),
              label: const Text(
                'Refresh',
                style: TextStyle(color: AppColors.primaryGold),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryGold,
      onRefresh: _loadEbooks,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: categories.length,
        itemBuilder: (ctx, i) => _buildCategoryCard(ctx, isDark, categories[i]),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    bool isDark,
    _EbookCategory category,
  ) {
    final ebooksInCategory = _allEbooks
        .where((e) => e.category == category.id)
        .toList();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              EbookCategoryPage(category: category, ebooks: ebooksInCategory),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14),
              ),
              child: SizedBox(
                width: 80,
                height: 80,
                child: category.coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: category.coverUrl!,
                        cacheManager: CustomImageCacheManager.instance,
                        fit: BoxFit.cover,
                        useOldImageOnUrlChange: true,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        placeholder: (_, __) => _placeholder(isDark),
                        errorWidget: (_, __, ___) => _placeholder(isDark),
                      )
                    : _placeholder(isDark),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    category.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${category.count} book${category.count != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.chevron_right,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(bool isDark) {
    return Container(
      color: isDark ? AppColors.backgroundDark : const Color(0xFFF0EDE6),
      child: Center(
        child: Icon(
          Icons.menu_book_rounded,
          size: 32,
          color: AppColors.primaryGold.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category model
// ─────────────────────────────────────────────────────────────────────────────
class _EbookCategory {
  final String id;
  final String name;
  String? coverUrl;
  int count;

  _EbookCategory({
    required this.id,
    required this.name,
    this.coverUrl,
    required this.count,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Ebooks in a category — list layout with description preview
// ─────────────────────────────────────────────────────────────────────────────
class EbookCategoryPage extends StatelessWidget {
  final _EbookCategory category;
  final List<Ebook> ebooks;

  const EbookCategoryPage({
    super.key,
    required this.category,
    required this.ebooks,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
        backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
      ),
      body: ebooks.isEmpty
          ? Center(
              child: Text(
                'No books in this category',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: ebooks.length,
              itemBuilder: (ctx, i) => _buildEbookCard(ctx, isDark, ebooks[i]),
            ),
    );
  }

  Widget _buildEbookCard(BuildContext context, bool isDark, Ebook ebook) {
    return GestureDetector(
      onTap: () {
        if (ebook.fileUrl == null || ebook.fileUrl!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No file available for this eBook'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EbookReaderPage(ebook: ebook)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover ─────────────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14),
              ),
              child: SizedBox(
                width: 90,
                height: 130,
                child: ebook.coverImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: ebook.coverImageUrl!,
                        cacheManager: CustomImageCacheManager.instance,
                        fit: BoxFit.cover,
                        useOldImageOnUrlChange: true,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        placeholder: (_, __) => _coverPlaceholder(isDark),
                        errorWidget: (_, __, ___) => _coverPlaceholder(isDark),
                      )
                    : _coverPlaceholder(isDark),
              ),
            ),

            // ── Details ───────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      ebook.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Author
                    if (ebook.author != null && ebook.author!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        ebook.author!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryGold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Description preview
                    if (ebook.description != null &&
                        ebook.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        ebook.description!,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Bottom row — Read badge + pages + arrow
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGold.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.menu_book_rounded,
                                size: 12,
                                color: AppColors.primaryGold,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Read',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryGold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (ebook.pages != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${ebook.pages} pages',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder(bool isDark) {
    return Container(
      color: isDark ? AppColors.backgroundDark : const Color(0xFFF0EDE6),
      child: Center(
        child: Icon(
          Icons.menu_book_rounded,
          size: 36,
          color: AppColors.primaryGold.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// In-app ebook reader using WebView
// Supports PDF (via Google Docs viewer) and HTML/web ebooks
// ─────────────────────────────────────────────────────────────────────────────
class EbookReaderPage extends StatefulWidget {
  final Ebook ebook;

  const EbookReaderPage({super.key, required this.ebook});

  @override
  State<EbookReaderPage> createState() => _EbookReaderPageState();
}

class _EbookReaderPageState extends State<EbookReaderPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    final fileUrl = widget.ebook.fileUrl!;
    final viewUrl = fileUrl.toLowerCase().endsWith('.pdf')
        ? 'https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(fileUrl)}'
        : fileUrl;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() {
            _isLoading = false;
            _loadingProgress = 100;
          }),
          onProgress: (p) => setState(() => _loadingProgress = p),
          onWebResourceError: (error) =>
              debugPrint('EbookReader WebView error: ${error.description}'),
        ),
      )
      ..loadRequest(Uri.parse(viewUrl));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.ebook.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: () => _controller.reload(),
          ),
        ],
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _loadingProgress / 100,
                  backgroundColor: Colors.transparent,
                  color: AppColors.primaryGold,
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
