import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/services/data_service.dart';
import '../../../domain/entities/teens_content.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';
import 'teens_content_list_page.dart';

class TeensPage extends ConsumerStatefulWidget {
  const TeensPage({super.key});

  @override
  ConsumerState<TeensPage> createState() => _TeensPageState();
}

class _TeensPageState extends ConsumerState<TeensPage> {
  final DataService _dataService = DataService();
  
  List<TeensContent> _devotionals = [];
  List<TeensContent> _retreats = [];
  List<TeensContent> _forgeCamp = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final devotionals = await _dataService.getDevotionals();
      final retreats = await _dataService.getRetreats();
      final forgeCamp = await _dataService.getForgeCamp();
      
      if (mounted) {
        setState(() {
          _devotionals = devotionals;
          _retreats = retreats;
          _forgeCamp = forgeCamp;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading teens data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final spacing = Responsive.verticalSpacing(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: '',
        showBackButton: true,
        lightBackground: true,
        onBackPressed: () => ref.read(mainTabIndexProvider.notifier).state = 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primaryGold,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.only(bottom: 80 + bottomPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBanner(context, isDark),
                      SizedBox(height: spacing * 1.5),
                      _buildCategoryList(context, isDark),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildBanner(BuildContext context, bool isDark) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final bannerHeight = Responsive.eventCardHeight(context);
    final borderRadius = Responsive.largeBorderRadius(context);
    final titleFontSize = Responsive.subtitleFontSize(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
      height: bannerHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/images/teens_banner.png',
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFF9800),
                    Color(0xFFFFB74D),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  'YOUNG ADULTS & TEENS',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryList(BuildContext context, bool isDark) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final borderRadius = Responsive.borderRadius(context);

    final categories = [
      _CategoryItem(
        title: 'Daily Devotional',
        icon: Icons.menu_book,
        color: AppColors.orange,
        count: _devotionals.length,
        contents: _devotionals,
        contentType: TeensContentType.devotionals,
      ),
      _CategoryItem(
        title: 'Teens Retreat',
        icon: Icons.hiking,
        color: const Color(0xFF8B0000),
        count: _retreats.length,
        contents: _retreats,
        contentType: TeensContentType.retreats,
      ),
      _CategoryItem(
        title: 'The Forge Teens Camp',
        icon: Icons.local_fire_department,
        color: AppColors.teal,
        count: _forgeCamp.length,
        contents: _forgeCamp,
        contentType: TeensContentType.forgeCamp,
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: categories
              .map((category) => Column(
                    children: [
                      _buildCategoryTile(context, isDark, category),
                      if (categories.indexOf(category) < categories.length - 1)
                        Divider(
                          height: 1,
                          indent: 72,
                          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                        ),
                    ],
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryTile(BuildContext context, bool isDark, _CategoryItem category) {
    final spacing = Responsive.verticalSpacing(context);
    final iconSize = Responsive.iconSize(context);
    final iconContainerSize = Responsive.value(context, mobile: 48.0, tablet: 56.0, desktop: 64.0);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final smallFontSize = Responsive.smallFontSize(context);
    final borderRadius = Responsive.borderRadius(context);

    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: spacing, vertical: spacing * 0.5),
      leading: Container(
        width: iconContainerSize,
        height: iconContainerSize,
        decoration: BoxDecoration(
          color: category.color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Icon(
          category.icon,
          color: category.color,
          size: iconSize,
        ),
      ),
      title: Text(
        category.title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: bodyFontSize,
            ),
      ),
      subtitle: Text(
        '${category.count} ${category.count == 1 ? 'item' : 'items'}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              fontSize: smallFontSize,
            ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        size: iconSize,
      ),
      onTap: () => _navigateToContentList(context, category),
    );
  }

  void _navigateToContentList(BuildContext context, _CategoryItem category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeensContentListPage(
          title: category.title,
          contents: category.contents,
          accentColor: category.color,
          contentType: category.contentType,
        ),
      ),
    );
  }
}

class _CategoryItem {
  final String title;
  final IconData icon;
  final Color color;
  final int count;
  final List<TeensContent> contents;
  final TeensContentType contentType;

  _CategoryItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.count,
    required this.contents,
    required this.contentType,
  });
}
