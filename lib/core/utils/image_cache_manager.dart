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
        // Cache images for 30 days (caps disk bloat while keeping active portraits fast)
        stalePeriod: const Duration(days: 30),
        maxNrOfCacheObjects: 150,
        // Repository for local database
        repo: JsonCacheInfoRepository(databaseName: key),
        fileService: HttpFileService(),
      ),
    );
    return _instance!;
  }
}
