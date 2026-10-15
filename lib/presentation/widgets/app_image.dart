import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/image_cache_manager.dart';

class AppImage extends StatelessWidget {
  final String? imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Color? placeholderColor;
  final IconData? placeholderIcon;

  const AppImage({
    super.key,
    this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderColor,
    this.placeholderIcon,
  });

  bool get _isNetworkImage => imagePath != null && imagePath!.startsWith('http');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget placeholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: placeholderColor ?? (isDark ? AppColors.cardDark : AppColors.dividerLight),
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Icon(
          placeholderIcon ?? Icons.image_outlined,
          size: (width ?? 50) * 0.4,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
      ),
    );

    if (imagePath == null || imagePath!.isEmpty) {
      return borderRadius != null
          ? ClipRRect(borderRadius: borderRadius!, child: placeholder)
          : placeholder;
    }

    Widget image;
    if (_isNetworkImage) {
      // Calculate memory cache dimensions to prevent OOM
      final cacheWidth = width != null ? (width! * 2).toInt() : 400;
      final cacheHeight = height != null ? (height! * 2).toInt() : 400;
      
      image = CachedNetworkImage(
        imageUrl: imagePath!,
        cacheManager: CustomImageCacheManager.instance,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: cacheWidth,
        memCacheHeight: cacheHeight,
        placeholder: (context, url) => placeholder,
        errorWidget: (context, url, error) => placeholder,
        // Use 0 duration when image is in memory cache to show instantly
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        // Keep image in memory cache longer
        useOldImageOnUrlChange: true,
      );
    } else {
      image = Image.asset(
        imagePath!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }
}
