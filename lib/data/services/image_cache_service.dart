import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/utils/image_cache_manager.dart';
import '../../domain/entities/sermon.dart';

class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  bool _initialized = false;

  Future<void> preCacheImages({
    required List<MessageCategory> categories,
    required List<Sermon> sermons,
  }) async {
    // Disabled to prevent ANR - images will load on demand
    debugPrint('ImageCacheService: Pre-caching disabled to prevent ANR');
    return;
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
