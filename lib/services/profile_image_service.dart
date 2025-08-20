import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'jwt_service.dart';

class ProfileImageService {
  static const String _s3BaseUrl =
      'https://mvp.edetectives.co.bw'; // Your S3 bucket base URL

  /// Get the current user's ID from JWT token
  static Future<String?> getCurrentUserId() async {
    return await JwtService.getCurrentUserId();
  }

  /// Fetch profile image URL for a specific user ID
  static Future<String?> getProfileImageUrl(String userId) async {
    try {
      final apiService = ApiService();
      final response = await apiService.getProfileImageByUserId(userId);

      if (response.statusCode == 200) {
        final data = response.data;

        // Handle different response formats
        if (data is Map<String, dynamic>) {
          // If the response contains the image URL directly
          if (data.containsKey('profileImageUrl')) {
            return data['profileImageUrl'];
          }

          // If the response contains the image data
          if (data.containsKey('imageUrl')) {
            return data['imageUrl'];
          }

          // If the response contains S3 key
          if (data.containsKey('s3Key')) {
            return '$_s3BaseUrl/${data['s3Key']}';
          }
        }

        // If response is a direct URL string
        if (data is String && data.isNotEmpty) {
          return data;
        }
      }

      return null;
    } catch (e) {
      print('Error fetching profile image URL: $e');
      return null;
    }
  }

  /// Upload profile image and update user profile with the new image URL
  static Future<String?> uploadAndUpdateProfileImage(FormData formData) async {
    try {
      // First upload the image
      final apiService = ApiService();
      final uploadResponse = await apiService.uploadProfileImage(formData);

      if (uploadResponse.statusCode == 200) {
        final uploadData = uploadResponse.data;
        String? imageUrl;

        // Extract image URL from upload response
        if (uploadData is Map<String, dynamic>) {
          if (uploadData.containsKey('imageUrl')) {
            imageUrl = uploadData['imageUrl'];
          } else if (uploadData.containsKey('s3Key')) {
            imageUrl = '$_s3BaseUrl/${uploadData['s3Key']}';
          } else if (uploadData.containsKey('url')) {
            imageUrl = uploadData['url'];
          }
        }

        if (imageUrl != null) {
          // Get current user ID
          final userId = await getCurrentUserId();
          if (userId != null) {
            // Update user profile with the new image URL
            final apiService = ApiService();
            final updateResponse = await apiService.updateUserProfile({
              'profileImageUrl': imageUrl,
            });

            if (updateResponse.containsKey('message')) {
              return imageUrl;
            }
          }
        }
      }

      return null;
    } catch (e) {
      print('Error uploading and updating profile image: $e');
      return null;
    }
  }

  /// Get profile image URL for current user
  static Future<String?> getCurrentUserProfileImageUrl() async {
    final userId = await getCurrentUserId();
    if (userId != null) {
      return await getProfileImageUrl(userId);
    }
    return null;
  }

  /// Update user profile with new image URL
  static Future<bool> updateUserProfileImageUrl(String imageUrl) async {
    try {
      final userId = await getCurrentUserId();
      if (userId != null) {
        final apiService = ApiService();
        final response = await apiService.updateUserProfile({
          'profileImageUrl': imageUrl,
        });
        return response.containsKey('message');
      }
      return false;
    } catch (e) {
      print('Error updating user profile image URL: $e');
      return false;
    }
  }

  /// Generate S3 URL from S3 key
  static String generateS3Url(String s3Key) {
    return '$_s3BaseUrl/$s3Key';
  }

  /// Check if image URL is from S3 bucket
  static bool isS3Url(String? url) {
    if (url == null) return false;
    return url.startsWith(_s3BaseUrl);
  }
}
