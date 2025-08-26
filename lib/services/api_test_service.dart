import 'package:dio/dio.dart';
import 'api_service.dart';
import 'dio_service.dart';

class ApiTestService {
  final ApiService _apiService = ApiService();
  final DioService _dioService = DioService();

  /// Debug the 405 error by checking endpoint existence
  Future<void> debug405Error() async {
    try {
      print('🔍 Debugging 405 Error...');
      
      final userId = '23d589fe-e86b-447d-bb51-6efbf255c277';
      final endpoint = 'auth/api/v1/user/update-user/$userId';
      
      print('🌐 Testing endpoint: $endpoint');
      print('🔗 Full URL: https://mvp.edetectives.co.bw/$endpoint');

      // Test 1: Check if endpoint exists with GET
      try {
        print('🔄 Test 1: Checking if endpoint exists with GET...');
        final getResponse = await _dioService.mainApi.get(endpoint);
        print('✅ GET successful - Status: ${getResponse.statusCode}');
        print('✅ GET response: ${getResponse.data}');
      } catch (e) {
        print('❌ GET failed: $e');
        if (e.toString().contains('404')) {
          print('🔍 Endpoint does not exist (404)');
        } else if (e.toString().contains('405')) {
          print('🔍 Endpoint exists but GET not allowed (405)');
        }
      }

      // Test 2: Check OPTIONS to see allowed methods
      try {
        print('🔄 Test 2: Checking allowed methods with OPTIONS...');
        final optionsResponse = await _dioService.mainApi.request(
          endpoint,
          options: Options(method: 'OPTIONS'),
        );
        print('✅ OPTIONS successful - Status: ${optionsResponse.statusCode}');
        print('✅ Allowed methods: ${optionsResponse.headers['allow']}');
        print('✅ Response: ${optionsResponse.data}');
      } catch (e) {
        print('❌ OPTIONS failed: $e');
      }

      // Test 3: Try different endpoint variations
      final variations = [
        'auth/api/v1/user/me',  // Known working endpoint
        'auth/api/v1/user/profile',
        'auth/api/v1/user/$userId',
        'auth/api/v1/users/$userId',
        'api/v1/user/me',
        'api/v1/user/profile',
      ];

      print('🔄 Test 3: Testing different endpoint variations...');
      for (final variation in variations) {
        try {
          print('🔄 Testing: $variation');
          final response = await _dioService.mainApi.get(variation);
          print('✅ $variation - Status: ${response.statusCode}');
          print('✅ $variation - Response: ${response.data}');
        } catch (e) {
          print('❌ $variation - Failed: ${e.toString().split('Exception: ').last}');
        }
      }

      // Test 4: Check authentication
      try {
        print('🔄 Test 4: Checking authentication...');
        final meResponse = await _dioService.mainApi.get('auth/api/v1/user/me');
        print('✅ Authentication works - Status: ${meResponse.statusCode}');
        print('✅ User data: ${meResponse.data}');
      } catch (e) {
        print('❌ Authentication failed: $e');
      }

    } catch (e) {
      print('❌ Debug error: $e');
    }
  }

  /// Test the exact endpoint and PUT method you confirmed
  Future<void> testExactEndpoint() async {
    try {
      print('🧪 Testing exact endpoint and PUT method...');
      
      final userId = '23d589fe-e86b-447d-bb51-6efbf255c277';
      final endpoint = 'auth/api/v1/user/update-user/$userId';
      
      print('🌐 Endpoint: $endpoint');
      print('🔗 Full URL: https://mvp.edetectives.co.bw/$endpoint');
      print('📋 Method: PUT');

      // Test with your exact payload
      final exactPayload = {
        'imageUrl': 'https://scamdetect-dev-afsouth1.s3.af-south-1.amazonaws.com/threads-fraud/87cb9172-62a4-4b85-92cb-e1ea24b1d2c9.jpg',
        'firstName': 'gokuL',
        'lastName': 'krishnan'
      };

      print('📦 Payload: $exactPayload');

      // Test with direct Dio PUT call
      try {
        print('🔄 Testing direct Dio PUT call...');
        final response = await _dioService.mainApi.put(
          endpoint, 
          data: exactPayload,
        );
        print('✅ PUT successful - Status: ${response.statusCode}');
        print('✅ PUT response: ${response.data}');
        print('🎉 Endpoint and PUT method work correctly!');
      } catch (e) {
        print('❌ PUT failed: $e');
        print('🔍 Error details: ${e.toString()}');
      }

    } catch (e) {
      print('❌ Exact endpoint test error: $e');
    }
  }

