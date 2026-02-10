import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/favorites_service.dart';
import '../../../domain/entities/sermon.dart';
import '../../widgets/custom_app_bar.dart';
import 'audio_player_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final FavoritesService _favoritesService = FavoritesService();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _favoritesService.initialize();
    _favoritesService.addListener(_onFavoritesChanged);
    if (mounted) setState(() {});
  }

  void _onFavoritesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _favoritesService.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final favorites = _favoritesService.favorites;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Favorites'),
      body: favorites.isEmpty
          ? _buildEmptyState(context, isDark)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final sermon = favorites[index];
                return _buildSermonTile(context, sermon, isDark);
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 64,
            color: isDark 
                ? AppColors.textSecondaryDark.withValues(alpha: 0.5)
                : AppColors.textSecondaryLight.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No favorites yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the heart icon on any message to add it here',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSermonTile(BuildContext context, Sermon sermon, bool isDark) {
    return Dismissible(
      key: Key(sermon.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        _favoritesService.removeFavorite(sermon.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed "${sermon.title}" from favorites')),
        );
      },
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 50,
            height: 50,
            color: isDark ? AppColors.cardDark : AppColors.dividerLight,
            child: sermon.imageUrl != null && sermon.imageUrl!.startsWith('http')
                ? Image.network(
                    sermon.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
                  )
                : _buildPlaceholder(isDark),
          ),
        ),
        title: Text(
          sermon.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          sermon.speaker ?? sermon.categoryName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.favorite, color: Colors.red),
          onPressed: () => _favoritesService.removeFavorite(sermon.id),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AudioPlayerPage(sermon: sermon)),
          );
        },
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Icon(
      Icons.music_note,
      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
    );
  }
}
