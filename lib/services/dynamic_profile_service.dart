import 'api_service.dart';
import '../models/user_model.dart';

class DynamicProfileService {
  final ApiService _apiService = ApiService();

  /// Update any user field dynamically
  Future<Map<String, dynamic>> updateUserField(
    String userId,
    String fieldName,
    dynamic fieldValue,
  ) async {
    print('🔄 Updating user field: $fieldName = $fieldValue');
    return await _apiService.updateUserField(userId, fieldName, fieldValue);
  }

  /// Update multiple user fields dynamically
  Future<Map<String, dynamic>> updateUserFields(
    String userId,
    Map<String, dynamic> fields,
  ) async {
    print('🔄 Updating multiple user fields: $fields');
    return await _apiService.updateUserFields(userId, fields);
  }

  /// Update user profile with JWT token format fields
  Future<Map<String, dynamic>> updateUserWithJwtFields(
    String userId,
    Map<String, dynamic> jwtFields,
  ) async {
    print('🔄 Updating user with JWT fields: $jwtFields');
    
    // Map JWT fields to API fields
    final Map<String, dynamic> apiFields = {};
    
    // Handle different field mappings
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
        case 'imageUrl':
          apiFields['imageUrl'] = value;
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
    return await _apiService.updateUserFields(userId, apiFields);
  }

  /// Update user profile from User object
  Future<Map<String, dynamic>> updateUserFromModel(
    String userId,
    User user,
    {List<String>? fieldsToUpdate}
  ) async {
    print('🔄 Updating user from model');
    
    final Map<String, dynamic> fields = {};
    
    // If specific fields are specified, only update those
    if (fieldsToUpdate != null) {
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
          case 'imageUrl':
            if (user.imageUrl != null && user.imageUrl!.isNotEmpty) {
              fields['imageUrl'] = user.imageUrl;
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
          case 'phone':
            if (user.phone != null && user.phone!.isNotEmpty) {
              fields['phone'] = user.phone;
            }
            break;
          case 'role':
            if (user.role != null && user.role!.isNotEmpty) {
              fields['role'] = user.role;
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
      if (user.imageUrl != null && user.imageUrl!.isNotEmpty) {
        fields['imageUrl'] = user.imageUrl;
      }
      if (user.email.isNotEmpty) {
        fields['email'] = user.email;
      }
      if (user.username.isNotEmpty) {
        fields['username'] = user.username;
      }
      if (user.phone != null && user.phone!.isNotEmpty) {
        fields['phone'] = user.phone;
      }
      if (user.role != null && user.role!.isNotEmpty) {
        fields['role'] = user.role;
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
    
    print('📦 Fields to update: $fields');
    return await _apiService.updateUserFields(userId, fields);
  }

  /// Get fresh user data after update
  Future<User?> refreshUserData() async {
    try {
      final userData = await _apiService.getUserMe();
      if (userData != null) {
        return User.fromJson(userData);
      }
      return null;
    } catch (e) {
      print('❌ Error refreshing user data: $e');
      return null;
    }
  }

  /// Example usage methods for common scenarios
  
  /// Update only name fields
  Future<Map<String, dynamic>> updateName(
    String userId,
    String firstName,
    String lastName,
  ) async {
    return await updateUserFields(userId, {
      'firstName': firstName,
      'lastName': lastName,
    });
  }

  /// Update only image
  Future<Map<String, dynamic>> updateImage(
    String userId,
    String imageUrl,
  ) async {
    return await updateUserField(userId, 'imageUrl', imageUrl);
  }

  /// Update contact information
  Future<Map<String, dynamic>> updateContact(
    String userId,
    String email,
    String? phone,
  ) async {
    final fields = {'email': email};
    if (phone != null && phone.isNotEmpty) {
      fields['phone'] = phone;
    }
    return await updateUserFields(userId, fields);
  }

  /// Update JWT token specific fields
  Future<Map<String, dynamic>> updateJwtFields(
    String userId,
    Map<String, dynamic> jwtData,
  ) async {
    return await updateUserWithJwtFields(userId, jwtData);
  }
}