  /// Test what HTTP methods the server supports
  Future<void> testServerMethods() async {
    try {
      print('🧪 Testing what HTTP methods the server supports...');
      
      final userId = '23d589fe-e86b-447d-bb51-6efbf255c277';
      final endpoint = 'api/v1/user/update-user/$userId';
      
      print('🌐 Testing endpoint: $endpoint');
      print('🔗 Full URL: https://mvp.edetectives.co.bw/auth/$endpoint');

      // Test OPTIONS first to see what methods are allowed
      try {
        print('🔄 Testing OPTIONS method...');
        final optionsResponse = await _dioService.authApi.request(
          endpoint,
          options: Options(method: 'OPTIONS'),
        );
        print('✅ OPTIONS successful - Status: ${optionsResponse.statusCode}');
        print('✅ Allowed methods: ${optionsResponse.headers['allow']}');
        print('✅ Response: ${optionsResponse.data}');
      } catch (e) {
        print('❌ OPTIONS failed: $e');
      }

      // Test HEAD method
      try {
        print('🔄 Testing HEAD method...');
        final headResponse = await _dioService.authApi.request(
          endpoint,
          options: Options(method: 'HEAD'),
        );
        print('✅ HEAD successful - Status: ${headResponse.statusCode}');
      } catch (e) {
        print('❌ HEAD failed: $e');
      }

      // Test GET method
      try {
        print('🔄 Testing GET method...');
        final getResponse = await _dioService.authApi.get(endpoint);
        print('✅ GET successful - Status: ${getResponse.statusCode}');
        print('✅ GET response: ${getResponse.data}');
      } catch (e) {
        print('❌ GET failed: $e');
      }

      // Test PATCH method
      try {
        print('🔄 Testing PATCH method...');
        final patchResponse = await _dioService.authApi.patch(
          endpoint,
          data: {'test': 'data'},
        );
        print('✅ PATCH successful - Status: ${patchResponse.statusCode}');
        print('✅ PATCH response: ${patchResponse.data}');
      } catch (e) {
        print('❌ PATCH failed: $e');
      }

      // Test PUT method
      try {
        print('🔄 Testing PUT method...');
        final putResponse = await _dioService.authApi.put(
          endpoint,
          data: {'test': 'data'},
        );
        print('✅ PUT successful - Status: ${putResponse.statusCode}');
        print('✅ PUT response: ${putResponse.data}');
      } catch (e) {
        print('❌ PUT failed: $e');
      }

      // Test POST method
      try {
        print('🔄 Testing POST method...');
        final postResponse = await _dioService.authApi.post(
          endpoint,
          data: {'test': 'data'},
        );
        print('✅ POST successful - Status: ${postResponse.statusCode}');
        print('✅ POST response: ${postResponse.data}');
      } catch (e) {
        print('❌ POST failed: $e');
      }

      // Test DELETE method
      try {
        print('🔄 Testing DELETE method...');
        final deleteResponse = await _dioService.authApi.delete(endpoint);
        print('✅ DELETE successful - Status: ${deleteResponse.statusCode}');
        print('✅ DELETE response: ${deleteResponse.data}');
      } catch (e) {
        print('❌ DELETE failed: $e');
      }

    } catch (e) {
      print('❌ Server methods test error: $e');
    }
  }

