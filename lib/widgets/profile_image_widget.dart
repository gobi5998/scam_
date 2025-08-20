import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
    this.fallbackAssetPath = 'assets/image/security1.jpg',
    this.border,
    this.backgroundColor,
  }) : super(key: key);

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
      return _buildFallbackImage();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: radius * 2,
      height: radius * 2,
      fit: BoxFit.cover,
      placeholder: (context, url) => _buildLoadingPlaceholder(),
      errorWidget: (context, url, error) => _buildFallbackImage(),
      httpHeaders: const {
        'Accept': 'image/*',
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
    return Image.asset(
      fallbackAssetPath,
      width: radius * 2,
      height: radius * 2,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: radius * 2,
          height: radius * 2,
          color: Colors.grey[300],
          child: Icon(
            Icons.person,
            size: radius,
            color: Colors.grey[600],
          ),
        );
      },
    );
  }
}
