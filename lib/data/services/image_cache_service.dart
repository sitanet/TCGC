import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/utils/image_cache_manager.dart';
import '../../domain/entities/sermon.dart';

class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  final Set<String> _warmedUrls = <String>{};

  Future<void> preCacheImages({
    required List<MessageCategory> categories,
    required List<Sermon> sermons,
  }) async {
    // Disabled bulk sermon pre-caching to prevent ANR
    return;
  }

  /// Safely pre-warms a bounded list of minister portrait URLs into the
  /// dedicated persistent minister disk cache + RAM, and silently refreshes
  /// stale portraits in the background without ever showing a loading state.
  Future<void> preCacheUrlsThrottled(
    List<String> urls, {
    int batchSize = 5,
    bool backgroundRefresh = false,
    bool useMinistersCache = true,
  }) async {
    final pending = urls
        .where((u) => u.startsWith('http') && (backgroundRefresh || !_warmedUrls.contains(u)))
        .toList();
    if (pending.isEmpty) return;

    final cache = useMinistersCache
        ? CustomImageCacheManager.ministersInstance
        : CustomImageCacheManager.instance;

    for (var i = 0; i < pending.length; i += batchSize) {
      final batch = pending.skip(i).take(batchSize).toList();
      await Future.wait(
        batch.map((url) async {
          _warmedUrls.add(url);
          try {
            final cached = await cache.getFileFromCache(url);
            if (cached == null) {
              await cache.getSingleFile(url);
            } else if (backgroundRefresh) {
              // Refresh in background if older than 12 hours
              final age = cached.validTill.difference(DateTime.now());
              // validTill is now + 90d on fresh fetch; refresh if >12h has elapsed
              if (age < const Duration(days: 89, hours: 12)) {
                await cache.downloadFile(url, force: true);
              }
            }
            // Warm RAM image cache with bounded dimensions so full-res photos don't OOM Android
            ResizeImage(
              CachedNetworkImageProvider(
                url,
                cacheManager: cache,
              ),
              width: 240,
            ).resolve(ImageConfiguration.empty);
          } catch (e) {
            _warmedUrls.remove(url);
            debugPrint('ImageCacheService: Failed to pre-warm $url: $e');
          }
        }),
      );
    }
  }

  void preCacheUrl(String url) {
    if (url.isEmpty) return;
    try {
      ResizeImage(
        CachedNetworkImageProvider(
          url,
          cacheManager: CustomImageCacheManager.instance,
        ),
        width: 240,
      ).resolve(ImageConfiguration.empty);
    } catch (e) {
      debugPrint('ImageCacheService: Failed to cache $url');
    }
  }

  void preCacheUrls(List<String> urls) {
    for (final url in urls) {
      preCacheUrl(url);
    }
  }
}