  /// Test different payload structures for image URL update
  Future<void> testImageUrlPayloadStructures() async {
    try {
      print('🧪 Testing different payload structures for image URL...');
      
      final userId = '0346f711-73a0-4047-9877-b65fd32d7541';
      final imageUrl = 'https://scamdetect-dev-afsouth1.s3.af-south-1.amazonaws.com/threads-fraud/87cb9172-62a4-4b85-92cb-e1ea24b1d2c9.jpg';
      final endpoint = '/api/v1/user/update-user/$userId';
      
      print('🌐 Endpoint: $endpoint');
      print('🖼️ Image URL: $imageUrl');
      
      // Test different payload structures
      final payloadStructures = [
        // Structure 1: Flat structure with imageUrl
        {
          'firstName': 'Gobi',
          'lastName': 'nathkkkk',
          'imageUrl': imageUrl,
        },
        // Structure 2: Flat structure with image_url
        {
          'firstName': 'Gobi',
          'lastName': 'nathkkkk',
          'image_url': imageUrl,
        },
        // Structure 3: Nested profile object
        {
          'firstName': 'Gobi',
          'lastName': 'nathkkkk',
          'profile': {
            'imageUrl': imageUrl,
          },
        },
        // Structure 4: Nested profile object with image_url
        {
          'firstName': 'Gobi',
          'lastName': 'nathkkkk',
          'profile': {
            'image_url': imageUrl,
          },
        },
        // Structure 5: Separate image object
        {
          'firstName': 'Gobi',
          'lastName': 'nathkkkk',
          'image': {
            'url': imageUrl,
          },
        },
        // Structure 6: Avatar object
        {
          'firstName': 'Gobi',
          'lastName': 'nathkkkk',
          'avatar': {
            'url': imageUrl,
          },
        },
        // Structure 7: Only imageUrl (no name fields)
        {
          'imageUrl': imageUrl,
        },
        // Structure 8: Only image_url (no name fields)
        {
          'image_url': imageUrl,
        },
      ];
      
      for (int i = 0; i < payloadStructures.length; i++) {
        final payload = payloadStructures[i];
        try {
          print('🔄 Testing payload structure ${i + 1}: $payload');
          
          final response = await _dioService.authApi.put(
            endpoint,
            data: payload,
          );
          
          print('✅ Structure ${i + 1} - Status: ${response.statusCode}');
          print('✅ Structure ${i + 1} - Response: ${response.data}');
          
          // Check if the update was successful by calling user/me
          await Future.delayed(Duration(seconds: 1));
          
          final meResponse = await _dioService.authApi.get('/api/v1/user/me');
          final userData = meResponse.data;
          
          print('📦 User data after structure ${i + 1}: $userData');
          
          // Check if imageUrl is present in the response
          if (userData is Map<String, dynamic>) {
            final returnedImageUrl = userData['imageUrl'];
            print('🖼️ imageUrl in user/me response: $returnedImageUrl');
            
            if (returnedImageUrl == imageUrl) {
              print('🎉 SUCCESS! Payload structure ${i + 1} works!');
              print('📦 Working payload: $payload');
              return;
            }
          }
          
        } catch (e) {
          print('❌ Structure ${i + 1} - Failed: $e');
        }
        
        // Wait a bit between tests
        await Future.delayed(Duration(seconds: 2));
      }
      
      print('❌ No payload structure worked for image URL');
      
    } catch (e) {
      print('❌ Test error: $e');
    }
  }

  /// Test different field names for image URL to see what the server accepts
  Future<void> testImageUrlFieldNames() async {
    try {
      print('🧪 Testing different field names for image URL...');
      
      final userId = '0346f711-73a0-4047-9877-b65fd32d7541';
      final imageUrl = 'https://scamdetect-dev-afsouth1.s3.af-south-1.amazonaws.com/threads-fraud/87cb9172-62a4-4b85-92cb-e1ea24b1d2c9.jpg';
      final endpoint = '/api/v1/user/update-user/$userId';
      
      print('🌐 Endpoint: $endpoint');
      print('🖼️ Image URL: $imageUrl');
      
      // Test different field names for image URL
      final fieldNames = [
        'imageUrl',
        'image_url',
        'profileImage',
        'profile_image',
        'avatar',
        'avatarUrl',
        'avatar_url',
        'picture',
        'pictureUrl',
        'picture_url',
        'photo',
        'photoUrl',
        'photo_url',
      ];
      
      for (final fieldName in fieldNames) {
        try {
          print('🔄 Testing field name: $fieldName');
          
          final payload = {
            'firstName': 'Gobi',
            'lastName': 'nathkkkk',
            fieldName: imageUrl,
          };
          
          print('📦 Payload: $payload');
          
          final response = await _dioService.authApi.put(
            endpoint,
            data: payload,
          );
          
          print('✅ $fieldName - Status: ${response.statusCode}');
          print('✅ $fieldName - Response: ${response.data}');
          
          // Check if the update was successful by calling user/me
          await Future.delayed(Duration(seconds: 1));
          
          final meResponse = await _dioService.authApi.get('/api/v1/user/me');
          final userData = meResponse.data;
          
          print('📦 User data after $fieldName update: $userData');
          
          // Check if imageUrl is present in the response
          if (userData is Map<String, dynamic>) {
            final returnedImageUrl = userData['imageUrl'];
            print('🖼️ imageUrl in user/me response: $returnedImageUrl');
            
            if (returnedImageUrl == imageUrl) {
              print('🎉 SUCCESS! Field name $fieldName works!');
              return;
            }
          }
          
        } catch (e) {
          print('❌ $fieldName - Failed: $e');
        }
        
        // Wait a bit between tests
        await Future.delayed(Duration(seconds: 2));
      }
      
      print('❌ No field name worked for image URL');
      
    } catch (e) {
      print('❌ Test error: $e');
    }
  }

