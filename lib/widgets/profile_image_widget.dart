import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';

class ProfileImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String fallbackAssetPath;
  final BoxBorder? border;
  final Color? backgroundColor;

  const ProfileImageWidget({
    Key? key,
    this.imageUrl,
    this.radius = 50,
    this.fallbackAssetPath = '',
    this.border,
    this.backgroundColor,
  }) : super(key: key);

  /// Clear cache for a specific URL (now using Image.network, so this is for compatibility)
  static void clearCache(String? url) {
    if (url != null && url.isNotEmpty) {
      try {
        // Since we're using Image.network now, we don't need to clear CachedNetworkImage cache
        // But we keep this method for compatibility
        print('🗑️ ProfileImageWidget: Cache clearing not needed (using Image.network)');
      } catch (e) {
        print('⚠️ ProfileImageWidget: Error in clearCache: $e');
      }
    }
  }

  /// Clear all image cache (now using Image.network, so this is for compatibility)
  static void clearAllCache() {
    try {
      // Since we're using Image.network now, we don't need to clear CachedNetworkImage cache
      // But we keep this method for compatibility
      print('🗑️ ProfileImageWidget: All cache clearing not needed (using Image.network)');
    } catch (e) {
      print('⚠️ ProfileImageWidget: Error in clearAllCache: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: border,
        color: backgroundColor,
      ),
      child: ClipOval(
        child: _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    if (imageUrl == null || imageUrl!.isEmpty) {
      print('🖼️ ProfileImageWidget: No image URL provided');
      return _buildFallbackImage();
    }

    // Clean up the URL by removing any query parameters
    final cleanUrl = imageUrl!.split('?').first;
    print('🖼️ ProfileImageWidget: Loading image from URL: $cleanUrl');
    print('🖼️ ProfileImageWidget: Original URL: $imageUrl');
    
    // Validate URL format
    if (!cleanUrl.startsWith('http')) {
      print('❌ ProfileImageWidget: Invalid URL format: $cleanUrl');
      return _buildFallbackImage();
    }
    
    // Ensure the URL is properly formatted
    String finalUrl = cleanUrl;
    if (finalUrl.contains('mvp.edetectives.co.bw') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
      print('🔄 ProfileImageWidget: Fixed URL format: $finalUrl');
    }
    
    // Add aggressive cache busting parameter to force reload
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomId = (timestamp % 1000000).toString();
    final cacheBustedUrl = '$finalUrl?t=$timestamp&r=$randomId';
    print('🔄 ProfileImageWidget: Using aggressive cache-busted URL: $cacheBustedUrl');
    
    // Use NetworkImage instead of CachedNetworkImage for profile images to avoid caching issues
    return Image.network(
      cacheBustedUrl,
      width: radius * 2,
      height: radius * 2,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        print('🔄 ProfileImageWidget: Loading progress: ${loadingProgress.cumulativeBytesLoaded}/${loadingProgress.expectedTotalBytes}');
        return _buildLoadingPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) {
        print('❌ ProfileImageWidget: Error loading image: $error');
        print('❌ Error details - URL: $cacheBustedUrl');
        print('❌ Stack trace: $stackTrace');
        return _buildFallbackImage();
      },
      headers: const {
        'Accept': 'image/*',
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      },
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: radius * 2,
      height: radius * 2,
      color: Colors.grey[300],
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    print('🖼️ ProfileImageWidget: Using fallback image');
    return Image.asset(
      fallbackAssetPath,
      width: radius * 2,
      height: radius * 2,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        print('❌ ProfileImageWidget: Error loading fallback image: $error');
        return Container(
          width: radius * 2,
          height: radius * 2,
          color: Colors.grey[300],
          child: Icon(
            Icons.error_outline,
            size: radius,
            color: Colors.red,
          ),
        );
      },
    );
  }
}
