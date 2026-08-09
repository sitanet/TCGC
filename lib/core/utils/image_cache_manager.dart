import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom cache manager for images with aggressive caching
/// Images are cached for 90 days and kept indefinitely if still in use
class CustomImageCacheManager {
  static const key = 'tcgcImageCache';
  
  static CacheManager? _instance;
  
  /// Get the singleton instance of the cache manager
  static CacheManager get instance {
    _instance ??= CacheManager(
      Config(
        key,
        // Cache images for 90 days
        stalePeriod: const Duration(days: 90),
        // Keep cached images for up to 1 year
        maxNrOfCacheObjects: 500,
        // Repository for local database
        repo: JsonCacheInfoRepository(databaseName: key),
        fileService: HttpFileService(),
      ),
    );
    return _instance!;
  }
}
