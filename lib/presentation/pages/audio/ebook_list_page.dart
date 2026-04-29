import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/services/api_service.dart';
import '../../../domain/entities/ebook.dart';

class EbookListPage extends StatefulWidget {
  const EbookListPage({super.key});

  @override
  State<EbookListPage> createState() => _EbookListPageState();
}

class _EbookListPageState extends State<EbookListPage> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<Ebook> _allEbooks = [];
  List<Ebook> _filtered = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEbooks();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEbooks() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await _api.get(ApiConstants.ebooks);
      if (res.isSuccess) {
        final list = res.data is List
            ? res.data as List
            : (res.data['results'] ?? res.data['data'] ?? []) as List;
        final ebooks = list.map((e) => Ebook.fromJson(e)).toList();
        if (mounted) {
          setState(() {
            _allEbooks = ebooks;
            _filtered = ebooks;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() { _error = 'Failed to load library'; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Error: $e'; _isLoading = false; });
    }
  }

  void _filter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _allEbooks
          : _allEbooks.where((b) =>
              b.title.toLowerCase().contains(q) ||
              (b.author?.toLowerCase().contains(q) ?? false) ||
              (b.description?.toLowerCase().contains(q) ?? false)).toList();
    });
  }

  Future<void> _openEbook(Ebook ebook) async {
    if (ebook.fileUrl == null || ebook.fileUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file available for this eBook'), backgroundColor: Colors.orange),
      );
      return;
    }
    try {
      final uri = Uri.parse(ebook.fileUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot open this file'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search books...',
              prefixIcon: const Icon(Icons.search, color: AppColors.primaryGold),
              filled: true,
              fillColor: isDark ? AppColors.cardDark : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadEbooks,
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold),
                            child: const Text('Retry', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    )
                  : _filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.menu_book_outlined,
                                  size: 64, color: AppColors.primaryGold.withValues(alpha: 0.4)),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isEmpty
                                    ? 'No eBooks available yet'
                                    : 'No results for "${_searchController.text}"',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.primaryGold,
                          onRefresh: _loadEbooks,
                          child: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.62,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                            itemCount: _filtered.length,
                            itemBuilder: (ctx, i) => _buildEbookCard(_filtered[i], isDark),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildEbookCard(Ebook ebook, bool isDark) {
    return GestureDetector(
      onTap: () => _openEbook(ebook),
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: AspectRatio(
                aspectRatio: 0.75,
                child: ebook.coverImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: ebook.coverImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _coverPlaceholder(isDark),
                        errorWidget: (_, __, ___) => _coverPlaceholder(isDark),
                      )
                    : _coverPlaceholder(isDark),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ebook.title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (ebook.author != null && ebook.author!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      ebook.author!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.menu_book_rounded,
                                size: 11, color: AppColors.primaryGold),
                            const SizedBox(width: 4),
                            Text(
                              'Read',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryGold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (ebook.pages != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${ebook.pages}p',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
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
          size: 48,
          color: AppColors.primaryGold.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
