import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/services/data_service.dart';
import '../../../domain/entities/teens_category.dart';
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
  
  List<TeensCategory> _categories = [];
  String? _bannerUrl;
  bool _isLoading = true;

  // Colors for categories (cycles through)
  final List<Color> _categoryColors = [
    AppColors.orange,
    const Color(0xFF8B0000),
    AppColors.teal,
    Colors.purple,
    Colors.blue,
    Colors.green,
  ];

  // Icons for categories (cycles through)
  final List<IconData> _categoryIcons = [
    Icons.menu_book,
    Icons.hiking,
    Icons.local_fire_department,
    Icons.music_note,
    Icons.video_library,
    Icons.school,
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _dataService.getTeensCategories(forceRefresh: forceRefresh),
        _dataService.getTeensBannerUrl(),
      ]);
      
      if (mounted) {
        setState(() {
          _categories = results[0] as List<TeensCategory>;
          _bannerUrl = results[1] as String?;
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
    final appConfig = ref.watch(appConfigChangeNotifierProvider);
    
    // Check if teens page is disabled
    if (appConfig.config.teensPageDisabled) {
      return _buildDisabledPage(context, appConfig.config.teensPageDisabledMessage);
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: '',
        showBackButton: true,
        lightBackground: true,
        onBackPressed: () => ref.read(mainTabIndexProvider.notifier).state = 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadData(forceRefresh: true),
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

  Widget _buildDisabledPage(BuildContext context, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = Responsive.horizontalPadding(context);
    
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Teens',
        showBackButton: true,
        lightBackground: true,
        onBackPressed: () => ref.read(mainTabIndexProvider.notifier).state = 0,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(horizontalPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.construction_rounded,
                  size: 50,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Under Maintenance',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  height: 1.5,
                ),
              ),
            ],
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

    Widget fallbackBanner = Container(
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

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
      height: bannerHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: _bannerUrl != null && _bannerUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: _bannerUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                memCacheWidth: 600,
                memCacheHeight: 400,
                placeholder: (context, url) => Container(
                  color: isDark ? AppColors.cardDark : Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.primaryGold),
                  ),
                ),
                errorWidget: (context, url, error) => fallbackBanner,
              )
            : Image.asset(
                'assets/images/teens_banner.png',
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) => fallbackBanner,
              ),
      ),
    );
  }

  Widget _buildCategoryList(BuildContext context, bool isDark) {
    final horizontalPadding = Responsive.horizontalPadding(context);
    final borderRadius = Responsive.borderRadius(context);

    if (_categories.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Center(
          child: Text(
            'No categories available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
          ),
        ),
      );
    }

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
          children: _categories.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            final color = _categoryColors[index % _categoryColors.length];
            final icon = _categoryIcons[index % _categoryIcons.length];
            
            return Column(
              children: [
                _buildCategoryTile(context, isDark, category, color, icon),
                if (index < _categories.length - 1)
                  Divider(
                    height: 1,
                    indent: 72,
                    color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryTile(BuildContext context, bool isDark, TeensCategory category, Color color, IconData icon) {
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
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: category.imageUrl != null && category.imageUrl!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: CachedNetworkImage(
                  imageUrl: category.imageUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: 128,
                  memCacheHeight: 128,
                  placeholder: (context, url) => Icon(icon, color: color, size: iconSize),
                  errorWidget: (context, url, error) => Icon(icon, color: color, size: iconSize),
                ),
              )
            : Icon(icon, color: color, size: iconSize),
      ),
      title: Text(
        category.name,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: bodyFontSize,
            ),
      ),
      subtitle: Text(
        '${category.contentCount} ${category.contentCount == 1 ? 'item' : 'items'}',
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
      onTap: () => _navigateToContentList(context, category, color),
    );
  }

  void _navigateToContentList(BuildContext context, TeensCategory category, Color color) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeensContentListPage(
          title: category.name,
          categoryId: category.id,
          accentColor: color,
        ),
      ),
    );
  }
}
