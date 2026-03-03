import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/services/data_service.dart';
import '../../../data/services/interests_service.dart';
import '../../../domain/entities/sermon.dart';
import '../../widgets/custom_app_bar.dart';

class EditInterestsPage extends StatefulWidget {
  const EditInterestsPage({super.key});

  @override
  State<EditInterestsPage> createState() => _EditInterestsPageState();
}

class _EditInterestsPageState extends State<EditInterestsPage> {
  final DataService _dataService = DataService();
  final InterestsService _interestsService = InterestsService();
  
  List<MessageCategory> _categories = [];
  Set<String> _selectedIds = {};
  bool _isLoading = true;
  bool _isSaving = false;

  static const int minSelection = 3;
  static const int maxSelection = 5;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _interestsService.initialize();
    
    try {
      final categories = await _dataService.getMessageCategories();
      
      if (mounted) {
        setState(() {
          _categories = categories.where((c) => c.isActive).toList();
          _selectedIds = _interestsService.selectedCategoryIds.toSet();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleCategory(String categoryId) {
    setState(() {
      if (_selectedIds.contains(categoryId)) {
        _selectedIds.remove(categoryId);
      } else if (_selectedIds.length < maxSelection) {
        _selectedIds.add(categoryId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You can only select up to $maxSelection categories'),
            backgroundColor: AppColors.primaryGold,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  Future<void> _saveInterests() async {
    if (_selectedIds.length < minSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least $minSelection categories'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    
    await _interestsService.saveInterests(_selectedIds.toList());
    
    setState(() => _isSaving = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Interests updated successfully'),
          backgroundColor: AppColors.primaryGold,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spacing = Responsive.verticalSpacing(context);
    final horizontalPadding = Responsive.horizontalPadding(context);
    final maxWidth = Responsive.maxContentWidth(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final buttonHeight = Responsive.buttonHeight(context);
    final borderRadius = Responsive.borderRadius(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
      appBar: const CustomAppBar(title: 'Edit Interests', showBackButton: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(horizontalPadding),
                  child: Column(
                    children: [
                      Text(
                        'Select $minSelection to $maxSelection categories to personalize your experience',
                        style: TextStyle(
                          fontSize: bodyFontSize,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: spacing * 0.75),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: spacing * 1.2, vertical: spacing * 0.6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryGold.withValues(alpha: 0.15),
                              AppColors.primaryGold.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: AppColors.primaryGold.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: AppColors.primaryGold,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedIds.length} of $maxSelection selected',
                              style: TextStyle(
                                fontSize: bodyFontSize * 0.9,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryGold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
                      : _categories.isEmpty
                          ? Center(
                              child: Text(
                                'No categories available',
                                style: TextStyle(
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            )
                          : GridView.builder(
                              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: Responsive.gridCrossAxisCount(context, mobile: 2, tablet: 3, desktop: 4),
                                crossAxisSpacing: spacing,
                                mainAxisSpacing: spacing,
                                childAspectRatio: 1.1,
                              ),
                              itemCount: _categories.length,
                              itemBuilder: (context, index) {
                                final category = _categories[index];
                                final isSelected = _selectedIds.contains(category.id);
                                return _buildCategoryCard(context, category, isSelected, isDark, borderRadius);
                              },
                            ),
                ),
                
                Container(
                  padding: EdgeInsets.all(horizontalPadding),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.backgroundDark : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: buttonHeight,
                    child: ElevatedButton(
                      onPressed: _selectedIds.length >= minSelection && !_isSaving
                          ? _saveInterests
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGold,
                        disabledBackgroundColor: isDark 
                            ? AppColors.cardDark 
                            : AppColors.dividerLight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                      ),
                      child: _isSaving
                          ? SizedBox(
                              width: Responsive.iconSize(context),
                              height: Responsive.iconSize(context),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _selectedIds.length < minSelection
                                  ? 'Select ${minSelection - _selectedIds.length} more'
                                  : 'Save',
                              style: TextStyle(
                                fontSize: bodyFontSize,
                                fontWeight: FontWeight.w600,
                                color: _selectedIds.length >= minSelection
                                    ? Colors.white
                                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    MessageCategory category,
    bool isSelected,
    bool isDark,
    double borderRadius,
  ) {
    final smallFontSize = Responsive.smallFontSize(context);
    
    return GestureDetector(
      onTap: () => _toggleCategory(category.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isSelected ? AppColors.primaryGold : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? AppColors.primaryGold.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.1),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius - 2),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildCategoryImage(category, isDark),
              
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),
              
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGold,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Text(
                  category.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: smallFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryImage(MessageCategory category, bool isDark) {
    Widget placeholder = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGold.withValues(alpha: 0.3),
            isDark ? AppColors.cardDark : AppColors.surfaceLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note,
          size: 40,
          color: AppColors.primaryGold.withValues(alpha: 0.5),
        ),
      ),
    );

    if (category.imageUrl == null || category.imageUrl!.isEmpty) {
      return placeholder;
    }

    if (category.imageUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: category.imageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => placeholder,
        errorWidget: (context, url, error) => placeholder,
      );
    }

    return Image.asset(
      category.imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}
