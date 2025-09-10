import 'package:dio/dio.dart';
import 'dart:io';
import 'api_service.dart';
import 'jwt_service.dart';
import '../models/user_model.dart';
import '../provider/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

/// Dynamic Profile Flow Service
/// Handles the complete flow: Image Upload → Profile Update → Data Refresh → UI Update
class DynamicProfileFlowService {
  final ApiService _apiService = ApiService();

  /// Step 1: Image Upload - User selects image → Uploads to S3 → Gets image URL
  Future<String?> uploadImageToS3({
    required File imageFile,
    required BuildContext context,
  }) async {
    try {
      print('🔄 Step 1: Image Upload - Starting S3 upload...');
      print('🌐 Upload endpoint: https://mvp.edetectives.co.bw/external/api/v1/file-upload/threads-fraud');
      
      // Get current user ID
      final userId = await JwtService.getCurrentUserId();
      if (userId == null) {
        print('❌ Step 1: Image Upload - No user ID found');
        return null;
      }
      print('👤 User ID for upload: $userId');
      
      // Create form data for image upload
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });
      
      print('📤 Uploading image: $fileName');
      
      // Use ApiService directly for upload with proper user ID
      final response = await _apiService.uploadProfileImage(formData, userId);
      
      print('📥 Upload response status: ${response.statusCode}');
      print('📥 Upload response data: ${response.data}');
      
      // Extract image URL from response
      String? imageUrl;
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        print('📦 Response data structure: $data');
        print('📦 Response data keys: ${data.keys.toList()}');
        
        // Check if response has nested data structure
        if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
          final nestedData = data['data'] as Map<String, dynamic>;
          print('📦 Nested data structure: $nestedData');
          print('📦 Nested data keys: ${nestedData.keys.toList()}');
          
          // Try different possible field names for the image URL in nested data
          imageUrl = nestedData['url'] ?? 
                     nestedData['imageUrl'] ?? 
                     nestedData['s3Url'] ?? 
                     nestedData['fileUrl'] ?? 
                     nestedData['downloadUrl'];
          
