import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom cache manager for images with aggressive caching
/// Images are cached for 90 days and kept indefinitely if still in use
class CustomImageCacheManager {
  static const key = 'tcgcImageCache';
  static const ministerKey = 'tcgcMinisterImageCache';

  static CacheManager? _instance;
  static CacheManager? _ministersInstance;

  /// Get the singleton instance of the general image cache manager
  static CacheManager get instance {
    _instance ??= CacheManager(
      Config(
        key,
        // Cache general images for 30 days
        stalePeriod: const Duration(days: 30),
        maxNrOfCacheObjects: 400,
        repo: JsonCacheInfoRepository(databaseName: key),
        fileService: HttpFileService(),
      ),
    );
    return _instance!;
  }

  /// Dedicated persistent cache manager for minister/speaker portraits so they
  /// are never evicted by sermon thumbnails or chat media.
  static CacheManager get ministersInstance {
    _ministersInstance ??= CacheManager(
      Config(
        ministerKey,
        stalePeriod: const Duration(days: 90),
        maxNrOfCacheObjects: 300,
        repo: JsonCacheInfoRepository(databaseName: ministerKey),
        fileService: HttpFileService(),
      ),
    );
    return _ministersInstance!;
  }
}