  /// Test the exact payload format you specified
  Future<void> testExactPayload() async {
    try {
      print('🧪 Testing exact payload format...');
      
      final userId = '23d589fe-e86b-447d-bb51-6efbf255c277';
      final exactPayload = {
        'imageUrl': 'https://scamdetect-dev-afsouth1.s3.af-south-1.amazonaws.com/threads-fraud/87cb9172-62a4-4b85-92cb-e1ea24b1d2c9.jpg',
        'firstName': 'gokuL',
        'lastName': 'krishnan'
      };

      print('📦 Exact payload: $exactPayload');
      print('👤 User ID: $userId');

      // Test with ApiService.updateUserProfileExactById
      try {
        print('🔄 Testing with ApiService.updateUserProfileExactById...');
        final response = await _apiService.updateUserProfileExactById(
          userId: userId,
          imageUrl: exactPayload['imageUrl']!,
          firstName: exactPayload['firstName']!,
          lastName: exactPayload['lastName']!,
        );
        print('✅ ApiService.updateUserProfileExactById successful: $response');
      } catch (e) {
        print('❌ ApiService.updateUserProfileExactById failed: $e');
      }

      // Test with direct Dio PUT call
      try {
        print('🔄 Testing with direct Dio PUT call...');
        final endpoint = 'api/v1/user/update-user/$userId';
        final response = await _dioService.authApi.put(endpoint, data: exactPayload);
        print('✅ Direct Dio PUT successful - Status: ${response.statusCode}');
        print('✅ Direct Dio PUT response: ${response.data}');
      } catch (e) {
        print('❌ Direct Dio PUT failed: $e');
      }

    } catch (e) {
      print('❌ Exact payload test error: $e');
    }
  }

  /// Test different HTTP methods for the user update endpoint
  Future<void> testHttpMethods() async {
    try {
      print('🧪 Testing HTTP methods for user update endpoint...');
      
      final userId = '23d589fe-e86b-447d-bb51-6efbf255c277'; // Test user ID
      final endpoint = 'api/v1/user/update-user/$userId';
      final testData = {
        'firstName': 'Test First',
        'lastName': 'Test Last',
        'imageUrl': 'https://example.com/test.jpg',
      };

      print('📦 Test data: $testData');
      print('🌐 Endpoint: $endpoint');

      // Test PUT method
      try {
        print('🔄 Testing PUT method...');
        final putResponse = await _dioService.authApi.put(endpoint, data: testData);
        print('✅ PUT successful - Status: ${putResponse.statusCode}');
        print('✅ PUT response: ${putResponse.data}');
      } catch (e) {
        print('❌ PUT failed: $e');
      }

      // Test POST method
      try {
        print('🔄 Testing POST method...');
        final postResponse = await _dioService.authApi.post(endpoint, data: testData);
        print('✅ POST successful - Status: ${postResponse.statusCode}');
        print('✅ POST response: ${postResponse.data}');
      } catch (e) {
        print('❌ POST failed: $e');
      }

      // Test GET method (should fail)
      try {
        print('🔄 Testing GET method...');
        final getResponse = await _dioService.authApi.get(endpoint);
        print('✅ GET successful - Status: ${getResponse.statusCode}');
        print('✅ GET response: ${getResponse.data}');
      } catch (e) {
        print('❌ GET failed (expected): $e');
      }

      // Test OPTIONS method
      try {
        print('🔄 Testing OPTIONS method...');
        final optionsResponse = await _dioService.authApi.request(
          endpoint,
          options: Options(method: 'OPTIONS'),
        );
        print('✅ OPTIONS successful - Status: ${optionsResponse.statusCode}');
        print('✅ OPTIONS response: ${optionsResponse.data}');
      } catch (e) {
        print('❌ OPTIONS failed: $e');
      }

    } catch (e) {
      print('❌ HTTP methods test error: $e');
    }
  }

  /// Test the specific user update endpoint with your payload
  Future<void> testYourEndpoint() async {
    try {
      print('🧪 Testing your specific endpoint...');
      
      final userId = '23d589fe-e86b-447d-bb51-6efbf255c277';
      final payload = {
        'imageUrl': 'https://scamdetect-dev-afsouth1.s3.af-south-1.amazonaws.com/threads-fraud/87cb9172-62a4-4b85-92cb-e1ea24b1d2c9.jpg',
        'firstName': 'gokuL',
        'lastName': 'krishnan'
      };

      print('📦 Your payload: $payload');
      print('👤 User ID: $userId');

      // Test with ApiService
      try {
        print('🔄 Testing with ApiService.updateUserProfileById...');
        final response = await _apiService.updateUserProfileById(userId, payload);
        print('✅ ApiService test successful: $response');
      } catch (e) {
        print('❌ ApiService test failed: $e');
      }

      // Test with direct Dio call
      try {
        print('🔄 Testing with direct Dio call...');
        final endpoint = 'api/v1/user/update-user/$userId';
        final response = await _dioService.authApi.put(endpoint, data: payload);
        print('✅ Direct Dio test successful - Status: ${response.statusCode}');
        print('✅ Direct Dio response: ${response.data}');
      } catch (e) {
        print('❌ Direct Dio test failed: $e');
      }

    } catch (e) {
      print('❌ Your endpoint test error: $e');
    }
  }
}
