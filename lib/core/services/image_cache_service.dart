import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ImageCacheService {
  static bool _initialized = false;
  
  static void initialize() {
    if (_initialized) return;
    _initialized = true;
    
    // Adaptive cache size based on platform
    // Very conservative for mobile to prevent OOM on low-end devices
    int maxImages;
    int maxBytes;
    
    if (kIsWeb) {
      maxImages = 100;
      maxBytes = 50 * 1024 * 1024; // 50MB for web
    } else if (Platform.isAndroid) {
      // Very conservative for Android - many low-end devices have 1-2GB RAM
      maxImages = 50;
      maxBytes = 15 * 1024 * 1024; // 15MB for Android (reduced from 30MB)
    } else if (Platform.isIOS) {
      // iOS devices generally have better memory management
      maxImages = 70;
      maxBytes = 30 * 1024 * 1024; // 30MB for iOS
    } else {
      // Desktop platforms
      maxImages = 100;
      maxBytes = 50 * 1024 * 1024; // 50MB for desktop
    }
    
    try {
      PaintingBinding.instance.imageCache.maximumSize = maxImages;
      PaintingBinding.instance.imageCache.maximumSizeBytes = maxBytes;
      debugPrint('ImageCache initialized: $maxImages images, ${maxBytes ~/ (1024 * 1024)}MB');
    } catch (e) {
      debugPrint('ImageCache initialization error: $e');
    }
  }

  static void clearMemoryCache() {
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      debugPrint('Image memory cache cleared');
    } catch (e) {
      debugPrint('Error clearing image cache: $e');
    }
  }
  
  static void evictImage(String url) {
    try {
      final provider = NetworkImage(url);
      PaintingBinding.instance.imageCache.evict(provider);
    } catch (e) {
      debugPrint('Error evicting image: $e');
    }
  }
}
