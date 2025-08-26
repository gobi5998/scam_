import '../services/dynamic_profile_service.dart';
import '../models/user_model.dart';

/// Examples of how to use the dynamic profile functionality
class DynamicProfileExamples {
  final DynamicProfileService _service = DynamicProfileService();

  /// Example 1: Update basic fields
  Future<void> updateBasicFields() async {
    const userId = '23d589fe-e86b-447d-bb51-6efbf255c277';
    
    // Update firstName, lastName, and imageUrl
    final response = await _service.updateUserFields(userId, {
      'firstName': 'gokuL',
      'lastName': 'krishnan',
      'imageUrl': 'https://scamdetect-dev-afsouth1.s3.af-south-1.amazonaws.com/threads-fraud/87cb9172-62a4-4b85-92cb-e1ea24b1d2c9.jpg',
    });
    
    print('✅ Basic fields updated: $response');
  }

  /// Example 2: Update single field
  Future<void> updateSingleField() async {
    const userId = '23d589fe-e86b-447d-bb51-6efbf255c277';
    
    // Update only imageUrl
    final response = await _service.updateUserField(userId, 'imageUrl', 
      'https://scamdetect-dev-afsouth1.s3.af-south-1.amazonaws.com/threads-fraud/87cb9172-62a4-4b85-92cb-e1ea24b1d2c9.jpg'
    );
    
    print('✅ Single field updated: $response');
  }

  /// Example 3: Update using JWT token format
  Future<void> updateWithJwtFormat() async {
    const userId = '23d589fe-e86b-447d-bb51-6efbf255c277';
    
    // Use JWT token format fields
    final jwtData = {
      'given_name': 'gokuL',
      'family_name': 'krishnan',
      'imageUrl': 'https://scamdetect-dev-afsouth1.s3.af-south-1.amazonaws.com/threads-fraud/87cb9172-62a4-4b85-92cb-e1ea24b1d2c9.jpg',
      'preferred_username': 'gokul@vcodewonders.com',
      'email_verified': true,
    };
    
    final response = await _service.updateUserWithJwtFields(userId, jwtData);
    print('✅ JWT fields updated: $response');
  }

  /// Example 4: Update from User model
  Future<void> updateFromUserModel() async {
    const userId = '23d589fe-e86b-447d-bb51-6efbf255c277';
    
    // Create user with dynamic data
    final user = User(
      id: userId,
      username: 'gokul@vcodewonders.com',
      email: 'gokul@vcodewonders.com',
      firstName: 'gokuL',
      lastName: 'krishnan',
      imageUrl: 'https://scamdetect-dev-afsouth1.s3.af-south-1.amazonaws.com/threads-fraud/87cb9172-62a4-4b85-92cb-e1ea24b1d2c9.jpg',
      additionalData: {
        'sub': userId,
        'email_verified': true,
        'name': 'gokuL krishnan',
        'preferred_username': 'gokul@vcodewonders.com',
        'roles': [
          {
            'id': '584d888b-c316-4b83-a7e9-8dd037aa1980',
            'name': 'user',
            'description': '',
            'composite': false,
            'clientRole': false,
            'containerId': '4b4b28ef-19da-4ef8-8968-ed720d394951'
          }
        ],
        'group': null,
      },
    );
    
    // Update all fields from user model
    final response = await _service.updateUserFromModel(userId, user);
    print('✅ User model updated: $response');
    
    // Update only specific fields
    final response2 = await _service.updateUserFromModel(
      userId, 
      user, 
      fieldsToUpdate: ['firstName', 'lastName', 'imageUrl']
    );
    print('✅ Specific fields updated: $response2');
  }

  /// Example 5: Update any dynamic field
  Future<void> updateAnyDynamicField() async {
    const userId = '23d589fe-e86b-447d-bb51-6efbf255c277';
    
    // Update any field that exists in JWT token
    final response = await _service.updateUserFields(userId, {
      'sub': userId,
      'email_verified': true,
      'name': 'gokuL krishnan',
      'preferred_username': 'gokul@vcodewonders.com',
      'given_name': 'gokuL',
      'family_name': 'krishnan',
      'email': 'gokul@vcodewonders.com',
      'imageUrl': 'https://scamdetect-dev-afsouth1.s3.af-south-1.amazonaws.com/threads-fraud/87cb9172-62a4-4b85-92cb-e1ea24b1d2c9.jpg',
      'roles': [
        {
          'id': '584d888b-c316-4b83-a7e9-8dd037aa1980',
          'name': 'user',
          'description': '',
          'composite': false,
          'clientRole': false,
          'containerId': '4b4b28ef-19da-4ef8-8968-ed720d394951'
        }
      ],
      'group': null,
    });
    
    print('✅ Any dynamic field updated: $response');
  }

  /// Example 6: Access dynamic data from User model
  Future<void> accessDynamicData() async {
    // Get fresh user data
    final user = await _service.refreshUserData();
    
    if (user != null) {
      // Access any field from JWT token
      final sub = user.getDynamicField('sub');
      final emailVerified = user.getDynamicField('email_verified');
      final roles = user.getDynamicField('roles');
      final group = user.getDynamicField('group');
      final name = user.getDynamicField('name');
      final preferredUsername = user.getDynamicField('preferred_username');
      
      print('🔍 Dynamic fields:');
      print('  sub: $sub');
      print('  email_verified: $emailVerified');
      print('  roles: $roles');
      print('  group: $group');
      print('  name: $name');
      print('  preferred_username: $preferredUsername');
      
      // Check if field exists
      if (user.hasDynamicField('sub')) {
        print('✅ Field "sub" exists');
      }
      
      // Get all dynamic data
      final allData = user.getAllDynamicData();
      print('📦 All dynamic data: $allData');
    }
  }

  /// Example 7: Your specific payload
  Future<void> yourSpecificPayload() async {
    const userId = '23d589fe-e86b-447d-bb51-6efbf255c277';
    
    // Your exact payload
    final payload = {
      'imageUrl': 'https://scamdetect-dev-afsouth1.s3.af-south-1.amazonaws.com/threads-fraud/87cb9172-62a4-4b85-92cb-e1ea24b1d2c9.jpg',
      'firstName': 'gokuL',
      'lastName': 'krishnan',
    };
    
    // This will call: https://mvp.edetectives.co.bw/auth/api/v1/user/update-user/23d589fe-e86b-447d-bb51-6efbf255c277
    final response = await _service.updateUserFields(userId, payload);
    print('✅ Your specific payload updated: $response');
  }
}
