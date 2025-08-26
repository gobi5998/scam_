import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'api_service.dart';
import 'jwt_service.dart';
import '../provider/auth_provider.dart';
import '../models/user_model.dart';

class ProfileImageService {
  static const String _s3BaseUrl = 'https://mvp.edetectives.co.bw';

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
  static Future<String?> uploadAndUpdateProfileImage(FormData formData, {required BuildContext context}) async {
    try {
      print('📤 Starting profile image upload...');
      print('🔍 Form data fields:');
      for (var field in formData.fields) {
        print('  ${field.key}: ${field.value}');
      }
      if (formData.files.isNotEmpty) {
        print('📎 File to upload:');
        print('  - Filename: ${formData.files.first.value.filename}');
        print('  - Content type: ${formData.files.first.value.contentType}');
      }
      
      // First upload the image
      final apiService = ApiService();
      print('🔍 Getting current user ID...');
      final userId = await getCurrentUserId();
      
      if (userId == null) {
        print('❌ User ID not found');
        return null;
      }
      print('✅ User ID: $userId');

      print('⬆️ Uploading image...');
      final uploadResponse = await apiService.uploadProfileImage(formData, userId);
      
      print('✅ Upload response status: ${uploadResponse.statusCode}');
      print('📦 Response headers: ${uploadResponse.headers}');
      print('📦 Response data type: ${uploadResponse.data.runtimeType}');
      print('📦 Response data: ${uploadResponse.data}');
      
              if (uploadResponse.statusCode == 200) {
          final uploadData = uploadResponse.data;
          print('📥 Upload data: $uploadData');
          
          String? imageUrl;
          
          // Handle different response formats
          if (uploadData is Map && uploadData.containsKey('data')) {
            // Handle nested data object
            final data = uploadData['data'];
            if (data is Map && (data['url'] != null || data['key'] != null)) {
              imageUrl = data['url'] ?? '$_s3BaseUrl/${data['key']}';
            } else if (data is String) {
              // If data is a direct URL string
              imageUrl = data;
            }
          } else if (uploadData is Map && (uploadData['url'] != null || uploadData['key'] != null)) {
            // Handle flat response
            imageUrl = uploadData['url'] ?? '$_s3BaseUrl/${uploadData['key']}';
          } else if (uploadData is String) {
            // If the response is a direct URL
            imageUrl = uploadData;
          } else if (uploadData is Map && uploadData.containsKey('imageUrl')) {
            // Handle response with imageUrl field
            imageUrl = uploadData['imageUrl'];
          } else if (uploadData is Map && uploadData.containsKey('s3Url')) {
            // Handle response with s3Url field
            imageUrl = uploadData['s3Url'];
          }
        
        if (imageUrl != null) {
          print('🖼️ Extracted image URL: $imageUrl');
          
          // Ensure the URL is absolute
          String finalImageUrl = imageUrl;
          if (!imageUrl.startsWith('http')) {
            // If it's a relative URL, prepend the base URL
            if (imageUrl.startsWith('/')) {
              finalImageUrl = '${Uri.parse(_s3BaseUrl).origin}$imageUrl';
            } else {
              finalImageUrl = '$_s3BaseUrl/$imageUrl';
            }
            print('🔄 Converted to absolute URL: $finalImageUrl');
          }
          
          // First get the current user data
          print('🔍 Fetching current user data...');
          final currentUser = await apiService.getUserMe();
          
          if (currentUser != null) {
            print('🔄 Updating user profile with new image URL...');
            
            // For user/me endpoint, we just need to update the imageUrl field
            final updatedUserData = {
              ...currentUser, // Include existing user data
              'imageUrl': finalImageUrl, // This is the field expected by the API
            };
            
            print('📝 Updated user data with new image URL:');
            print(updatedUserData);
            
            print('📝 Updated user data with profile image:',);
            print(updatedUserData);
            
            // Update the profile with the new image URL
            print('🔄 Updating user profile with new image URL...');
            final updateResponse = await apiService.updateUserProfile(updatedUserData);
            print('✅ Profile update response: $updateResponse');
            
            if (updateResponse.containsKey('message') || updateResponse['success'] == true) {
                        // Update the local state
          try {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            
            // Update local user data with the new image URL
            final userData = {
              ...currentUser, // Include all existing user data
              'imageUrl': finalImageUrl, // This matches the API response format
            };
            
            print('📝 Updated user data with imageUrl: $finalImageUrl');
            
            // Update the auth provider with the complete user data - single update
            await authProvider.setUserData(userData);
            print('✅ Updated local user state with new profile image URL');
            
            // Return just the image URL
            return finalImageUrl;
          } catch (e) {
            print('⚠️ Warning: Could not update AuthProvider: $e');
            // Return the URL even if local state update fails
            return finalImageUrl;
          }
            } else {
              print('❌ Failed to update profile: $updateResponse');
              return null;
            }
          } else {
            print('❌ Failed to fetch current user data');
            return null;
          }
        } else {
          print('❌ Could not extract image URL from response');
          print('Response data: $uploadData');
        }
      } else {
        print('❌ Upload failed with status: ${uploadResponse.statusCode}');
        print('Response: ${uploadResponse.data}');
      }

      return null;
    } catch (e) {
      print('❌ Error in uploadAndUpdateProfileImage: $e');
      rethrow;
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
