import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
    if (_initialized) return;
    _initialized = true;

    debugPrint('ImageCacheService: Pre-caching images...');

    final urls = <String>{};

    for (final category in categories) {
      if (category.imageUrl != null && category.imageUrl!.isNotEmpty) {
        urls.add(category.imageUrl!);
      }
    }

    for (final sermon in sermons) {
      if (sermon.imageUrl != null && sermon.imageUrl!.isNotEmpty) {
        urls.add(sermon.imageUrl!);
      }
    }

    debugPrint('ImageCacheService: Caching ${urls.length} images');

    for (final url in urls) {
      try {
        CachedNetworkImageProvider(url).resolve(ImageConfiguration.empty);
      } catch (e) {
        debugPrint('ImageCacheService: Failed to cache $url');
      }
    }

    debugPrint('ImageCacheService: Pre-caching complete');
  }

  void preCacheUrl(String url) {
    if (url.isEmpty) return;
    try {
      CachedNetworkImageProvider(url).resolve(ImageConfiguration.empty);
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
