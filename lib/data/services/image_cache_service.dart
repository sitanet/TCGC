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

  /// Safely pre-warms a bounded list of image URLs (e.g. minister portraits)
  /// into disk cache in small batches so UI rendering stays smooth.
  Future<void> preCacheUrlsThrottled(
    List<String> urls, {
    int batchSize = 3,
  }) async {
    final pending = urls
        .where((u) => u.startsWith('http') && !_warmedUrls.contains(u))
        .toList();
    if (pending.isEmpty) return;

    for (var i = 0; i < pending.length; i += batchSize) {
      final batch = pending.skip(i).take(batchSize).toList();
      await Future.wait(
        batch.map((url) async {
          _warmedUrls.add(url);
          try {
            await CustomImageCacheManager.instance.getSingleFile(url);
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
      CachedNetworkImageProvider(
        url,
        cacheManager: CustomImageCacheManager.instance,
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
