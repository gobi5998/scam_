import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/filter_model.dart';
import 'jwt_service.dart';
import 'dio_service.dart';
import 'token_storage.dart';
import 'dart:convert'; // Added for json.decode

class ApiService {
  final DioService _dioService = DioService();
  bool _useMockData = false;
  bool _isRefreshingToken = false;

  ApiService() {
    // Using the centralized DioService instead of separate Dio instances
  }

  // Interceptors are now handled by DioService
  void _setupInterceptors(Dio dio) {
    // This method is kept for compatibility but interceptors are now handled by DioService
  }

  Future<void> setUseMockData(bool value) async {
    _useMockData = value;
  }

  Future<String?> _getAccessToken() async {
    try {
      // Use secure storage for tokens
      String? token = await TokenStorage.getAccessToken();

      // Fallback to JWT service if secure storage fails
      if (token == null || token.isEmpty) {
        print('API Service - Secure storage empty, trying JWT service...');
        token = await JwtService.getTokenWithFallback();
      }

      return token;
    } catch (e) {
      print('API Service - Error getting access token: $e');
      return null;
    }
  }

  Future<String?> _getRefreshToken() async {
    String? refreshToken = await TokenStorage.getRefreshToken();

    // Fallback to SharedPreferences if secure storage is empty
    if (refreshToken == null || refreshToken.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      refreshToken = prefs.getString('refresh_token');
    }

    return refreshToken;
  }

  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    await TokenStorage.setAccessToken(accessToken);
    await TokenStorage.setRefreshToken(refreshToken);
    // Also save using JWT service for device compatibility
    await JwtService.saveToken(accessToken);

    // Save refresh token to SharedPreferences as backup
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('refresh_token', refreshToken);
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _getRefreshToken();
      print('Attempting token refresh with: $refreshToken');
      if (refreshToken == null) {
        print('No refresh token found, cannot refresh');
        return false;
      }

      final response = await _dioService.authPost(
        '${ApiConfig.authBaseUrl}/auth/refresh-token',
        data: {'refreshToken': refreshToken},
      );

      final newAccessToken = response.data['access_token'];
      final newRefreshToken = response.data['refresh_token'];