          // If we have a key but no URL, construct the S3 URL
          if (imageUrl == null && nestedData['key'] != null) {
            imageUrl = 'https://scamdetect-dev-afsouth1.s3.af-south-1.amazonaws.com/threads-fraud/${nestedData['key']}';
          }
        } else {
          // Try different possible field names for the image URL in flat data
          imageUrl = data['url'] ?? 
                     data['imageUrl'] ?? 
                     data['s3Url'] ?? 
                     data['key'] ?? 
                     data['fileUrl'] ?? 
                     data['downloadUrl'];
          
          // If we have a key but no URL, construct the S3 URL
          if (imageUrl == null && data['key'] != null) {
            imageUrl = 'https://scamdetect-dev-afsouth1.s3.af-south-1.amazonaws.com/threads-fraud/${data['key']}';
          }
        }
      }
      
      if (imageUrl != null) {
        print('✅ Step 1: Image Upload - Success! Image URL: $imageUrl');
        return imageUrl;
      } else {
        print('❌ Step 1: Image Upload - Failed: No image URL in response');
        print('📦 Response data structure: ${response.data}');
        return null;
      }
    } catch (e) {
      print('❌ Step 1: Image Upload - Error: $e');
      return null;
    }
  }

  /// Step 2: Profile Update - PUT request with any dynamic fields
  Future<Map<String, dynamic>?> updateProfile({
    required String userId,
    required Map<String, dynamic> profileData,
  }) async {
    try {
      print('🔄 Step 2: Profile Update - Making PUT request...');
      print('👤 User ID: $userId');
      print('📦 Profile data: $profileData');
      print('📦 Profile data type: ${profileData.runtimeType}');
      print('📦 Profile data keys: ${profileData.keys.toList()}');
      print('📦 imageUrl in profileData: ${profileData['imageUrl']}');
      print('🌐 Endpoint: auth/api/v1/user/update-user/$userId');
      print('🔗 Full URL: https://mvp.edetectives.co.bw/auth/api/v1/user/update-user/$userId');
      
      // Make PUT request to update profile
      final response = await _apiService.updateUserProfileById(userId, profileData);
      
      print('✅ Step 2: Profile Update - Success!');
      print('📦 Response: $response');
      print('📦 Response type: ${response.runtimeType}');
      
      return response;
    } catch (e) {
      print('❌ Step 2: Profile Update - Error: $e');
      print('❌ Error type: ${e.runtimeType}');
      return null;
    }
  }

  /// Step 3: Data Refresh - Call user/me endpoint to get updated user data
  Future<User?> refreshUserData() async {
    try {
      print('🔄 Step 3: Data Refresh - Calling user/me endpoint...');
      
      final userData = await _apiService.getUserMe();
      
      if (userData != null) {
        print('✅ Step 3: Data Refresh - Success!');
        print('📦 Updated user data: $userData');
        print('📦 User data keys: ${userData.keys.toList()}');
        print('📦 imageUrl in userData: ${userData['imageUrl']}');
        
        // Create user object from the response
        final user = User.fromJson(userData);
        print('👤 Created user object: ${user.toJson()}');
        print('🖼️ User imageUrl: ${user.imageUrl}');
        
        return user;
      } else {
        print('❌ Step 3: Data Refresh - Failed to get user data');
        return null;
      }
    } catch (e) {
      print('❌ Step 3: Data Refresh - Error: $e');
      print('❌ Error type: ${e.runtimeType}');
      return null;
    }
  }

  /// Step 4: UI Update - Update AuthProvider and return updated user
  Future<User?> updateUI({
    required User updatedUser,
    required BuildContext context,
  }) async {
    try {
      print('🔄 Step 4: UI Update - Updating AuthProvider...');
      
      // Update AuthProvider with fresh data
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.setUserData(updatedUser.toJson());
      
      print('✅ Step 4: UI Update - AuthProvider updated');
      print('👤 Updated user: ${updatedUser.toJson()}');
      print('🖼️ New image URL: ${updatedUser.imageUrl}');
      
      return updatedUser;
    } catch (e) {
      print('❌ Step 4: UI Update - Error: $e');
      return null;
    }
  }

  /// Complete Dynamic Flow - All steps together
  Future<User?> completeDynamicFlow({
    required File imageFile,
    required String userId,
    required Map<String, dynamic> profileFields,
    required BuildContext context,
  }) async {
    try {
      print('🚀 Starting Complete Dynamic Profile Flow...');
      print('📋 Profile fields to update: $profileFields');
      
      // Step 1: Image Upload
      String? imageUrl;
      try {
        imageUrl = await uploadImageToS3(
          imageFile: imageFile,
          context: context,
        );
      } catch (e) {
        print('⚠️ Image upload failed, continuing without image: $e');
        imageUrl = null;
      }
      
      // Step 2: Prepare dynamic payload with image URL
      final dynamicPayload = Map<String, dynamic>.from(profileFields);
      if (imageUrl != null && imageUrl.isNotEmpty) {
        dynamicPayload['imageUrl'] = imageUrl;
        print('🖼️ Adding imageUrl to payload: $imageUrl');
        print('✅ imageUrl field added successfully');
      } else {
        print('⚠️ No imageUrl to add to payload');
        print('❌ imageUrl is null or empty: "$imageUrl"');
      }
      
      print('📦 Dynamic payload with image URL: $dynamicPayload');
      print('📦 Payload keys: ${dynamicPayload.keys.toList()}');
      print('📦 Payload contains imageUrl: ${dynamicPayload.containsKey('imageUrl')}');
      print('📦 imageUrl value in payload: ${dynamicPayload['imageUrl']}');
      
      // Step 3: Profile Update
      print('🔄 Step 3: Profile Update - About to call updateProfile...');
      print('📦 Final payload being sent: $dynamicPayload');
      print('📦 Payload type: ${dynamicPayload.runtimeType}');
      print('📦 Payload JSON: ${dynamicPayload.toString()}');
      
      final updateResponse = await updateProfile(
        userId: userId,
        profileData: dynamicPayload,
      );
      
      print('📥 Profile update response: $updateResponse');
      
      if (updateResponse == null) {
        throw Exception('Profile update failed');
      }
      
      // Step 4: Data Refresh
      print('🔄 Step 4: Refreshing user data from user/me endpoint...');
      final updatedUser = await refreshUserData();
      
      if (updatedUser == null) {
        throw Exception('Data refresh failed');
      }
      
      print('📦 Updated user data: ${updatedUser.toJson()}');
      print('🖼️ Updated user imageUrl: ${updatedUser.imageUrl}');
      print('📦 Updated user additionalData: ${updatedUser.additionalData}');
      
      // Step 5: UI Update
      final finalUser = await updateUI(
        updatedUser: updatedUser,
        context: context,
      );
      
      if (finalUser != null) {
        print('🎉 Complete Dynamic Flow - SUCCESS!');
        print('✅ Image uploaded to S3');
        print('✅ Profile updated with dynamic fields');
        print('✅ User data refreshed from user/me');
        print('✅ UI updated with new data');
        return finalUser;
      } else {
        throw Exception('UI update failed');
      }
      
    } catch (e) {
      print('❌ Complete Dynamic Flow - Error: $e');
      return null;
    }
  }

  /// Dynamic method to update any fields from JWT token
  Future<User?> updateWithJwtFields({
    required File imageFile,
    required String userId,
    required Map<String, dynamic> jwtFields,
    required BuildContext context,
  }) async {
    try {
      print('🔄 Dynamic JWT Update - Starting...');
      print('📦 JWT fields: $jwtFields');
      
      // Map JWT fields to API fields
      final Map<String, dynamic> apiFields = {};
      
      jwtFields.forEach((key, value) {
        switch (key) {
          case 'given_name':
            apiFields['firstName'] = value;
            break;
          case 'family_name':
            apiFields['lastName'] = value;
            break;
          case 'preferred_username':
            apiFields['username'] = value;
            break;
          case 'name':
            apiFields['fullName'] = value;
            break;
          case 'email_verified':
            apiFields['emailVerified'] = value;
            break;
          case 'email':
            apiFields['email'] = value;
            break;
          case 'phone':
            apiFields['phone'] = value;
            break;
          case 'role':
            apiFields['role'] = value;
            break;
          case 'roles':
            apiFields['roles'] = value;
            break;
          case 'group':
            apiFields['group'] = value;
            break;
          default:
            // Pass through any other fields as-is
            apiFields[key] = value;
            break;
        }
      });
      
      print('📦 Mapped API fields: $apiFields');
      
      return await completeDynamicFlow(
        imageFile: imageFile,
        userId: userId,
        profileFields: apiFields,
        context: context,
      );
      
    } catch (e) {
      print('❌ Dynamic JWT Update - Error: $e');
      return null;
    }
  }

  /// Example usage methods for common scenarios
  
  /// Update only name and image
  Future<User?> updateNameAndImage({
    required File imageFile,
    required String userId,
    required String firstName,
    required String lastName,
    required BuildContext context,
  }) async {
    return await completeDynamicFlow(
      imageFile: imageFile,
      userId: userId,
      profileFields: {
        'firstName': firstName,
        'lastName': lastName,
      },
      context: context,
    );
  }

  /// Update any dynamic fields
  Future<User?> updateAnyFields({
    required File imageFile,
    required String userId,
    required Map<String, dynamic> fields,
    required BuildContext context,
  }) async {
    return await completeDynamicFlow(
      imageFile: imageFile,
      userId: userId,
      profileFields: fields,
      context: context,
    );
  }

  /// Update from User model
  Future<User?> updateFromUserModel({
    required File imageFile,
    required String userId,
    required User user,
    required BuildContext context,
    List<String>? fieldsToUpdate,
  }) async {
    final Map<String, dynamic> fields = {};
    
    if (fieldsToUpdate != null) {
      // Update only specific fields
      for (final field in fieldsToUpdate) {
        switch (field) {
          case 'firstName':
            if (user.firstName != null && user.firstName!.isNotEmpty) {
              fields['firstName'] = user.firstName;
            }
            break;
          case 'lastName':
            if (user.lastName != null && user.lastName!.isNotEmpty) {
              fields['lastName'] = user.lastName;
            }
            break;
          case 'email':
            if (user.email.isNotEmpty) {
              fields['email'] = user.email;
            }
            break;
          case 'username':
            if (user.username.isNotEmpty) {
              fields['username'] = user.username;
            }
            break;
          default:
            // Try to get from additional data
            if (user.hasDynamicField(field)) {
              fields[field] = user.getDynamicField(field);
            }
            break;
        }
      }
    } else {
      // Update all available fields
      if (user.firstName != null && user.firstName!.isNotEmpty) {
        fields['firstName'] = user.firstName;
      }
      if (user.lastName != null && user.lastName!.isNotEmpty) {
        fields['lastName'] = user.lastName;
      }
      if (user.email.isNotEmpty) {
        fields['email'] = user.email;
      }
      if (user.username.isNotEmpty) {
        fields['username'] = user.username;
      }
      
      // Add any additional dynamic fields
      final additionalData = user.getAllDynamicData();
      if (additionalData != null) {
        additionalData.forEach((key, value) {
          if (!fields.containsKey(key) && value != null) {
            fields[key] = value;
          }
        });
      }
    }
    
    return await completeDynamicFlow(
      imageFile: imageFile,
      userId: userId,
      profileFields: fields,
      context: context,
    );
  }

  /// Test method to verify the complete flow
  Future<bool> testCompleteFlow({
    required File imageFile,
    required String userId,
    required BuildContext context,
  }) async {
    try {
      print('🧪 Testing Complete Dynamic Flow...');
      
      // Test Step 1: Image Upload
      print('🧪 Testing Step 1: Image Upload...');
      final imageUrl = await uploadImageToS3(
        imageFile: imageFile,
        context: context,
      );
      
      if (imageUrl == null) {
        print('❌ Test failed: Image upload returned null');
        return false;
      }
      
      print('✅ Test Step 1: Image upload successful - URL: $imageUrl');
      
      // Test Step 2: Profile Update
      print('🧪 Testing Step 2: Profile Update...');
      final updateResponse = await updateProfile(
        userId: userId,
        profileData: {'imageUrl': imageUrl},
      );
      
      if (updateResponse == null) {
        print('❌ Test failed: Profile update returned null');
        return false;
      }
      
      print('✅ Test Step 2: Profile update successful');
      
      // Test Step 3: Data Refresh
      print('🧪 Testing Step 3: Data Refresh...');
      final updatedUser = await refreshUserData();
      
      if (updatedUser == null) {
        print('❌ Test failed: Data refresh returned null');
        return false;
      }
      
      print('✅ Test Step 3: Data refresh successful');
      print('🖼️ Final user imageUrl: ${updatedUser.imageUrl}');
      
      return true;
    } catch (e) {
      print('❌ Test failed with error: $e');
      return false;
    }
  }

  /// Debug method to check current user data
  Future<void> debugCurrentUserData() async {
    try {
      print('🔍 Debugging current user data...');
      
      final userData = await _apiService.getUserMe();
      if (userData != null) {
        print('📦 Current user data: $userData');
        print('📦 User data keys: ${userData.keys.toList()}');
        print('📦 imageUrl field: ${userData['imageUrl']}');
        
        final user = User.fromJson(userData);
        print('👤 User object: ${user.toJson()}');
        print('🖼️ User imageUrl: ${user.imageUrl}');
      } else {
        print('❌ No user data found');
      }
    } catch (e) {
      print('❌ Error debugging user data: $e');
    }
  }
}