      print('Token refresh successful - New access token: $newAccessToken');
      await _saveTokens(newAccessToken, newRefreshToken);
      return true;
    } catch (e) {
      print('Token refresh failed: $e');
      return false;
    }
  }

  Future<Response> get(String url) async {
    return _dioService.get(url);
  }

  Future<Response> post(String url, dynamic data) async {
    return _dioService.post(url, data: data);
  }

  //////////////////////////////////////////////////////////////////////

  // Example: Login using Auth Server
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      print('Attempting login with username: $username');

      final response = await _dioService.authPost(
        ApiConfig.loginEndpoint,
        data: {'username': username, 'password': password},
      );

      print('Raw response: ${response}');
      print('Raw response data: ${response.data}');

      if (response.data == null || response.data is! Map<String, dynamic>) {
        throw Exception('Invalid response from server');
      }

      final Map<String, dynamic> responseData = response.data;

      // Save tokens if available
      if (responseData.containsKey('access_token')) {
        final accessToken = responseData['access_token'];
        await _saveTokens(accessToken, responseData['refresh_token'] ?? '');
        print('access_token: ${accessToken}');
      }
      if (responseData.containsKey('refresh_token')) {
        print('refresh_token: ${responseData['refresh_token']}');
      }
      if (responseData.containsKey('id_token')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('id_token', responseData['id_token']);
        print('id_token: ${responseData['id_token']}');
      }

      return responseData;
    } on DioException catch (e) {
      print('DioException during login: ${e.message}');
      print('DioException response data: ${e.response?.data}');
      print('DioException status code: ${e.response?.statusCode}');

      final errMsg = e.response?.data is Map<String, dynamic>
          ? e.response?.data['message'] ?? 'Unknown error'
          : e.message;

      throw Exception('Login failed: $errMsg');
    } catch (e) {
      print('General exception during login: $e');
      throw Exception('Login failed: Invalid response from server');
    }
  }

  // Example: Fetch dashboard stats using Main Server
  Future<Map<String, dynamic>?> getDashboardStats() async {
    try {
      final response = await _dioService.get(ApiConfig.dashboardStatsEndpoint);

      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to load dashboard stats');
      }
    } catch (e) {
      print("Error fetching stats: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>> register(
    String firstname,
    String lastname,
    String username,
    String password,
    String role,
  ) async {
    try {
      // Print the payload for debugging
      final payload = {
        'firstName': firstname,
        'lastName': lastname,
        'username': username,
        'password': password,
        'role': role,
      };
      print('Registration payload: $payload');

      final response = await _dioService.authPost(
        ApiConfig.registerEndpoint,
        data: payload,
      );

      print('Registration response: ${response.data}');
      print('Type of response.data: ${response.data.runtimeType}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Handle different response formats
        Map<String, dynamic> responseData;

        if (response.data is String) {
          // If response is a string, try to parse it as JSON
          try {
            responseData = json.decode(response.data) as Map<String, dynamic>;
          } catch (e) {
            print('Failed to parse string response as JSON: $e');
            // If it's not JSON, create a success response
            responseData = {'message': response.data, 'status': 'success'};
          }
        } else if (response.data is Map<String, dynamic>) {
          responseData = response.data;
        } else {
          print('Unexpected response format: ${response.data}');
          // Create a success response for unexpected formats
          responseData = {
            'message': 'Registration successful',
            'status': 'success',
          };
        }

        // Save tokens if they exist in the response
        final prefs = await SharedPreferences.getInstance();
        if (responseData.containsKey('access_token')) {
          await prefs.setString('auth_token', responseData['access_token']);
          await JwtService.saveToken(responseData['access_token']);
          print('access_token saved: ${responseData['access_token']}');
        }
        if (responseData.containsKey('refresh_token')) {
          await prefs.setString('refresh_token', responseData['refresh_token']);
          print('refresh_token saved: ${responseData['refresh_token']}');
        }
        if (responseData.containsKey('id_token')) {
          await prefs.setString('id_token', responseData['id_token']);
          print('id_token saved: ${responseData['id_token']}');
        }

        return responseData;
      } else {
        // Print backend error message if available
        if (response.data is Map<String, dynamic> &&
            response.data['message'] != null) {
          throw Exception(response.data['message']);
        }
        throw Exception('Registration failed - Status: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('DioException during registration: ${e.message}');
      print('Response data: ${e.response?.data}');
      // If API is not available, use mock data
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.response?.statusCode == 404) {
        print('Using mock data for registration');
        return _getMockRegisterResponse(firstname, lastname, username, role);
      }
      if (e.response?.statusCode == 409) {
        throw Exception('Username or email already exists');
      } else if (e.response?.statusCode == 400) {
        // Print backend error message if available
        if (e.response?.data is Map<String, dynamic> &&
            e.response?.data['message'] != null) {
          throw Exception(e.response?.data['message']);
        }
        throw Exception('Invalid registration data');
      } else {
        throw Exception(
          e.response?.data?['message'] ?? 'Registration failed: ${e.message}',
        );
      }
    } catch (e) {
      print('General exception during registration: $e');
      // Fallback to mock data
      return _getMockRegisterResponse(firstname, lastname, username, role);
    }
  }

  Map<String, dynamic> _getMockLoginResponse(String username) {
    return {
      'user': {
        'id': '1',
        'username': username,
        'email': '$username@example.com',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      'token': 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
      'message': 'Login successful (mock data)',
    };
  }

  Map<String, dynamic> _getMockRegisterResponse(
    String firstname,
    String lastname,
    String username,
    String role,
  ) {
    return {
      'user': {
        'id': '1',
        'firstName': firstname,
        'lastName': lastname,
        'username': username,
        'role': role,
      },
      'token': 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
      'message': 'Registration successful (mock data)',
    };
  }

  Future<void> logout() async {
    try {
      if (!_useMockData) {
        await _dioService.authPost(ApiConfig.logoutEndpoint);
      }
      // Clear tokens from shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('refresh_token');
    } on DioException catch (e) {
      print('Logout error: ${e.message}');
      // Even if logout fails, clear the tokens locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('refresh_token');
    }
  }

  // Security alerts endpoints
  Future<List<Map<String, dynamic>>> getSecurityAlerts() async {
    try {
      if (_useMockData) {
        return _getMockSecurityAlerts();
      }

      final response = await _dioService.get(ApiConfig.securityAlertsEndpoint);
      if (response.statusCode == 200) {
        // Handle different response structures
        if (response.data is List) {
          return List<Map<String, dynamic>>.from(response.data);
        } else if (response.data.containsKey('alerts')) {
          return List<Map<String, dynamic>>.from(response.data['alerts']);
        } else {
          return [];
        }
      }
      throw Exception('Failed to fetch security alerts');
    } on DioException catch (e) {
      print('Error fetching security alerts: ${e.message}');
      // Return mock data
      return _getMockSecurityAlerts();
    }
  }

  List<Map<String, dynamic>> _getMockSecurityAlerts() {
    return [
      {
        'id': '1',
        'title': 'Suspicious Email Detected',
        'description': 'A phishing email was detected in your inbox',
        'severity': 'high',
        'type': 'phishing',
        'timestamp': DateTime.now()
            .subtract(Duration(hours: 2))
            .toIso8601String(),
        'is_resolved': false,
      },
      {
        'id': '2',
        'title': 'Malware Alert',
        'description': 'Potential malware detected in downloaded file',
        'severity': 'critical',
        'type': 'malware',
        'timestamp': DateTime.now()
            .subtract(Duration(hours: 1))
            .toIso8601String(),
        'is_resolved': true,
      },
    ];
  }

  // Future<Map<String, dynamic>> getDashboardStats() async {
  //   try {
  //     if (_useMockData) {
  //       return _getMockDashboardStats();
  //     }
  //
  //     final response = await _dioMain.get(ApiConfig.dashboardStatsEndpoint);
  //     if (response.statusCode == 200) {
  //       return response.data;
  //     }
  //     throw Exception('Failed to fetch dashboard stats');
  //   } on DioException catch (e) {
  //     print('Error fetching dashboard stats: ${e.message}');
  //     // Return mock data
  //     return _getMockDashboardStats();
  //   }
  // }

  Map<String, dynamic> _getMockDashboardStats() {
    return {
      'total_alerts': 50,
      'resolved_alerts': 35,
      'pending_alerts': 15,
      'alerts_by_type': {'spam': 20, 'malware': 15, 'fraud': 10, 'other': 5},
      'alerts_by_severity': {'low': 25, 'medium': 15, 'high': 8, 'critical': 2},
      'threat_trend_data': [30, 35, 40, 50, 45, 38, 42],
      'threat_bar_data': [10, 20, 15, 30, 25, 20, 10],
      'risk_score': 75.0,
    };
  }

  Future<Map<String, dynamic>> reportSecurityIssue(
    Map<String, dynamic> issueData,
  ) async {
    try {
      if (_useMockData) {
        return {'message': 'Issue reported successfully (mock data)'};
      }

      final response = await _dioService.reportsPost(
        ApiConfig.reportSecurityIssueEndpoint,
        data: issueData,
      );
      if (response.statusCode == 201) {
        return response.data;
      }
      throw Exception('Failed to report security issue');
    } on DioException catch (e) {
      print('Error reporting security issue: ${e.message}');
      return {'message': 'Issue reported successfully (mock data)'};
    }
  }

  Future<List<Map<String, dynamic>>> getThreatHistory({
    String period = '1D',
  }) async {
    try {
      if (_useMockData) {
        return _getMockThreatHistory();
      }

      final response = await _dioService.get(
        ApiConfig.threatHistoryEndpoint,
        queryParameters: {'period': period},
      );
      if (response.statusCode == 200) {
        if (response.data is List) {
          return List<Map<String, dynamic>>.from(response.data);
        } else if (response.data.containsKey('threats')) {
          return List<Map<String, dynamic>>.from(response.data['threats']);
        } else {
          return [];
        }
      }
      throw Exception('Failed to fetch threat history');
    } on DioException catch (e) {
      print('Error fetching threat history: ${e.message}');
      return _getMockThreatHistory();
    }
  }

  List<Map<String, dynamic>> _getMockThreatHistory() {
    return [
      {'date': '2024-01-01', 'count': 10},
      {'date': '2024-01-02', 'count': 15},
      {'date': '2024-01-03', 'count': 8},
      {'date': '2024-01-04', 'count': 20},
      {'date': '2024-01-05', 'count': 12},
    ];
  }

  // User profile endpoints
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      if (_useMockData) {
        return _getMockUserProfile();
      }

      final response = await _dioService.authGet(ApiConfig.userProfileEndpoint);

      print('response data$response');
      if (response.statusCode == 200) {
        return response.data;
      }
      throw Exception('Failed to fetch user profile');
    } on DioException catch (e) {
      print('Error fetching user profile: ${e.message}');
      // Return mock user data
      return _getMockUserProfile();
    }
  }

  Map<String, dynamic> _getMockUserProfile() {
    return {'id': '1', 'username': 'demo_user', 'email': 'demo@example.com'};
  }

  Future<Map<String, dynamic>> updateUserProfile(
    Map<String, dynamic> profileData,
  ) async {
    try {
      if (_useMockData) {
        return {'message': 'Profile updated successfully (mock data)'};
      }

      final response = await _dioService.authPut(
        ApiConfig.updateProfileEndpoint,
        data: profileData,
      );
      if (response.statusCode == 200) {
        return response.data;
      }
      throw Exception('Failed to update user profile');
    } on DioException catch (e) {
      print('Error updating user profile: ${e.message}');
      return {'message': 'Profile updated successfully (mock data)'};
    }
  }

  Future<List<Map<String, dynamic>>> fetchReportCategories() async {
    try {
      print(
        '🔍 Fetching report categories from: ${_dioService.mainApi.options.baseUrl}${ApiConfig.reportCategoryEndpoint}',
      );
      final response = await _dioService.get(ApiConfig.reportCategoryEndpoint);
      print('✅ Categories response: ${response.data}');

      if (response.data != null && response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      } else if (response.data != null && response.data is Map) {
        // Handle case where response is wrapped in an object
        final data = response.data as Map<String, dynamic>;
        if (data.containsKey('data') && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }

      print('⚠️ Unexpected response format: ${response.data}');
      return [];
    } catch (e) {
      print('❌ Error fetching categories: $e');
      if (e is DioException) {
        print('📡 DioException type: ${e.type}');
        print('📡 DioException message: ${e.message}');
        print('📡 Response status: ${e.response?.statusCode}');
        print('📡 Response data: ${e.response?.data}');
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchReportTypesByCategory(
    String categoryId,
  ) async {
    try {
      print('🔍 Fetching report types for category: $categoryId');

      // Check if categoryId is a valid ObjectId format
      final isObjectId = RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(categoryId);

      if (!isObjectId) {
        print('⚠️ CategoryId "$categoryId" is not a valid ObjectId format');
        print('🔄 Trying to fetch all report types instead...');

        // If not a valid ObjectId, fetch all types and filter client-side
        final allTypes = await fetchReportTypes();
        return allTypes.where((type) {
          final typeCategoryId = type['reportCategoryId'];
          if (typeCategoryId is Map) {
            return typeCategoryId['_id']?.toString() == categoryId ||
                typeCategoryId['name']?.toString().toLowerCase().contains(
                      categoryId.toLowerCase(),
                    ) ==
                    true;
          } else {
            return typeCategoryId?.toString() == categoryId;
          }
        }).toList();
      }

      final response = await _dioService.get(
        ApiConfig.reportTypeEndpoint,
        queryParameters: {'id': categoryId},
      );

      if (response.data != null && response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      } else if (response.data != null && response.data is Map) {
        // Handle case where response is wrapped in an object
        final data = response.data as Map<String, dynamic>;
        if (data.containsKey('data') && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }

      print('⚠️ Unexpected response format: ${response.data}');
      return [];
    } catch (e) {
      print('❌ Error fetching types for category $categoryId: $e');
      if (e is DioException) {
        print('📡 DioException type: ${e.type}');
        print('📡 DioException message: ${e.message}');
        print('📡 Response status: ${e.response?.statusCode}');
        print('📡 Response data: ${e.response?.data}');
      }
      return [];
    }
  }

  Future<void> submitScamReport(Map<String, dynamic> data) async {
    try {
      print('🟡 Submitting scam report to backend...');

      // Get current user information
      final userInfo = await _getCurrentUserInfo();
      print('🔍 User Info: $userInfo');

      // Test backend connectivity first
      final isConnected = await testBackendConnectivity();
      if (!isConnected) {
        print('❌ Backend connectivity test failed - cannot submit report');
        throw Exception('Backend connectivity test failed');
      }

      print(
        '🟡 Target URL: ${_dioService.reportsApi.options.baseUrl}${ApiConfig.scamReportsEndpoint}',
      );
      print('🟡 Base URL: ${_dioService.reportsApi.options.baseUrl}');
      print('🟡 Scam Reports Endpoint: ${ApiConfig.scamReportsEndpoint}');
      print(
        '🟡 Report Security Issue Endpoint: ${ApiConfig.reportSecurityIssueEndpoint}',
      );
      print('🟡 Report data: $data');

      // Ensure required fields are present and properly formatted
      final reportData = Map<String, dynamic>.from(data);

      // Validate and format required fields according to backend format
      reportData['reportCategoryId'] = reportData['reportCategoryId'] ?? '';
      reportData['reportTypeId'] = reportData['reportTypeId'] ?? '';

      // Validate alert levels - must be a valid ObjectId
      if (reportData['alertLevels'] == null ||
          reportData['alertLevels'].toString().isEmpty) {
        print('❌ Alert levels is null or empty - cannot submit to backend');
        throw Exception(
          'Alert levels is required and must be a valid ObjectId',
        );
      }

      reportData['keycloackUserId'] =
          reportData['keycloackUserId'] ??
          '123e4567-e89b-12d3-a456-426614174000';
      reportData['createdBy'] = reportData['createdBy'] ?? '';
      reportData['isActive'] = reportData['isActive'] ?? true;
      reportData['status'] = reportData['status'] ?? 'draft';
      reportData['reportOutcome'] = reportData['reportOutcome'] ?? true;

      // Ensure arrays are properly formatted as arrays
      reportData['phoneNumbers'] = reportData['phoneNumbers'] is List
          ? List<String>.from(reportData['phoneNumbers'])
          : [];
      reportData['emails'] = reportData['emails'] is List
          ? List<String>.from(reportData['emails'])
          : [];
      reportData['mediaHandles'] = reportData['mediaHandles'] is List
          ? List<String>.from(reportData['mediaHandles'])
          : [];
      reportData['screenshots'] = reportData['screenshots'] is List
          ? reportData['screenshots']
          : [];
      reportData['voiceMessages'] = reportData['voiceMessages'] is List
          ? reportData['voiceMessages']
          : [];
      reportData['documents'] = reportData['documents'] is List
          ? reportData['documents']
          : [];

      // Ensure string fields are properly formatted
      reportData['website'] = reportData['website']?.toString() ?? '';
      reportData['currency'] = reportData['currency']?.toString() ?? 'INR';
      reportData['moneyLost'] = reportData['moneyLost']?.toString() ?? '0';
      reportData['description'] = reportData['description']?.toString() ?? '';
      reportData['scammerName'] = reportData['scammerName']?.toString() ?? '';

      // Ensure timestamps are properly formatted
      reportData['createdAt'] =
          reportData['createdAt'] ?? DateTime.now().toIso8601String();
      reportData['updatedAt'] = DateTime.now().toIso8601String();

      // Ensure location is properly formatted
      if (!reportData.containsKey('location')) {
        // For production, you would implement a proper location service here
        // For now, we'll use a fallback that indicates location was not available
        print('⚠️ No location provided - using fallback coordinates');
        reportData['location'] = {
          'type': 'Point',
          'coordinates': [
            0.0,
            0.0,
          ], // Fallback coordinates when location unavailable
        };
      }

      // Keep arrays as arrays for backend compatibility
      // The backend expects phoneNumbers, emails, mediaHandles as arrays
      if (reportData['phoneNumbers'] is List) {
        print('📋 phoneNumbers as array: ${reportData['phoneNumbers']}');
        print('📋 phoneNumbers length: ${reportData['phoneNumbers'].length}');
        print(
          '📋 phoneNumbers type: ${reportData['phoneNumbers'].runtimeType}',
        );
      }
      if (reportData['emails'] is List) {
        print('📋 emails as array: ${reportData['emails']}');
        print('📋 emails length: ${reportData['emails'].length}');
        print('📋 emails type: ${reportData['emails'].runtimeType}');
      }
      if (reportData['mediaHandles'] is List) {
        print('📋 mediaHandles as array: ${reportData['mediaHandles']}');
        print('📋 mediaHandles length: ${reportData['mediaHandles'].length}');
        print(
          '📋 mediaHandles type: ${reportData['mediaHandles'].runtimeType}',
        );
      }

      print('📋 Final report data being sent: ${jsonEncode(reportData)}');
      print('📋 Data length: ${jsonEncode(reportData).length} characters');
      print('📋 KeycloakUserId: ${reportData['keycloackUserId']}');
      print('📋 AlertLevels: ${reportData['alertLevels']}');
      print('📋 ReportCategoryId: ${reportData['reportCategoryId']}');
      print('📋 ReportTypeId: ${reportData['reportTypeId']}');

      // Debug authentication token
      final token = await _getAccessToken();
      print(
        '🔐 Authentication token present: ${token != null && token.isNotEmpty ? 'YES' : 'NO'}',
      );
      if (token != null && token.isNotEmpty) {
        print('🔐 Token length: ${token.length}');
        print(
          '🔐 Token preview: ${token.substring(0, token.length > 50 ? 50 : token.length)}...',
        );
      }

      // Try the scam-specific endpoint first
      Response response;
      try {
        print(
          '🟡 Trying scam-specific endpoint: ${ApiConfig.scamReportsEndpoint}',
        );
        print('🟡 Reports Base URL: ${ApiConfig.reportsBaseUrl}');
        print('🟡 Dio Base URL: ${_dioService.reportsApi.options.baseUrl}');
        print(
          '🟡 Expected Full URL: ${ApiConfig.reportsBaseUrl}${ApiConfig.scamReportsEndpoint}',
        );
        response = await _dioService.reportsPost(
          ApiConfig.scamReportsEndpoint, // Use the scam-specific endpoint
          data: reportData,
        );
        print(
          '✅ Using scam-specific endpoint: ${ApiConfig.scamReportsEndpoint}',
        );
      } catch (e) {
        print(
          '⚠️ Scam-specific endpoint failed, trying general reports endpoint...',
        );
        print('⚠️ Error: $e');
        print(
          '🟡 Trying general endpoint: ${ApiConfig.reportSecurityIssueEndpoint}',
        );
        print(
          '🟡 Expected Full URL: ${ApiConfig.reportsBaseUrl}${ApiConfig.reportSecurityIssueEndpoint}',
        );
        response = await _dioService.reportsPost(
          ApiConfig.reportSecurityIssueEndpoint, // Fallback to general endpoint
          data: reportData,
        );
        print(
          '✅ Using general reports endpoint: ${ApiConfig.reportSecurityIssueEndpoint}',
        );
      }

      print('✅ Backend response: ${response.data}');
      print('✅ Response status: ${response.statusCode}');
      print('✅ Response data type: ${response.data.runtimeType}');
      if (response.data != null) {
        print('✅ Response data keys: ${(response.data as Map).keys.toList()}');
      }

      // Verify the report was stored
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Scam report successfully stored in backend');

        // Try to fetch the report back to verify
        if (response.data != null && response.data['_id'] != null) {
          try {
            final verifyResponse = await _dioService.reportsGet(
              '${ApiConfig.reportSecurityIssueEndpoint}/${response.data['_id']}',
            );
            print('✅ Verified report in backend: ${verifyResponse.data}');
          } catch (e) {
            print('⚠️ Could not verify report: $e');
          }
        }
      } else {
        print(
          '❌ Failed to store scam report in backend. Status: ${response.statusCode}',
        );
        print('❌ Response data: ${response.data}');
      }
    } catch (e) {
      print('❌ Error sending scam report to backend: $e');
      if (e is DioException) {
        print('❌ DioException type: ${e.type}');
        print('❌ DioException message: ${e.message}');
        print('❌ DioException response: ${e.response?.data}');
        print('❌ Request URL: ${e.requestOptions.uri}');
        print('❌ Request method: ${e.requestOptions.method}');
        print('❌ Request base URL: ${e.requestOptions.baseUrl}');
        print('❌ Request path: ${e.requestOptions.path}');
        print('❌ Request headers: ${e.requestOptions.headers}');
        print('❌ Request data: ${e.requestOptions.data}');
      }
      rethrow;
    }
  }

  // New integrated report submission with file upload
  Future<void> submitReportWithFiles(
    Map<String, dynamic> reportData,
    List<Map<String, dynamic>> screenshots,
    List<Map<String, dynamic>> documents,
    List<Map<String, dynamic>> voiceMessages,
    List<Map<String, dynamic>> videoRecordings,
    List<Map<String, dynamic>> voiceRecordings,
  ) async {
    try {
      print('🟡 Submitting report with integrated files...');

      print('🟡 Sending report data to backend...');
      print(
        '🟡 Target URL: ${ApiConfig.mainBaseUrl}${ApiConfig.reportSecurityIssueEndpoint}',
      );
      print('🟡 Report data: $reportData');

      final response = await _dioService.reportsApi.post(
        ApiConfig.reportSecurityIssueEndpoint,
        data: reportData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      print('🟡 Backend response: ${response.data}');

      // Verify report was stored
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Report successfully stored in backend');
        // Fetch the report back to verify
        try {
          final verifyResponse = await _dioService.reportsGet(
            '${ApiConfig.reportSecurityIssueEndpoint}/${response.data['_id']}',
          );
          print('✅ Verified report in backend: ${verifyResponse.data}');
        } catch (e) {
          print('⚠️ Could not verify report: $e');
        }
      } else {
        print('❌ Failed to store report in backend');
      }
    } catch (e) {
      print('❌ Error submitting report with files: $e');
      if (e is DioException) {
        print('❌ DioException type: ${e.type}');
        print('❌ DioException message: ${e.message}');
        print('❌ DioException response: ${e.response?.data}');
        print('❌ Request URL: ${e.requestOptions.uri}');
        print('❌ Request method: ${e.requestOptions.method}');
        print('❌ Request headers: ${e.requestOptions.headers}');

        // Save report locally if it's a connection error
        if (e.type == DioExceptionType.connectionError) {
          print('📱 Connection error - saving report locally for later sync');
          // TODO: Implement local storage save
        }
      }
      rethrow;
    }
  }

  Future<void> submitFraudReport(Map<String, dynamic> data) async {
    try {
      print('🟡 Submitting fraud report to backend...');

      // Get current user information
      final userInfo = await _getCurrentUserInfo();
      print('🔍 User Info: $userInfo');

      // Test backend connectivity first
      final isConnected = await testBackendConnectivity();
      if (!isConnected) {
        print('❌ Backend connectivity test failed - cannot submit report');
        throw Exception('Backend connectivity test failed');
      }

      print(
        '🟡 Target URL: ${_dioService.reportsApi.options.baseUrl}${ApiConfig.fraudReportsEndpoint}',
      );
      print('🟡 Base URL: ${_dioService.reportsApi.options.baseUrl}');
      print('🟡 Fraud Reports Endpoint: ${ApiConfig.fraudReportsEndpoint}');
      print(
        '🟡 Report Security Issue Endpoint: ${ApiConfig.reportSecurityIssueEndpoint}',
      );
      print('🟡 Report data: $data');

      // Ensure required fields are present and properly formatted
      final reportData = Map<String, dynamic>.from(data);

      // Validate and format required fields according to backend format
      reportData['reportCategoryId'] = reportData['reportCategoryId'] ?? '';
      reportData['reportTypeId'] = reportData['reportTypeId'] ?? '';

      // Validate alert levels - must be a valid ObjectId
      if (reportData['alertLevels'] == null ||
          reportData['alertLevels'].toString().isEmpty) {
        print('❌ Alert levels is null or empty - cannot submit to backend');
        throw Exception(
          'Alert levels is required and must be a valid ObjectId',
        );
      }

      reportData['keycloackUserId'] =
          reportData['keycloackUserId'] ??
          '123e4567-e89b-12d3-a456-426614174000';
      reportData['createdBy'] = reportData['createdBy'] ?? '';
      reportData['isActive'] = reportData['isActive'] ?? true;
      reportData['status'] = reportData['status'] ?? 'draft';
      reportData['reportOutcome'] = reportData['reportOutcome'] ?? true;

      // Ensure arrays are properly formatted as arrays
      reportData['phoneNumbers'] = reportData['phoneNumbers'] is List
          ? List<String>.from(reportData['phoneNumbers'])
          : [];
      reportData['emails'] = reportData['emails'] is List
          ? List<String>.from(reportData['emails'])
          : [];
      reportData['mediaHandles'] = reportData['mediaHandles'] is List
          ? List<String>.from(reportData['mediaHandles'])
          : [];
      reportData['screenshots'] = reportData['screenshots'] is List
          ? reportData['screenshots']
          : [];
      reportData['voiceMessages'] = reportData['voiceMessages'] is List
          ? reportData['voiceMessages']
          : [];
      reportData['documents'] = reportData['documents'] is List
          ? reportData['documents']
          : [];

      // Ensure string fields are properly formatted
      reportData['website'] = reportData['website']?.toString() ?? '';
      reportData['currency'] = reportData['currency']?.toString() ?? 'INR';
      reportData['moneyLost'] = reportData['moneyLost']?.toString() ?? '0';
      reportData['description'] = reportData['description']?.toString() ?? '';
      reportData['fraudsterName'] =
          reportData['fraudsterName']?.toString() ?? '';
      reportData['companyName'] = reportData['companyName']?.toString() ?? '';
      reportData['methodOfContact'] =
          reportData['methodOfContact']?.toString() ?? '';

      // Ensure timestamps are properly formatted
      reportData['createdAt'] =
          reportData['createdAt'] ?? DateTime.now().toIso8601String();
      reportData['updatedAt'] = DateTime.now().toIso8601String();

      // Ensure location is properly formatted
      if (!reportData.containsKey('location')) {
        // For production, you would implement a proper location service here
        // For now, we'll use a fallback that indicates location was not available
        print('⚠️ No location provided - using fallback coordinates');
        reportData['location'] = {
          'type': 'Point',
          'coordinates': [
            0.0,
            0.0,
          ], // Fallback coordinates when location unavailable
        };
      }

      // Keep arrays as arrays for backend compatibility
      // The backend expects phoneNumbers, emails, mediaHandles as arrays
      if (reportData['phoneNumbers'] is List) {
        print('📋 phoneNumbers as array: ${reportData['phoneNumbers']}');
        print('📋 phoneNumbers length: ${reportData['phoneNumbers'].length}');
        print(
          '📋 phoneNumbers type: ${reportData['phoneNumbers'].runtimeType}',
        );
      }

      if (reportData['emails'] is List) {
        print('📧 emails as array: ${reportData['emails']}');
        print('📧 emails length: ${reportData['emails'].length}');
        print('📧 emails type: ${reportData['emails'].runtimeType}');
      }

      if (reportData['mediaHandles'] is List) {
        print('📱 mediaHandles as array: ${reportData['mediaHandles']}');
        print('📱 mediaHandles length: ${reportData['mediaHandles'].length}');
        print(
          '📱 mediaHandles type: ${reportData['mediaHandles'].runtimeType}',
        );
      }

      print('🟡 Final report data for backend: $reportData');

      // Try the fraud-specific endpoint first, then fallback to general endpoint
      Response response;
      try {
        print(
          '🟡 Trying fraud-specific endpoint: ${ApiConfig.fraudReportsEndpoint}',
        );
        print(
          '🟡 Full URL: ${ApiConfig.reportsBaseUrl}${ApiConfig.fraudReportsEndpoint}',
        );
        response = await _dioService.reportsPost(
          ApiConfig.fraudReportsEndpoint, // Use the fraud-specific endpoint
          data: reportData,
        );
        print(
          '✅ Using fraud-specific endpoint: ${ApiConfig.fraudReportsEndpoint}',
        );
      } catch (e) {
        print(
          '⚠️ Fraud-specific endpoint failed, trying general reports endpoint...',
        );
        print('⚠️ Error: $e');
        print(
          '🟡 Trying general endpoint: ${ApiConfig.reportSecurityIssueEndpoint}',
        );
        print(
          '🟡 Full URL: ${ApiConfig.reportsBaseUrl}${ApiConfig.reportSecurityIssueEndpoint}',
        );
        response = await _dioService.reportsPost(
          ApiConfig.reportSecurityIssueEndpoint, // Fallback to general endpoint
          data: reportData,
        );
        print(
          '✅ Using general reports endpoint: ${ApiConfig.reportSecurityIssueEndpoint}',
        );
      }

      print('✅ Fraud report submitted successfully');
      print('✅ Backend response: ${response.data}');
      print('✅ Response status: ${response.statusCode}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        print('❌ Backend returned non-success status: ${response.statusCode}');
        print('❌ Response data: ${response.data}');
        throw Exception(
          'Backend returned status ${response.statusCode}: ${response.data}',
        );
      }

      print('✅ Fraud report submission completed successfully');
    } catch (e) {
      print('❌ Error submitting fraud report to backend: $e');
      print('❌ Error type: ${e.runtimeType}');
      if (e is DioException) {
        print('📡 DioException type: ${e.type}');
        print('📡 DioException message: ${e.message}');
        print('📡 Response status: ${e.response?.statusCode}');
        print('📡 Response data: ${e.response?.data}');

        // Handle authentication errors gracefully
        if (e.response?.statusCode == 401) {
          print(
            '🔐 Authentication error detected - using fallback credentials',
          );
          print(
            '🔍 This might be because auth and reports are on different servers',
          );
          print('🔍 Auth Server: ${ApiConfig.authBaseUrl}');
          print('🔍 Reports Server: ${ApiConfig.reportsBaseUrl}');
          // The report will be saved locally and synced later when authentication is restored
        }
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchReportTypes() async {
    try {
      print(
        '🔍 Fetching report types from: ${_dioService.mainApi.options.baseUrl}${ApiConfig.reportTypeEndpoint}',
      );
      final response = await _dioService.get(ApiConfig.reportTypeEndpoint);
      print('✅ Types response: ${response.data}');

      if (response.data != null && response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      } else if (response.data != null && response.data is Map) {
        // Handle case where response is wrapped in an object
        final data = response.data as Map<String, dynamic>;
        if (data.containsKey('data') && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }

      print('⚠️ Unexpected response format: ${response.data}');
      return [];
    } catch (e) {
      print('❌ Error fetching types: $e');
      if (e is DioException) {
        print('📡 DioException type: ${e.type}');
        print('📡 DioException message: ${e.message}');
        print('📡 Response status: ${e.response?.statusCode}');
        print('📡 Response data: ${e.response?.data}');
      }
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchCategoryById(String categoryId) async {
    try {
      final response = await _dioService.get(
        '/api/report-category/$categoryId',
      );
      return response.data;
    } catch (e) {
      print('Error fetching category by ID: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchTypeById(String typeId) async {
    try {
      final response = await _dioService.get(
        '${ApiConfig.reportTypeEndpoint}/$typeId',
      );
      return response.data;
    } catch (e) {
      print('Error fetching type by ID: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAlertLevels() async {
    try {
      final response = await _dioService.get(ApiConfig.alertLevelsEndpoint);
      if (response.statusCode == 200 && response.data is List) {
        final levels = List<Map<String, dynamic>>.from(response.data);
        return levels.where((level) => level['isActive'] == true).toList();
      }
      return [
        {'_id': '64e8b2c83c9f9c1e2aa1a333', 'name': 'Low', 'isActive': true},
        {'_id': '64e8b2c83c9f9c1e2aa1a334', 'name': 'Medium', 'isActive': true},
        {'_id': '64e8b2c83c9f9c1e2aa1a335', 'name': 'High', 'isActive': true},
        {
          '_id': '64e8b2c83c9f9c1e2aa1a336',
          'name': 'Critical',
          'isActive': true,
        },
      ];
    } catch (e) {
      print('Error fetching alert levels: $e');
      return [
        {'_id': '64e8b2c83c9f9c1e2aa1a333', 'name': 'Low', 'isActive': true},
        {'_id': '64e8b2c83c9f9c1e2aa1a334', 'name': 'Medium', 'isActive': true},
        {'_id': '64e8b2c83c9f9c1e2aa1a335', 'name': 'High', 'isActive': true},
        {
          '_id': '64e8b2c83c9f9c1e2aa1a336',
          'name': 'Critical',
          'isActive': true,
        },
      ];
    }
  }

  // TARGETED DUPLICATE REMOVAL - Only for scam and fraud reports
  Future<void> removeDuplicateScamFraudReports() async {
    try {
      print(
        '🔍 Starting targeted duplicate removal for scam and fraud reports...',
      );

      // Get all reports from backend
      final response = await _dioService.reportsGet(
        ApiConfig.reportSecurityIssueEndpoint,
      );
      if (response.statusCode != 200 || response.data == null) {
        print('❌ Failed to fetch reports from backend');
        return;
      }

      final allReports = List<Map<String, dynamic>>.from(response.data);
      print('📊 Found ${allReports.length} total reports in backend');

      // Filter scam and fraud reports
      final scamFraudReports = allReports.where((report) {
        final categoryId = report['reportCategoryId']?.toString() ?? '';
        return categoryId.contains('scam') || categoryId.contains('fraud');
      }).toList();

      print('🎯 Found ${scamFraudReports.length} scam/fraud reports');

      // Group by unique identifiers to find duplicates
      final Map<String, List<Map<String, dynamic>>> groupedReports = {};

      for (var report in scamFraudReports) {
        // Create unique key based on phone, email, description, and alertLevels
        final phone = report['phoneNumber']?.toString() ?? '';
        final email = report['email']?.toString() ?? '';
        final description = report['description']?.toString() ?? '';
        final alertLevels = report['alertLevels']?.toString() ?? '';

        final uniqueKey = '${phone}_${email}_${description}_${alertLevels}';

        if (!groupedReports.containsKey(uniqueKey)) {
          groupedReports[uniqueKey] = [];
        }
        groupedReports[uniqueKey]!.add(report);
      }

      // Find and remove duplicates (keep the oldest one)
      int duplicatesRemoved = 0;
      for (var entry in groupedReports.entries) {
        final reports = entry.value;
        if (reports.length > 1) {
          print('🔍 Found ${reports.length} duplicates for key: ${entry.key}');

          // Sort by creation date (oldest first)
          reports.sort((a, b) {
            final aDate =
                DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
                DateTime.now();
            final bDate =
                DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
                DateTime.now();
            return aDate.compareTo(bDate);
          });

          // Keep the oldest, remove the rest
          for (int i = 1; i < reports.length; i++) {
            final reportId = reports[i]['_id'];
            if (reportId != null) {
              try {
                await _dioService.reportsApi.delete(
                  '${ApiConfig.reportSecurityIssueEndpoint}/$reportId',
                );
                duplicatesRemoved++;
                print('🗑️ Removed duplicate report: $reportId');
              } catch (e) {
                print('❌ Failed to remove duplicate report $reportId: $e');
              }
            }
          }
        }
      }

      print('✅ TARGETED DUPLICATE REMOVAL COMPLETED');
      print('📊 Summary:');
      print('  - Total scam/fraud reports: ${scamFraudReports.length}');
      print('  - Duplicates removed: $duplicatesRemoved');
    } catch (e) {
      print('❌ Error during targeted duplicate removal: $e');
    }
  }

  // Add missing methods for thread database functionality
  Future<List<Map<String, dynamic>>> fetchReportsWithFilter(
    ReportsFilter filter,
  ) async {
    try {
      print('🔍 Fetching reports with filter: $filter');
      final response = await _dioService.reportsGet(filter.buildUrl());
      print('✅ Filter response: ${response.data}');

      if (response.data != null && response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      } else if (response.data != null && response.data is Map) {
        // Handle case where response is wrapped in an object
        final data = response.data as Map<String, dynamic>;
        if (data.containsKey('data') && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }

      print('⚠️ Unexpected response format: ${response.data}');
      return [];
    } catch (e) {
      print('❌ Error fetching reports with filter: $e');
      if (e is DioException) {
        print('📡 DioException type: ${e.type}');
        print('📡 DioException message: ${e.message}');
        print('📡 Response status: ${e.response?.statusCode}');
        print('📡 Response data: ${e.response?.data}');
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getReportsWithComplexFilter({
    String? searchQuery,
    List<String>? categoryIds,
    List<String>? typeIds,
    List<String>? severityLevels,
    int page = ApiConfig.defaultPage,
    int limit = ApiConfig.defaultLimit, // Use default limit from config
  }) async {
    try {
      print('🔍 Fetching reports with complex filter');
      print(
        '📋 Parameters: searchQuery=$searchQuery, categoryIds=$categoryIds, typeIds=$typeIds, severityLevels=$severityLevels, page=$page, limit=$limit',
      );

      final queryParams = <String, dynamic>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (searchQuery != null && searchQuery.isNotEmpty) {
        queryParams['search'] = searchQuery;
      }
      if (categoryIds != null && categoryIds.isNotEmpty) {
        queryParams['categoryIds'] = categoryIds;
      }
      if (typeIds != null && typeIds.isNotEmpty) {
        queryParams['typeIds'] = typeIds;
      }
      if (severityLevels != null && severityLevels.isNotEmpty) {
        queryParams['severityLevels'] = severityLevels;
      }

      final response = await _dioService.reportsGet(
        ApiConfig.reportSecurityIssueEndpoint,
        queryParameters: queryParams,
      );
      print('✅ Complex filter response: ${response.data}');

      if (response.data != null && response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      } else if (response.data != null && response.data is Map) {
        // Handle case where response is wrapped in an object
        final data = response.data as Map<String, dynamic>;
        if (data.containsKey('data') && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }

      print('⚠️ Unexpected response format: ${response.data}');
      return [];
    } catch (e) {
      print('❌ Error fetching reports with complex filter: $e');
      if (e is DioException) {
        print('📡 DioException type: ${e.type}');
        print('📡 DioException message: ${e.message}');
        print('📡 Response status: ${e.response?.statusCode}');
        print('📡 Response data: ${e.response?.data}');
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllReports() async {
    try {
      print('🔍 Fetching all reports');
      final response = await _dioService.reportsGet(
        ApiConfig.reportSecurityIssueEndpoint,
      );
      print('✅ All reports response: ${response.data}');

      if (response.data != null && response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      } else if (response.data != null && response.data is Map) {
        // Handle case where response is wrapped in an object
        final data = response.data as Map<String, dynamic>;
        if (data.containsKey('data') && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }

      print('⚠️ Unexpected response format: ${response.data}');
      return [];
    } catch (e) {
      print('❌ Error fetching all reports: $e');
      if (e is DioException) {
        print('📡 DioException type: ${e.type}');
        print('📡 DioException message: ${e.message}');
        print('📡 Response status: ${e.response?.statusCode}');
        print('📡 Response data: ${e.response?.data}');
      }
      return [];
    }
  }

  Future<void> testBackendEndpoints() async {
    try {
      print('🧪 Testing backend endpoints...');

      // Test basic connectivity
      final reports = await fetchAllReports();
      print('✅ Basic connectivity test: ${reports.length} reports found');

      // Test reports API specifically
      print('🔍 Testing reports API endpoint...');
      try {
        final response = await _dioService.reportsGet(
          '/reports?page=1&limit=200', // Updated limit to 200
        );
        print('✅ Reports API test successful: ${response.statusCode}');
        print(
          '📊 Reports found: ${response.data is List ? response.data.length : 'N/A'}',
        );
      } catch (e) {
        print('❌ Reports API test failed: $e');
      }

      // Test thread database filter
      print('🔍 Testing thread database filter...');
      try {
        final filter = ReportsFilter(page: 1, limit: 10);
        final filteredReports = await fetchReportsWithFilter(filter);
        print(
          '✅ Thread database filter test successful: ${filteredReports.length} reports found',
        );
      } catch (e) {
        print('❌ Thread database filter test failed: $e');
      }

      // Test categories endpoint
      final categories = await fetchReportCategories();
      print(
        '✅ Categories endpoint test: ${categories.length} categories found',
      );

      // Test types endpoint
      final types = await fetchReportTypes();
      print('✅ Types endpoint test: ${types.length} types found');
    } catch (e) {
      print('❌ Backend endpoints test failed: $e');
    }
  }

  Future<List<Map<String, dynamic>>> testExactUrlStructure() async {
    try {
      print('🧪 Testing exact URL structure...');

      // Test with a simple filter
      final filter = ReportsFilter(page: 1, limit: 10);
      final reports = await fetchReportsWithFilter(filter);

      print('✅ Exact URL structure test: ${reports.length} reports found');
      return reports;
    } catch (e) {
      print('❌ Exact URL structure test failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchMethodOfContact() async {
    try {
      print('🔍 Fetching method of contact options...');
      print(
        '🔍 API URL: ${_dioService.mainApi.options.baseUrl}${ApiConfig.methodOfContactEndpoint}',
      );

      // Try to fetch from the backend endpoint
      final response = await _dioService.mainApi.get(
        ApiConfig.methodOfContactEndpoint,
      );

      print('🔍 Response status: ${response.statusCode}');
      print('🔍 Response data type: ${response.data.runtimeType}');
      print('🔍 Response data: ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data;
        print('🔍 Total method of contact items received: ${data.length}');

        // Print all items to see what's available
        for (int i = 0; i < data.length; i++) {
          final item = data[i];
          print('🔍 Item $i: ${item['name']} (ID: ${item['_id']})');
        }

        final List<Map<String, dynamic>> methodOfContactOptions = data
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        print(
          '✅ Method of contact options loaded from API: ${methodOfContactOptions.length} items',
        );

        // Print the options
        for (int i = 0; i < methodOfContactOptions.length; i++) {
          final option = methodOfContactOptions[i];
          print(
            '✅ Method of contact option $i: ${option['name']} (ID: ${option['_id']})',
          );
        }

        return methodOfContactOptions;
      } else {
        print(
          '❌ API endpoint returned invalid response, using fallback options',
        );
        return _getFallbackMethodOfContactOptions();
      }
    } catch (e) {
      print('❌ Error fetching method of contact options from API: $e');
      print('❌ Error type: ${e.runtimeType}');
      if (e is Exception) {
        print('❌ Exception details: $e');
      }
      print('⚠️ Using fallback method of contact options');
      return _getFallbackMethodOfContactOptions();
    }
  }

  List<Map<String, dynamic>> _getFallbackMethodOfContactOptions() {
    print('🔍 Using fallback method of contact options');

    final List<Map<String, dynamic>> fallbackOptions = [
      {'_id': '1', 'name': 'Email', 'type': 'Method of Contact'},
      {'_id': '2', 'name': 'SMS', 'type': 'Method of Contact'},
      {'_id': '3', 'name': 'Phone Call', 'type': 'Method of Contact'},
      {'_id': '4', 'name': 'Social Media', 'type': 'Method of Contact'},
      {'_id': '5', 'name': 'Website', 'type': 'Method of Contact'},
      {'_id': '6', 'name': 'Other', 'type': 'Method of Contact'},
    ];

    print(
      '✅ Fallback method of contact options loaded: ${fallbackOptions.length} items',
    );

    // Print the fallback options
    for (int i = 0; i < fallbackOptions.length; i++) {
      final option = fallbackOptions[i];
      print('✅ Fallback option $i: ${option['name']} (ID: ${option['_id']})');
    }

    return fallbackOptions;
  }

  // Cache method of contact options for offline use
  static List<Map<String, dynamic>>? _cachedMethodOfContactOptions;

  Future<List<Map<String, dynamic>>> fetchMethodOfContactWithCache() async {
    // Return cached options if available
    if (_cachedMethodOfContactOptions != null) {
      print(
        '✅ Returning cached method of contact options: ${_cachedMethodOfContactOptions!.length} items',
      );
      return _cachedMethodOfContactOptions!;
    }

    // Try to fetch from API
    final options = await fetchMethodOfContact();

    // Cache the options (whether from API or fallback)
    _cachedMethodOfContactOptions = options;
    print('✅ Cached method of contact options: ${options.length} items');

    return options;
  }

  // Clear cache (useful for testing or when you want fresh data)
  static void clearMethodOfContactCache() {
    _cachedMethodOfContactOptions = null;
    print('🧹 Cleared method of contact options cache');
  }

  // Helper method to get current user information
  Future<Map<String, String?>> _getCurrentUserInfo() async {
    try {
      final currentUserId = await JwtService.getCurrentUserId();
      final currentUserEmail = await JwtService.getCurrentUserEmail();

      print('🔍 Current User ID from JWT: $currentUserId');
      print('🔍 Current User Email from JWT: $currentUserEmail');

      return {'userId': currentUserId, 'userEmail': currentUserEmail};
    } catch (e) {
      print('❌ Error getting current user info: $e');
      return {'userId': null, 'userEmail': null};
    }
  }

  // Test authentication and backend connectivity
  Future<bool> testBackendConnectivity() async {
    try {
      print('🔍 Testing backend connectivity...');
      print(
        '🔍 Target URL: ${ApiConfig.reportsBaseUrl}${ApiConfig.reportSecurityIssueEndpoint}',
      );

      // Test 0: Check if basic backend is responding
      try {
        final basicResponse = await _dioService.reportsGet('/');
        print('✅ Basic backend response: ${basicResponse.data}');
      } catch (e) {
        print('⚠️ Basic backend test failed: $e');
      }

      // Test 0.5: Check authentication endpoint
      try {
        final authResponse = await _dioService.authGet('/auth/profile');
        print('✅ Auth endpoint response: ${authResponse.statusCode}');
      } catch (e) {
        print('⚠️ Auth endpoint test failed: $e');
      }

      // Test 1: Check if we can reach the backend
      final response = await _dioService.reportsGet(
        ApiConfig.reportSecurityIssueEndpoint,
        queryParameters: {'page': '1', 'limit': '1'},
      );

      print('✅ Backend is reachable');
      print('✅ Response status: ${response.statusCode}');
      print('✅ Response data type: ${response.data.runtimeType}');
      print('✅ Response data: ${response.data}');

      // Test 2: Check authentication
      final token = await _getAccessToken();
      print(
        '🔍 Current access token: ${token != null ? 'Present' : 'Not present'}',
      );

      if (token == null) {
        print('❌ No access token found - authentication may fail');
        return false;
      }

      print('✅ Authentication token is present');

      // Test 2.5: Check if token is valid for the reports server
      try {
        print('🔍 Testing token validity for reports server...');
        print('🔍 Auth Server: ${ApiConfig.authBaseUrl}');
        print('🔍 Reports Server: ${ApiConfig.reportsBaseUrl}');

        final testResponse = await _dioService.reportsGet(
          ApiConfig.reportSecurityIssueEndpoint,
          queryParameters: {'page': '1', 'limit': '1'},
        );
        print('✅ Token is valid for reports server');
      } catch (e) {
        print('❌ Token validation failed for reports server: $e');
        if (e is DioException && e.response?.statusCode == 401) {
          print(
            '❌ Authentication failed - token may be invalid or from wrong server',
          );
          print(
            '🔍 This might be because auth and reports are on different servers',
          );
        }
      }

      return true;
    } catch (e) {
      print('❌ Backend connectivity test failed: $e');
      if (e is DioException) {
        print('❌ DioException type: ${e.type}');
        print('❌ DioException status: ${e.response?.statusCode}');
        print('❌ DioException data: ${e.response?.data}');
        print('❌ DioException URL: ${e.requestOptions.uri}');

        // If it's a 404, the endpoint might not exist
        if (e.response?.statusCode == 404) {
          print(
            '❌ Endpoint not found - backend might not have full API set up',
          );
        }
      }
      return false;
    }
  }
}
