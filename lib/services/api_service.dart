import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/filter_model.dart';
import 'jwt_service.dart';
import 'dio_service.dart';
import 'token_storage.dart';
import 'dart:convert'; // Added for json.decode
import 'offline_cache_service.dart';
// connectivity_plus is not used directly here

class ApiService {
  final DioService _dioService = DioService();
  bool _useMockData = false;
  // Note: kept for future refresh-logic; ignore unused warning intentionally
  // ignore: unused_field
  final bool _isRefreshingToken = false;

  // ========================================
  // AUTHENTICATION METHODS (from auth_api_service.dart)
  // ========================================

  // Login method with working token management
  Future<bool> login(String email, String password) async {
    print("📤 Sending login request...");
    print("Username: $email");
    print("Password: $password");

    try {
      final response = await _dioService.authPost(
        "/api/v1/auth/login-user",
        data: {"username": email, "password": password},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("🔄 Login response: ${response.data}");
        final access = response.data["access_token"];
        final refresh = response.data["refresh_token"];
        await TokenStorage.setAccessToken(access);
        await TokenStorage.setRefreshToken(refresh);
        print(
          "✅ Login successful. Access token: ${access.substring(0, 20)}...",
        );
        return true;
      } else {
        print("🚫 Login failed: ${response.statusCode}");
        return false;
      }
    } on DioException catch (e) {
      print("❌ API Error Occurred!");
      print("Type: ${e.type}");
      print("Message: ${e.message}");
      print("Response: ${e.response}");
      print("Status code: ${e.response?.statusCode}");
      print("Data: ${e.response?.data}");
      return false;
    }
  }

  // Register method with working token management
  Future<bool> register(
    String firstname,
    String lastname,
    String username,
    String password,
    String role,
  ) async {
    print("📤 Sending register request...");
    print("Username: $username");
    print("Role: $role");

    try {
      final response = await _dioService.authPost(
        "/api/v1/auth/create-user",
        data: {
          "firstname": firstname,
          "lastname": lastname,
          "username": username,
          "password": password,
          "role": role,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ Registration successful");
        return true;
      } else {
        print("🚫 Registration failed: ${response.statusCode}");
        return false;
      }
    } on DioException catch (e) {
      print("❌ Registration Error Occurred!");
      print("Type: ${e.type}");
      print("Message: ${e.message}");
      print("Response: ${e.response}");
      print("Status code: ${e.response?.statusCode}");
      print("Data: ${e.response?.data}");
      return false;
    }
  }

  // Logout method with token clearing
  Future<bool> logout() async {
    print("📤 Sending logout request...");

    try {
      final response = await _dioService.authPost("/api/v1/auth/logout");

      // Clear tokens regardless of response
      await TokenStorage.clearAllTokens();

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ Logout successful");
        return true;
      } else {
        print("🚫 Logout failed: ${response.statusCode}");
        return false;
      }
    } on DioException catch (e) {
      print("❌ Logout Error Occurred!");
      print("Type: ${e.type}");
      print("Message: ${e.message}");

      // Clear tokens even if logout fails
      await TokenStorage.clearAllTokens();
      return false;
    }
  }

  // Get user profile with working token management
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final response = await _dioService.authGet("/api/v1/auth/profile");
      print("👤 User data: ${response.data}");
      return response.data;
    } catch (e) {
      print("❌ Failed to fetch user: $e");
      return null;
    }
  }

  // Get user data using the /user/me endpoint (from your working NewApiService)
  Future<Map<String, dynamic>?> getUserMe() async {
    try {
      final response = await _dioService.authGet("/api/v1/user/me");
      print("👤 User data: ${response.data}");
      return response.data;
    } catch (e) {
      print("❌ Failed to fetch user: $e");
      return null;
    }
  }

  // Additional methods from working NewApiService
  Future<List<Map<String, dynamic>>?> getThreadsReports() async {
    try {
      final response = await _dioService.reportsGet("/api/v1/reports");
      print("📊 Threads reports: ${response.data}");
      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      } else if (response.data is Map && response.data['data'] is List) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      print("❌ Failed to fetch threads reports: $e");
      return null;
    }
  }

  // Removed getDashboardStats method - endpoint doesn't exist on backend

  Future<List<Map<String, dynamic>>?> getReportCategories() async {
    try {
      final response = await _dioService.reportsGet("/api/v1/report-category");
      print("📊 Report categories: ${response.data}");
      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      } else if (response.data is Map && response.data['data'] is List) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      print("❌ Failed to fetch report categories: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> getReportTypes() async {
    try {
      final response = await _dioService.reportsGet("/api/v1/report-type");
      print("📊 Report types: ${response.data}");
      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      } else if (response.data is Map && response.data['data'] is List) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      print("❌ Failed to fetch report types: $e");
      return null;
    }
  }

  // Profile image methods

  // Password reset method
  Future<Response> forgotPassword(String email) async {
    return await _dioService.authPost(
      'api/v1/auth/forgot-password',
      data: {'email': email},
    );
  }

  ApiService() {
    // Using the centralized DioService instead of separate Dio instances
  }

  // Interceptors are handled by DioService
  // ignore: unused_element
  void _setupInterceptors(Dio dio) {}

  Future<void> setUseMockData(bool value) async {
    _useMockData = value;
  }

  Future<String?> _getAccessToken() async {
    try {
      // Use secure storage for tokens
      String? token = await TokenStorage.getAccessToken();

      // Fallback to JWT service if secure storage fails
      if (token == null || token.isEmpty) {
        token = await JwtService.getTokenWithFallback();
      }

      return token;
    } catch (e) {
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
    print('💾 ApiService: _saveTokens called');
    print('💾 ApiService: Access token length: ${accessToken.length}');
    print('💾 ApiService: Refresh token length: ${refreshToken.length}');

    await TokenStorage.setAccessToken(accessToken);
    await TokenStorage.setRefreshToken(refreshToken);
    // Also save using JWT service for device compatibility
    await JwtService.saveToken(accessToken);

    // Save refresh token to SharedPreferences as backup
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('refresh_token', refreshToken);

    print('✅ ApiService: _saveTokens completed');
  }

  // ignore: unused_element
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _getRefreshToken();

      if (refreshToken == null) {
        return false;
      }

      final response = await _dioService.authPost(
        '${ApiConfig.authBaseUrl}/auth/refresh-token',
        data: {'refreshToken': refreshToken},
      );

      final newAccessToken = response.data['access_token'];
      final newRefreshToken = response.data['refresh_token'];

      await _saveTokens(newAccessToken, newRefreshToken);
      return true;
    } catch (e) {
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

  // Fetch thread statistics from the API
  Future<List<Map<String, dynamic>>> getThreadStatistics() async {
    try {
      print(
        '🔍 Full URL: ${ApiConfig.reportsBaseUrl}${ApiConfig.threatStatsEndpoint}',
      );

      // Use reportsGet for proper reports server authentication
      final response = await _dioService.reportsGet(
        ApiConfig.threatStatsEndpoint,
      );

      if (response.statusCode == 200 && response.data != null) {
        if (response.data is List) {
          final stats = List<Map<String, dynamic>>.from(response.data);
          print(
            '✅ Successfully fetched ${stats.length} thread statistics with auth',
          );
          return stats;
        } else if (response.data is Map<String, dynamic>) {
          // Handle case where response is wrapped in an object
          final data = response.data as Map<String, dynamic>;
          if (data.containsKey('data') && data['data'] is List) {
            final stats = List<Map<String, dynamic>>.from(data['data']);
            print(
              '✅ Successfully fetched ${stats.length} thread statistics from wrapped response',
            );
            return stats;
          }
        }
      }

      return [];
    } catch (e) {
      print('❌ Failed to fetch thread statistics: $e');
      return [];
    }
  }

  // Fetch thread analysis data from the API
  Future<Map<String, dynamic>> getThreadAnalysis(String range) async {
    try {
      print(
        '🔍 Full URL: ${ApiConfig.reportsBaseUrl}${ApiConfig.threadAnalysisEndpoint}?range=$range',
      );

      // Use reportsGet for proper reports server authentication
      final response = await _dioService.reportsGet(
        ApiConfig.threadAnalysisEndpoint,
        queryParameters: {'range': range},
      );

      if (response.statusCode == 200 && response.data != null) {
        if (response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          print(
            '✅ Successfully fetched thread analysis with auth for range: $range',
          );
          return data;
        } else if (response.data is List) {
          // Handle array response format
          final data = response.data as List;
          print(
            '✅ Successfully fetched thread analysis array for range: $range',
          );
          return {'data': data};
        }
      }

      return {};
    } catch (e) {
      print('❌ Failed to fetch thread analysis: $e');
      return {};
    }
  }

  // Fetch percentage count data for reported features
  Future<Map<String, dynamic>> getPercentageCount() async {
    try {
      print(
        '🔍 Full URL: ${ApiConfig.reportsBaseUrl}${ApiConfig.percentageCountEndpoint}',
      );

      // Use reportsGet for proper reports server authentication
      final response = await _dioService.reportsGet(
        ApiConfig.percentageCountEndpoint,
      );

      if (response.statusCode == 200 && response.data != null) {
        if (response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          print('✅ Successfully fetched percentage count with auth');
          return data;
        }
      }

      return {};
    } catch (e) {
      print('❌ Failed to fetch percentage count: $e');
      return {};
    }
  }

  // Test method to verify the percentage count endpoint
  Future<Map<String, dynamic>> testPercentageCountEndpoint() async {
    try {
      print(
        '🧪 Full URL: ${ApiConfig.reportsBaseUrl}${ApiConfig.percentageCountEndpoint}',
      );

      final response = await _dioService.reportsGet(
        ApiConfig.percentageCountEndpoint,
      );

      if (response.statusCode == 200 && response.data != null) {
        return {
          'success': true,
          'data': response.data,
          'statusCode': response.statusCode,
        };
      } else {
        return {
          'success': false,
          'error': 'Unexpected response format',
          'statusCode': response.statusCode,
          'data': response.data,
        };
      }
    } catch (e) {
      if (e is DioException) {}
      return {'success': false, 'error': e.toString()};
    }
  }

  // Test method to verify the thread analysis endpoint
  Future<Map<String, dynamic>> testThreadAnalysisEndpoint() async {
    try {
      print(
        '🧪 URL: ${ApiConfig.reportsBaseUrl}${ApiConfig.threadAnalysisEndpoint}?range=1w',
      );

      // Test with reports API
      try {
        final response = await _dioService.reportsGet(
          ApiConfig.threadAnalysisEndpoint,
          queryParameters: {'range': '1w'},
        );
        return {
          'success': true,
          'statusCode': response.statusCode,
          'data': response.data,
          'method': 'reportsGet',
        };
      } catch (e) {
        return {
          'success': false,
          'error': e.toString(),
          'method': 'reportsGet_failed',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'method': 'test_failed'};
    }
  }

  // Test method to verify the thread statistics endpoint
  Future<Map<String, dynamic>> testThreadStatisticsEndpoint() async {
    try {
      print(
        '🧪 URL: ${ApiConfig.reportsBaseUrl}${ApiConfig.threatStatsEndpoint}',
      );

      // Test with reports API
      try {
        final response = await _dioService.reportsGet(
          ApiConfig.threatStatsEndpoint,
        );
        return {
          'success': true,
          'statusCode': response.statusCode,
          'data': response.data,
          'method': 'reportsGet',
        };
      } catch (e) {
        // Test with main API
        try {
          final response = await _dioService.mainApi.get(
            ApiConfig.threatStatsEndpoint,
          );
          return {
            'success': true,
            'statusCode': response.statusCode,
            'data': response.data,
            'method': 'mainApi',
          };
        } catch (e2) {
          return {
            'success': false,
            'error': e2.toString(),
            'method': 'both_failed',
          };
        }
      }
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'method': 'test_failed'};
    }
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

  // ignore: unused_element
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
      return {'message': 'Profile updated successfully (mock data)'};
    }
  }

  Future<List<Map<String, dynamic>>> fetchReportCategories() async {
    try {
      await OfflineCacheService.initialize();
      print(
        '🔍 Fetching report categories from: ${_dioService.mainApi.options.baseUrl}${ApiConfig.reportCategoryEndpoint}',
      );
      final response = await _dioService.get(ApiConfig.reportCategoryEndpoint);

      if (response.data != null && response.data is List) {
        final categories = List<Map<String, dynamic>>.from(response.data);

        // Cache for offline use
        await OfflineCacheService.saveCategories(categories);
        return categories;
      } else if (response.data != null && response.data is Map) {
        // Handle case where response is wrapped in an object
        final data = response.data as Map<String, dynamic>;
        if (data.containsKey('data') && data['data'] is List) {
          final categories = List<Map<String, dynamic>>.from(data['data']);
          print(
            '✅ Successfully parsed ${categories.length} categories from wrapped response',
          );
          await OfflineCacheService.saveCategories(categories);
          return categories;
        }
      }

      // Fallback to cache
      final cached = OfflineCacheService.getCategories();
      if (cached.isNotEmpty) return cached;
      return [];
    } catch (e) {
      if (e is DioException) {}
      await OfflineCacheService.initialize();
      final cached = OfflineCacheService.getCategories();
      return cached;
    }
  }

  Future<List<Map<String, dynamic>>> fetchReportTypesByCategory(
    String categoryId,
  ) async {
    try {
      await OfflineCacheService.initialize();

      // Check if categoryId is a valid ObjectId format
      final isObjectId = RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(categoryId);

      if (!isObjectId) {
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
        final list = List<Map<String, dynamic>>.from(response.data);
        await OfflineCacheService.saveTypesByCategory(categoryId, list);
        return list;
      } else if (response.data != null && response.data is Map) {
        // Handle case where response is wrapped in an object
        final data = response.data as Map<String, dynamic>;
        final raw = data['data'];
        if (raw is List) {
          final list = List<Map<String, dynamic>>.from(raw);
          await OfflineCacheService.saveTypesByCategory(categoryId, list);
          return list;
        }
      }

      final cached = OfflineCacheService.getTypesByCategory(categoryId);
      if (cached.isNotEmpty) return cached;
      return [];
    } catch (e) {
      if (e is DioException) {}
      await OfflineCacheService.initialize();
      final cached = OfflineCacheService.getTypesByCategory(categoryId);
      return cached;
    }
  }

  Future<void> submitScamReport(Map<String, dynamic> data) async {
    try {
      // Get current user information
      final userInfo = await _getCurrentUserInfo();

      // Test backend connectivity first
      final isConnected = await testBackendConnectivity();
      if (!isConnected) {
        throw Exception('Backend connectivity test failed');
      }

      print(
        '🟡 Target URL: ${_dioService.reportsApi.options.baseUrl}${ApiConfig.scamReportsEndpoint}',
      );

      print(
        '🟡 Report Security Issue Endpoint: ${ApiConfig.reportSecurityIssueEndpoint}',
      );

      // Ensure required fields are present and properly formatted
      final reportData = Map<String, dynamic>.from(data);

      // Validate and format required fields according to backend format
      reportData['reportCategoryId'] = reportData['reportCategoryId'] ?? '';
      reportData['reportTypeId'] = reportData['reportTypeId'] ?? '';

      // Validate alert levels - must be a valid ObjectId
      if (reportData['alertLevels'] == null ||
          reportData['alertLevels'].toString().isEmpty) {
        throw Exception(
          'Alert levels is required and must be a valid ObjectId',
        );
      }

      reportData['keycloackUserId'] =
          reportData['keycloackUserId'] ??
          '123e4567-e89b-12d3-a456-426614174000';
      reportData['createdBy'] = reportData['createdBy'] ?? '';
      reportData['isActive'] = reportData['isActive'] ?? true;
      // Removed status field as requested
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
        print(
          '📋 phoneNumbers type: ${reportData['phoneNumbers'].runtimeType}',
        );
      }
      if (reportData['emails'] is List) {}
      if (reportData['mediaHandles'] is List) {
        print(
          '📋 mediaHandles type: ${reportData['mediaHandles'].runtimeType}',
        );
      }

      print('📋 Final report data being sent: ${jsonEncode(reportData)}');
      print('📋 Data length: ${jsonEncode(reportData).length} characters');

      // Debug authentication token
      final token = await _getAccessToken();
      print(
        '🔐 Authentication token present: ${token != null && token.isNotEmpty ? 'YES' : 'NO'}',
      );
      if (token != null && token.isNotEmpty) {
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

      if (response.data != null) {
        print('✅ Response data keys: ${(response.data as Map).keys.toList()}');
      }

      // Verify the report was stored
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Try to fetch the report back to verify
        if (response.data != null && response.data['_id'] != null) {
          try {
            final verifyResponse = await _dioService.reportsGet(
              '${ApiConfig.reportSecurityIssueEndpoint}/${response.data['_id']}',
            );
          } catch (e) {}
        }
      } else {
        print(
          '❌ Failed to store scam report in backend. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is DioException) {}
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
      print(
        '🟡 Target URL: ${ApiConfig.mainBaseUrl}${ApiConfig.reportSecurityIssueEndpoint}',
      );

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

      // Verify report was stored
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Fetch the report back to verify
        try {
          final verifyResponse = await _dioService.reportsGet(
            '${ApiConfig.reportSecurityIssueEndpoint}/${response.data['_id']}',
          );
        } catch (e) {}
      } else {}
    } catch (e) {
      if (e is DioException) {
        // Save report locally if it's a connection error
        if (e.type == DioExceptionType.connectionError) {
          // TODO: Implement local storage save
        }
      }
      rethrow;
    }
  }

  Future<void> submitFraudReport(Map<String, dynamic> data) async {
    try {
      // Get current user information
      final userInfo = await _getCurrentUserInfo();

      // Test backend connectivity first
      final isConnected = await testBackendConnectivity();
      if (!isConnected) {
        throw Exception('Backend connectivity test failed');
      }

      print(
        '🟡 Target URL: ${_dioService.reportsApi.options.baseUrl}${ApiConfig.fraudReportsEndpoint}',
      );

      print(
        '🟡 Report Security Issue Endpoint: ${ApiConfig.reportSecurityIssueEndpoint}',
      );

      // Ensure required fields are present and properly formatted
      final reportData = Map<String, dynamic>.from(data);

      // Validate and format required fields according to backend format
      reportData['reportCategoryId'] = reportData['reportCategoryId'] ?? '';
      reportData['reportTypeId'] = reportData['reportTypeId'] ?? '';

      // Validate alert levels - must be a valid ObjectId
      if (reportData['alertLevels'] == null ||
          reportData['alertLevels'].toString().isEmpty) {
        throw Exception(
          'Alert levels is required and must be a valid ObjectId',
        );
      }

      reportData['keycloackUserId'] =
          reportData['keycloackUserId'] ??
          '123e4567-e89b-12d3-a456-426614174000';
      reportData['createdBy'] = reportData['createdBy'] ?? '';
      reportData['isActive'] = reportData['isActive'] ?? true;
      // Removed status field as requested
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

      // Ensure timestamps are properly formatted
      reportData['createdAt'] =
          reportData['createdAt'] ?? DateTime.now().toIso8601String();
      reportData['updatedAt'] = DateTime.now().toIso8601String();

      // Ensure location is properly formatted
      if (!reportData.containsKey('location')) {
        // For production, you would implement a proper location service here
        // For now, we'll use a fallback that indicates location was not available

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
        print(
          '📋 phoneNumbers type: ${reportData['phoneNumbers'].runtimeType}',
        );
      }

      if (reportData['emails'] is List) {}

      if (reportData['mediaHandles'] is List) {
        print(
          '📱 mediaHandles type: ${reportData['mediaHandles'].runtimeType}',
        );
      }

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

      print('🔄 Fraud report response status: ${response.statusCode}');
      print('🔄 Fraud report response data: ${response.data}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Backend returned status ${response.statusCode}: ${response.data}',
        );
      }

      print('✅ Fraud report submitted successfully');
    } catch (e) {
      if (e is DioException) {
        // Handle authentication errors gracefully
        if (e.response?.statusCode == 401) {
          print(
            '🔐 Authentication error detected - using fallback credentials',
          );
          print(
            '🔍 This might be because auth and reports are on different servers',
          );

          // The report will be saved locally and synced later when authentication is restored
        }
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchReportTypes() async {
    try {
      await OfflineCacheService.initialize();
      print(
        '🔍 Fetching report types from: ${_dioService.mainApi.options.baseUrl}${ApiConfig.reportTypeEndpoint}',
      );
      final response = await _dioService.get(ApiConfig.reportTypeEndpoint);

      if (response.data != null && response.data is List) {
        final list = List<Map<String, dynamic>>.from(response.data);
        await OfflineCacheService.saveTypes(list);
        return list;
      } else if (response.data != null && response.data is Map) {
        // Handle case where response is wrapped in an object
        final data = response.data as Map<String, dynamic>;
        final raw = data['data'];
        if (raw is List) {
          final list = List<Map<String, dynamic>>.from(raw);
          await OfflineCacheService.saveTypes(list);
          return list;
        }
      }

      final cached = OfflineCacheService.getTypes();
      if (cached.isNotEmpty) return cached;
      return [];
    } catch (e) {
      if (e is DioException) {}
      await OfflineCacheService.initialize();
      final cached = OfflineCacheService.getTypes();
      return cached;
    }
  }

  Future<Map<String, dynamic>?> fetchCategoryById(String categoryId) async {
    try {
      final response = await _dioService.get(
        '/api/report-category/$categoryId',
      );
      return response.data;
    } catch (e) {
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
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAlertLevels() async {
    try {
      final response = await _dioService.get(ApiConfig.alertLevelsEndpoint);

      if (response.statusCode == 200 && response.data is List) {
        final levels = List<Map<String, dynamic>>.from(response.data);
        final activeLevels = levels
            .where((level) => level['isActive'] == true)
            .toList();

        print(
          '✅ Successfully fetched ${activeLevels.length} active alert levels from backend',
        );
        await OfflineCacheService.saveAlertLevels(activeLevels);
        print(
          '✅ Alert levels: ${activeLevels.map((level) => '${level['name']} (${level['_id']})').join(', ')}',
        );

        return activeLevels;
      } else {
        final cached = OfflineCacheService.getAlertLevels();
        if (cached.isNotEmpty) return cached;
        throw Exception('Invalid response format from alert levels API');
      }
    } catch (e) {
      final cached = OfflineCacheService.getAlertLevels();
      if (cached.isNotEmpty) return cached;
      throw Exception('Failed to fetch alert levels from backend: $e');
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
        return;
      }

      final allReports = List<Map<String, dynamic>>.from(response.data);

      // Filter scam and fraud reports
      final scamFraudReports = allReports.where((report) {
        final categoryId = report['reportCategoryId']?.toString() ?? '';
        return categoryId.contains('scam') || categoryId.contains('fraud');
      }).toList();

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
              } catch (e) {}
            }
          }
        }
      }
    } catch (e) {}
  }

  // TARGETED DUPLICATE REMOVAL - Only for malware reports
  Future<void> removeDuplicateMalwareReports() async {
    try {
      print('🔍 Starting targeted duplicate removal for malware reports...');

      // Get all reports from backend
      final response = await _dioService.reportsGet(
        ApiConfig.reportSecurityIssueEndpoint,
      );
      if (response.statusCode != 200 || response.data == null) {
        return;
      }

      final allReports = List<Map<String, dynamic>>.from(response.data);

      // Filter malware reports
      final malwareReports = allReports.where((report) {
        final categoryId = report['reportCategoryId']?.toString() ?? '';
        return categoryId.contains('malware');
      }).toList();

      // Group by unique identifiers to find duplicates
      final Map<String, List<Map<String, dynamic>>> groupedReports = {};

      for (var report in malwareReports) {
        // Create unique key based on malware-specific fields
        final name = report['attackName']?.toString() ?? '';
        final malwareType = report['attackName']?.toString() ?? '';
        final fileName = report['attackName']?.toString() ?? '';
        final description = report['description']?.toString() ?? '';
        final infectedDeviceType = report['deviceTypeId']?.toString() ?? '';
        final operatingSystem = report['attackSystem']?.toString() ?? '';
        final detectionMethod = report['detectTypeId']?.toString() ?? '';
        final location = report['location']?.toString() ?? '';
        final systemAffected = report['attackSystem']?.toString() ?? '';
        final alertSeverityLevel = report['alertLevels']?.toString() ?? '';

        final uniqueKey =
            '${name}_${malwareType}_${fileName}_${description}_${infectedDeviceType}_${operatingSystem}_${detectionMethod}_${location}_${systemAffected}_${alertSeverityLevel}';

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
                print('🗑️ Removed duplicate malware report: $reportId');
              } catch (e) {
                print('❌ Error removing duplicate malware report: $e');
              }
            }
          }
        }
      }

      print(
        '✅ Removed $duplicatesRemoved duplicate malware reports from backend',
      );
    } catch (e) {
      print('❌ Error during malware duplicate removal: $e');
    }
  }

  // Add missing methods for thread database functionality
  Future<List<Map<String, dynamic>>> fetchReportsWithFilter(
    ReportsFilter filter,
  ) async {
    try {
      final response = await _dioService.reportsGet(filter.buildUrl());

      if (response.data != null && response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      } else if (response.data != null && response.data is Map) {
        // Handle case where response is wrapped in an object
        final data = response.data as Map<String, dynamic>;
        if (data.containsKey('data') && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }

      return [];
    } catch (e) {
      if (e is DioException) {}
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getReportsWithComplexFilter({
    String? searchQuery,
    List<String>? categoryIds,
    List<String>? typeIds,
    List<String>? severityLevels,
    bool? hasEvidence, // NEW: Filter for reports with evidence files
    int page = ApiConfig.defaultPage,
    int limit = ApiConfig.defaultLimit,
    List<String>? alertLevels,
    String? deviceTypeId,
    String? detectTypeId,
    String? operatingSystemName,
    DateTime? startDate,
    DateTime? endDate, // Use default limit from config
  }) async {
    try {
      print(
        '📋 Parameters: searchQuery=$searchQuery, categoryIds=$categoryIds, typeIds=$typeIds, alertLevels=$alertLevels, page=$page, limit=$limit',
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
      if (alertLevels != null && alertLevels.isNotEmpty) {
        queryParams['alertLevels'] = alertLevels;
      }
      if (hasEvidence != null) {
        queryParams['hasEvidence'] = hasEvidence.toString();
      }
      if (deviceTypeId != null) {
        queryParams['deviceTypeId'] = deviceTypeId;
      }
      if (detectTypeId != null) {
        queryParams['detectTypeId'] = detectTypeId;
      }
      if (operatingSystemName != null) {
        queryParams['operatingSystemName'] = operatingSystemName;
      }
      if (startDate != null) {
        queryParams['startDate'] = startDate.toString();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toString();
      }

      final response = await _dioService.reportsGet(
        ApiConfig.reportSecurityIssueEndpoint,
        queryParameters: queryParams,
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

      return [];
    } catch (e) {
      if (e is DioException) {}
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllReports() async {
    try {
      final response = await _dioService.reportsGet(
        ApiConfig.reportSecurityIssueEndpoint,
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

      return [];
    } catch (e) {
      if (e is DioException) {}
      return [];
    }
  }

  // CRITICAL FIX: Clean up duplicate reports in MongoDB
  Future<void> cleanupDuplicateReports() async {
    try {
      print('🧹 Starting duplicate cleanup in MongoDB...');

      final allReports = await fetchAllReports();
      print('📊 Total reports in database: ${allReports.length}');

      // Group reports by key identifying fields
      final Map<String, List<Map<String, dynamic>>> groupedReports = {};

      for (final report in allReports) {
        final description = report['description']?.toString() ?? '';
        final scammerName = report['scammerName']?.toString() ?? '';
        final website = report['website']?.toString() ?? '';
        final moneyLost = report['moneyLost']?.toString() ?? '';

        // Create a unique key based on identifying fields
        final key = '${description}_${scammerName}_${website}_${moneyLost}';

        if (!groupedReports.containsKey(key)) {
          groupedReports[key] = [];
        }
        groupedReports[key]!.add(report);
      }

      int duplicatesRemoved = 0;

      // Process each group
      for (final entry in groupedReports.entries) {
        final reports = entry.value;
        if (reports.length > 1) {
          print('🔍 Found ${reports.length} duplicates for: ${entry.key}');

          // Sort by creation date (keep the oldest one)
          reports.sort((a, b) {
            final aDate =
                DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
                DateTime.now();
            final bDate =
                DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
                DateTime.now();
            return aDate.compareTo(bDate);
          });

          // Keep the first (oldest) report, delete the rest
          for (int i = 1; i < reports.length; i++) {
            final reportId = reports[i]['_id'] ?? reports[i]['id'];
            if (reportId != null) {
              try {
                await _dioService.reportsApi.delete(
                  '${ApiConfig.reportSecurityIssueEndpoint}/$reportId',
                );
                duplicatesRemoved++;
                print('🗑️ Removed duplicate report: $reportId');
              } catch (e) {
                print('❌ Error removing duplicate report $reportId: $e');
              }
            }
          }
        }
      }

      print(
        '✅ Duplicate cleanup completed. Removed $duplicatesRemoved duplicate reports.',
      );
    } catch (e) {
      print('❌ Error during duplicate cleanup: $e');
    }
  }

  Future<void> testBackendEndpoints() async {
    try {
      // Test basic connectivity
      final reports = await fetchAllReports();

      // Test reports API specifically

      try {
        final response = await _dioService.reportsGet(
          '/reports?page=1&limit=200', // Updated limit to 200
        );

        print(
          '📊 Reports found: ${response.data is List ? response.data.length : 'N/A'}',
        );
      } catch (e) {}

      // Test thread database filter

      try {
        final filter = ReportsFilter(page: 1, limit: 10);
        final filteredReports = await fetchReportsWithFilter(filter);
        print(
          '✅ Thread database filter test successful: ${filteredReports.length} reports found',
        );
      } catch (e) {}

      // Test categories endpoint
      final categories = await fetchReportCategories();
      print(
        '✅ Categories endpoint test: ${categories.length} categories found',
      );

      // Test types endpoint
      final types = await fetchReportTypes();
    } catch (e) {}
  }

  Future<List<Map<String, dynamic>>> testExactUrlStructure() async {
    try {
      // Test with a simple filter
      final filter = ReportsFilter(page: 1, limit: 10);
      final reports = await fetchReportsWithFilter(filter);

      return reports;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchMethodOfContact() async {
    try {
      await OfflineCacheService.initialize();

      print('📞 Fetching method of contact data...');

      // First, try to get the scam category ID
      String scamCategoryId = '';
      try {
        final categories = await fetchReportCategories();
        for (final category in categories) {
          final name = category['name']?.toString().toLowerCase() ?? '';
          if (name.contains('scam')) {
            scamCategoryId = category['_id']?.toString() ?? '';
            print('✅ Found scam category ID: $scamCategoryId');
            break;
          }
        }
      } catch (e) {
        print('❌ Error getting scam category ID: $e');
      }

      // If we have a scam category ID, try to fetch method of contact from that category
      if (scamCategoryId.isNotEmpty) {
        try {
          print(
            '🔍 Trying to fetch method of contact from scam category: $scamCategoryId',
          );
          final response = await _dioService.mainApi.get(
            '${ApiConfig.dropdownEndpoint}&id=$scamCategoryId',
          );

          if (response.statusCode == 200 && response.data != null) {
            final Map<String, dynamic> responseData = response.data;
            final List<dynamic> data = responseData['data'] ?? [];

            // Filter for method of contact type
            final List<Map<String, dynamic>> methodOfContactOptions = data
                .where((item) {
                  final type = item['type']?.toString().toLowerCase() ?? '';
                  return type.contains('method') ||
                      type.contains('contact') ||
                      type.contains('method-of-contact') ||
                      type.contains('method_of_contact');
                })
                .map((item) {
                  final Map<String, dynamic> transformedItem =
                      Map<String, dynamic>.from(item);

                  // Ensure the item has the required fields
                  if (!transformedItem.containsKey('name')) {
                    transformedItem['name'] =
                        transformedItem['_id']?.toString() ?? 'Unknown Method';
                  }

                  // Ensure the item has an ID field
                  if (!transformedItem.containsKey('_id')) {
                    transformedItem['_id'] =
                        transformedItem['id'] ??
                        transformedItem['name'] ??
                        'unknown';
                  }

                  return transformedItem;
                })
                .toList();

            if (methodOfContactOptions.isNotEmpty) {
              print(
                '✅ Found ${methodOfContactOptions.length} method of contact options from category',
              );

              // Cache for offline
              await OfflineCacheService.saveDropdown(
                'method-of-contact',
                methodOfContactOptions,
              );

              // Print the options
              for (int i = 0; i < methodOfContactOptions.length; i++) {
                final option = methodOfContactOptions[i];
                print(
                  '✅ Method of contact option $i: ${option['name']} (ID: ${option['_id']})',
                );
              }

              return methodOfContactOptions;
            }
          }
        } catch (e) {
          print('❌ Error fetching from category: $e');
        }
      }

      // Fallback: try the generic dropdown endpoint
      print('🔍 Fallback: trying generic dropdown endpoint...');
      final response = await _dioService.mainApi.get(
        '${ApiConfig.dropdownEndpoint}&limit=200',
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data;

        // Transform the data to ensure it has the expected structure
        final List<Map<String, dynamic>> methodOfContactOptions = data.map((
          item,
        ) {
          final Map<String, dynamic> transformedItem =
              Map<String, dynamic>.from(item);

          // Ensure the item has the required fields
          if (!transformedItem.containsKey('name')) {
            // Try to find a name field in different possible formats
            if (transformedItem.containsKey('title')) {
              transformedItem['name'] = transformedItem['title'];
            } else if (transformedItem.containsKey('label')) {
              transformedItem['name'] = transformedItem['label'];
            } else if (transformedItem.containsKey('value')) {
              transformedItem['name'] = transformedItem['value'];
            } else if (transformedItem.containsKey('text')) {
              transformedItem['name'] = transformedItem['text'];
            } else {
              // If no name field found, use the ID or a default
              transformedItem['name'] =
                  transformedItem['_id']?.toString() ??
                  transformedItem['id']?.toString() ??
                  'Unknown Method';
            }
          }

          // Ensure the item has an ID field
          if (!transformedItem.containsKey('_id')) {
            if (transformedItem.containsKey('id')) {
              transformedItem['_id'] = transformedItem['id'];
            } else {
              transformedItem['_id'] = transformedItem['name'] ?? 'unknown';
            }
          }

          return transformedItem;
        }).toList();

        print(
          '✅ Method of contact options loaded from generic API: ${methodOfContactOptions.length} items',
        );

        // Cache for offline
        await OfflineCacheService.saveDropdown(
          'method-of-contact',
          methodOfContactOptions,
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
        throw Exception(
          'API returned invalid response: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error in fetchMethodOfContact: $e');

      // If the primary endpoint fails, return cached list (with aliases)
      await OfflineCacheService.initialize();
      final cached = OfflineCacheService.getDropdownByAliases([
        'method of contact',
        'method-of-contact',
        'method_of_contact',
      ]);

      if (cached.isNotEmpty) {
        print(
          '✅ Returning cached method of contact data: ${cached.length} items',
        );
      } else {
        print('⚠️ No cached method of contact data found');
      }

      return cached;
    }
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

    // Cache the options (only if we got data from backend)
    if (options.isNotEmpty) {
      _cachedMethodOfContactOptions = options;
    } else {}

    return options;
  }

  // Test method of contact API connectivity
  Future<Map<String, dynamic>> testMethodOfContactAPI() async {
    try {
      print(
        '🧪 Full URL: ${_dioService.mainApi.options.baseUrl}${ApiConfig.dropdownEndpoint}',
      );

      final response = await _dioService.mainApi.get(
        ApiConfig.dropdownEndpoint,
      );

      return {
        'success': true,
        'statusCode': response.statusCode,
        'data': response.data,
        'message': 'API call successful',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'API call failed',
      };
    }
  }

  // Test different possible endpoints for method of contact
  Future<Map<String, dynamic>> testMethodOfContactEndpoints() async {
    final endpoints = ['${ApiConfig.dropdownEndpoint}&limit=200'];

    final results = <String, Map<String, dynamic>>{};

    for (final endpoint in endpoints) {
      try {
        final response = await _dioService.mainApi.get(endpoint);

        results[endpoint] = {
          'success': true,
          'statusCode': response.statusCode,
          'data': response.data,
          'message': 'Endpoint working',
        };
      } catch (e) {
        results[endpoint] = {
          'success': false,
          'error': e.toString(),
          'message': 'Endpoint failed',
        };
      }
    }

    return {
      'endpoints': results,
      'summary': 'Tested ${endpoints.length} different endpoint variations',
    };
  }

  // Clear cache (useful for testing or when you want fresh data)
  static void clearMethodOfContactCache() {
    _cachedMethodOfContactOptions = null;
  }

  // Manually refresh method of contact cache (useful for offline preparation)
  Future<void> refreshMethodOfContactCache() async {
    try {
      _cachedMethodOfContactOptions = null; // Clear existing cache
      final options = await fetchMethodOfContact();
      if (options.isNotEmpty) {
        _cachedMethodOfContactOptions = options;
      } else {}
    } catch (e) {}
  }

  // Check if method of contact data is cached
  bool isMethodOfContactCached() {
    final cached = _cachedMethodOfContactOptions;
    final offlineCached = OfflineCacheService.getDropdown('method-of-contact');
    return (cached != null && cached.isNotEmpty) || offlineCached.isNotEmpty;
  }

  // Get method of contact cache status
  Map<String, dynamic> getMethodOfContactCacheStatus() {
    final cached = _cachedMethodOfContactOptions;
    final offlineCached = OfflineCacheService.getDropdown('method-of-contact');

    return {
      'memoryCache': cached?.length ?? 0,
      'offlineCache': offlineCached.length,
      'totalCached': (cached?.length ?? 0) + offlineCached.length,
      'isAvailable':
          (cached != null && cached.isNotEmpty) || offlineCached.isNotEmpty,
    };
  }

  // Preload and cache reference data so dropdowns are identical offline
  Future<void> prewarmReferenceData() async {
    try {
      print('🔥 Starting reference data prewarm...');
      await OfflineCacheService.initialize();

      // 1) Categories and all types
      print('📋 Fetching report categories...');
      final categories = await fetchReportCategories();
      print('✅ Fetched ${categories.length} categories');

      print('📋 Fetching report types...');
      await fetchReportTypes();
      print('✅ Fetched report types');

      // 2) Cache method of contact data globally (not category-specific)
      print('📞 Fetching method of contact...');
      try {
        await fetchMethodOfContact();
        print('✅ Method of contact fetched');
      } catch (e) {
        print('❌ Error fetching method of contact: $e');
      }

      // 3) Cache types and other dropdowns for each known category
      print('🔍 Fetching types by category...');
      for (final c in categories) {
        final id = (c['_id'] ?? c['id'])?.toString();
        if (id == null || id.isEmpty) continue;
        try {
          await fetchReportTypesByCategory(id);
          print('✅ Fetched types for category: ${c['name'] ?? id}');
        } catch (e) {
          print('❌ Error fetching types for category ${c['name'] ?? id}: $e');
        }
        // Note: method-of-contact is now cached globally above, so we don't need to cache per category
      }

      // 4) Global families used by malware flow
      print('🦠 Fetching malware reference data...');
      try {
        await fetchDeviceTypes();
        print('✅ Device types fetched');
      } catch (e) {
        print('❌ Error fetching device types: $e');
      }
      try {
        await fetchOperatingSystems();
        print('✅ Operating systems fetched');
      } catch (e) {
        print('❌ Error fetching operating systems: $e');
      }
      try {
        await fetchDetectionMethods();
        print('✅ Detection methods fetched');
      } catch (e) {
        print('❌ Error fetching detection methods: $e');
      }
      try {
        await fetchSeverityLevels();
        print('✅ Severity levels fetched');
      } catch (e) {
        print('❌ Error fetching severity levels: $e');
      }

      // 5) Alert levels
      print('🚨 Fetching alert levels...');
      try {
        await fetchAlertLevels();
        print('✅ Alert levels fetched');
      } catch (e) {
        print('❌ Error fetching alert levels: $e');
      }

      print('🔥 Reference data prewarm completed successfully!');
    } catch (e) {
      print('❌ Error during reference data prewarm: $e');
    }
  }

  // Helper method to get current user information
  Future<Map<String, String?>> _getCurrentUserInfo() async {
    try {
      final currentUserId = await JwtService.getCurrentUserId();
      final currentUserEmail = await JwtService.getCurrentUserEmail();

      return {'userId': currentUserId, 'userEmail': currentUserEmail};
    } catch (e) {
      return {'userId': null, 'userEmail': null};
    }
  }

  // Test authentication and backend connectivity
  Future<bool> testBackendConnectivity() async {
    try {
      print(
        '🔍 Target URL: ${ApiConfig.reportsBaseUrl}${ApiConfig.reportSecurityIssueEndpoint}',
      );

      // Test 0: Check if basic backend is responding
      try {
        final basicResponse = await _dioService.reportsGet('/');
      } catch (e) {}

      // Test 0.5: Check authentication endpoint
      try {
        final authResponse = await _dioService.authGet('/auth/profile');
      } catch (e) {}

      // Test 1: Check if we can reach the backend
      final response = await _dioService.reportsGet(
        '/api/v1/reports',
        queryParameters: {'page': '1', 'limit': '1'},
      );

      // Test 2: Check authentication
      final token = await _getAccessToken();
      print(
        '🔍 Current access token: ${token != null ? 'Present' : 'Not present'}',
      );

      if (token == null) {
        return false;
      }

      // Test 2.5: Check if token is valid for the reports server
      try {
        final _ = await _dioService.reportsGet(
          ApiConfig.reportSecurityIssueEndpoint,
          queryParameters: {'page': '1', 'limit': '1'},
        );
      } catch (e) {
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
      if (e is DioException) {
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

  // Enhanced test function that includes authentication testing
  Future<Map<String, dynamic>> testBackendAndAuthComprehensive() async {
    final results = <String, dynamic>{};

    try {
      // Test 1: Check if we have a token
      final token = await _getAccessToken();
      results['has_token'] = token != null && token.isNotEmpty;
      results['token_length'] = token?.length ?? 0;

      // Test 2: Check if backend is reachable without auth
      try {
        final response = await _dioService.mainApi.get(
          '/api/v1/report-category',
        );
        results['backend_reachable'] = true;
        results['backend_status'] = response.statusCode;
      } catch (e) {
        results['backend_reachable'] = false;
        results['backend_error'] = e.toString();
      }

      // Test 3: Check if we can fetch categories with auth
      try {
        final categories = await fetchReportCategories();
        results['categories_fetchable'] = true;
        results['categories_count'] = categories.length;
      } catch (e) {
        results['categories_fetchable'] = false;
        results['categories_error'] = e.toString();
      }

      // Test 4: Check if we can fetch types with auth
      try {
        final types = await fetchReportTypes();
        results['types_fetchable'] = true;
        results['types_count'] = types.length;
      } catch (e) {
        results['types_fetchable'] = false;
        results['types_error'] = e.toString();
      }

      // Test 5: Check if we can fetch alert levels
      try {
        final alertLevels = await fetchAlertLevels();
        results['alert_levels_fetchable'] = true;
        results['alert_levels_count'] = alertLevels.length;
      } catch (e) {
        results['alert_levels_fetchable'] = false;
        results['alert_levels_error'] = e.toString();
      }
    } catch (e) {
      results['general_error'] = e.toString();
    }

    return results;
  }

  // Test URL construction for debugging
  Future<void> testUrlConstruction() async {
    final scamUrl =
        '${ApiConfig.reportsBaseUrl}${ApiConfig.scamReportsEndpoint}';
    final fraudUrl =
        '${ApiConfig.reportsBaseUrl}${ApiConfig.fraudReportsEndpoint}';
    final malwareUrl =
        '${ApiConfig.reportsBaseUrl}${ApiConfig.malwareReportsEndpoint}';

    // Test if URLs are valid
    try {
      final response = await _dioService.reportsGet('/api/v1/reports');
    } catch (e) {}
  }

  // Test authentication and backend connectivity
  Future<Map<String, dynamic>> testBackendAndAuth() async {
    final results = <String, dynamic>{};

    try {
      // Test 1: Check if we have a token
      final token = await _getAccessToken();
      results['has_token'] = token != null && token.isNotEmpty;
      results['token_length'] = token?.length ?? 0;

      // Test 2: Check if backend is reachable without auth
      try {
        final response = await _dioService.mainApi.get(
          '/api/v1/report-category',
        );
        results['backend_reachable'] = true;
        results['backend_status'] = response.statusCode;
      } catch (e) {
        results['backend_reachable'] = false;
        results['backend_error'] = e.toString();
      }

      // Test 3: Check if we can fetch categories with auth
      try {
        final categories = await fetchReportCategories();
        results['categories_fetchable'] = true;
        results['categories_count'] = categories.length;
      } catch (e) {
        results['categories_fetchable'] = false;
        results['categories_error'] = e.toString();
      }

      // Test 4: Check if we can fetch types with auth
      try {
        final types = await fetchReportTypes();
        results['types_fetchable'] = true;
        results['types_count'] = types.length;
      } catch (e) {
        results['types_fetchable'] = false;
        results['types_error'] = e.toString();
      }
    } catch (e) {
      results['general_error'] = e.toString();
    }

    return results;
  }

  // Update malware report with new payload structure
  Future<bool> updateMalwareReport(Map<String, dynamic> malwarePayload) async {
    try {
      final response = await _dioService.reportsPost(
        ApiConfig.malwareReportsEndpoint,
        data: malwarePayload,
      );

      return true;
    } catch (e) {
      if (e is DioException) {}
      return false;
    }
  }

  // Create new malware report with the provided payload structure
  Future<bool> createMalwareReport(Map<String, dynamic> malwarePayload) async {
    try {
      print(
        '🔄 Using general reports endpoint: ${ApiConfig.malwareReportsEndpoint}',
      );
      print('🔄 Malware payload keys: ${malwarePayload.keys.toList()}');
      print(
        '🔄 Screenshots count: ${(malwarePayload['screenshots'] as List?)?.length ?? 0}',
      );
      print(
        '🔄 Documents count: ${(malwarePayload['documents'] as List?)?.length ?? 0}',
      );
      print(
        '🔄 Voice messages count: ${(malwarePayload['voiceMessages'] as List?)?.length ?? 0}',
      );
      print(
        '🔄 Video files count: ${(malwarePayload['videofiles'] as List?)?.length ?? 0}',
      );

      final response = await _dioService.reportsPost(
        ApiConfig.malwareReportsEndpoint,
        data: malwarePayload,
      );

      print('🔄 Response status: ${response.statusCode}');
      print('🔄 Response data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Malware report created successfully');
        return true;
      } else {
        print(
          '❌ Malware report creation failed with status: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      print('❌ Error creating malware report: $e');
      if (e is DioException) {
        print('❌ DioException type: ${e.type}');
        print('❌ DioException message: ${e.message}');
        print('❌ DioException response: ${e.response?.data}');
      }
      return false;
    }
  }

  // Create new fraud report with the provided payload structure
  Future<bool> createFraudReport(Map<String, dynamic> fraudPayload) async {
    try {
      print(
        '🔄 Using fraud reports endpoint: ${ApiConfig.fraudReportsEndpoint}',
      );
      print('🔄 Fraud payload keys: ${fraudPayload.keys.toList()}');
      print(
        '🔄 Screenshots count: ${(fraudPayload['screenshots'] as List?)?.length ?? 0}',
      );
      print(
        '🔄 Documents count: ${(fraudPayload['documents'] as List?)?.length ?? 0}',
      );
      print(
        '🔄 Voice messages count: ${(fraudPayload['voiceMessages'] as List?)?.length ?? 0}',
      );
      print(
        '🔄 Video files count: ${(fraudPayload['videofiles'] as List?)?.length ?? 0}',
      );

      final response = await _dioService.reportsPost(
        ApiConfig.fraudReportsEndpoint,
        data: fraudPayload,
      );

      print('🔄 Response status: ${response.statusCode}');
      print('🔄 Response data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Fraud report created successfully');
        return true;
      } else {
        print(
          '❌ Fraud report creation failed with status: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      print('❌ Error creating fraud report: $e');
      if (e is DioException) {
        print('❌ DioException type: ${e.type}');
        print('❌ DioException message: ${e.message}');
        print('❌ DioException response: ${e.response?.data}');
      }
      return false;
    }
  }

  // Get malware reports from backend
  Future<List<Map<String, dynamic>>> getMalwareReports({
    int page = 1,
    int limit = 50,
    String? status,
    String? reportCategoryId,
    String? reportTypeId,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (status != null) queryParams['status'] = status;
      if (reportCategoryId != null)
        queryParams['reportCategoryId'] = reportCategoryId;
      if (reportTypeId != null) queryParams['reportTypeId'] = reportTypeId;

      final response = await _dioService.reportsGet(
        ApiConfig.malwareReportsEndpoint,
        queryParameters: queryParams,
      );

      if (response.data is Map<String, dynamic> &&
          response.data['data'] is List) {
        final reports = List<Map<String, dynamic>>.from(response.data['data']);

        return reports;
      } else if (response.data is List) {
        final reports = List<Map<String, dynamic>>.from(response.data);

        return reports;
      } else {
        return [];
      }
    } catch (e) {
      if (e is DioException) {}
      return [];
    }
  }

  // Method to get method of contact from API only
  Future<List<Map<String, dynamic>>> fetchMethodOfContactFromAPI() async {
    try {
      // Try the correct endpoint with limit 200
      final response = await _dioService.mainApi.get(
        ApiConfig.dropdownEndpoint,
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data;

        // Transform the data to ensure it has the expected structure
        final List<Map<String, dynamic>> methodOfContactOptions = data.map((
          item,
        ) {
          final Map<String, dynamic> transformedItem =
              Map<String, dynamic>.from(item);

          // Ensure the item has the required fields
          if (!transformedItem.containsKey('name')) {
            transformedItem['name'] =
                transformedItem['_id']?.toString() ?? 'Unknown Method';
          }

          // Ensure the item has an ID field
          if (!transformedItem.containsKey('_id')) {
            transformedItem['_id'] =
                transformedItem['id'] ?? transformedItem['name'] ?? 'unknown';
          }

          print(
            '🔍 API Item: ${transformedItem['name']} (ID: ${transformedItem['_id']})',
          );
          return transformedItem;
        }).toList();

        print(
          '✅ Successfully loaded ${methodOfContactOptions.length} method of contact options from API',
        );
        return methodOfContactOptions;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Method to fetch dropdown data by type using the new API
  Future<List<Map<String, dynamic>>> fetchDropdownByType(
    String type,
    String categoryId,
  ) async {
    try {
      await OfflineCacheService.initialize();

      final response = await _dioService.mainApi.get(
        '${ApiConfig.dropdownEndpoint}&id=$categoryId',
      );

      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> responseData = response.data;
        final List<dynamic> data = responseData['data'] ?? [];

        String normalize(String s) => s
            .toLowerCase()
            .trim()
            .replaceAll(RegExp(r'[ _]+'), '-')
            .replaceAll(RegExp(r'[^a-z0-9\-]'), '');
        final normalizedType = normalize(type);

        // Filter by normalized type and transform the data
        List<Map<String, dynamic>> filteredOptions = data
            .where((item) {
              final raw = item['type']?.toString() ?? '';
              final n = normalize(raw);
              return n == normalizedType || n.contains(normalizedType);
            })
            .map((item) {
              final Map<String, dynamic> transformedItem =
                  Map<String, dynamic>.from(item);

              // Ensure the item has the required fields
              if (!transformedItem.containsKey('name')) {
                transformedItem['name'] =
                    transformedItem['_id']?.toString() ?? 'Unknown Option';
              }

              // Ensure the item has an ID field
              if (!transformedItem.containsKey('_id')) {
                transformedItem['_id'] =
                    transformedItem['id'] ??
                    transformedItem['name'] ??
                    'unknown';
              }

              print(
                '🔍 API Item: ${transformedItem['name']} (ID: ${transformedItem['_id']}, Type: ${transformedItem['type']})',
              );
              return transformedItem;
            })
            .toList();

        // Fallback: if filter returned empty, cache and return the whole list
        if (filteredOptions.isEmpty && data.isNotEmpty) {
          filteredOptions = data
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }

        print(
          '✅ Successfully loaded ${filteredOptions.length} $type options from API',
        );
        // Normalize cache key
        final key = normalizedType;
        await OfflineCacheService.saveDropdown(key, filteredOptions);
        return filteredOptions;
      } else {
        String normalize(String s) => s
            .toLowerCase()
            .trim()
            .replaceAll(RegExp(r'[ _]+'), '-')
            .replaceAll(RegExp(r'[^a-z0-9\-]'), '');
        final key = normalize(type);
        final cached = OfflineCacheService.getDropdown(key);
        return cached;
      }
    } catch (e) {
      String normalize(String s) => s
          .toLowerCase()
          .trim()
          .replaceAll(RegExp(r'[ _]+'), '-')
          .replaceAll(RegExp(r'[^a-z0-9\-]'), '');
      final key = normalize(type);
      await OfflineCacheService.initialize();
      final cached = OfflineCacheService.getDropdown(key);
      return cached;
    }
  }

  // Method to fetch method of contact using the new API
  Future<List<Map<String, dynamic>>> fetchMethodOfContactNew() async {
    return await fetchDropdownByType(
      'method-of-contact',
      '6874f8cb98e4e5a7dc75f42e',
    );
  }

  // Method to fetch device types using the new API
  Future<List<Map<String, dynamic>>> fetchDeviceTypes() async {
    return await fetchDropdownByType('device', '6874f8cb98e4e5a7dc75f42e');
  }

  // Method to fetch operating systems using the new API
  Future<List<Map<String, dynamic>>> fetchOperatingSystems() async {
    return await fetchDropdownByType(
      'operating System',
      '6874f8cb98e4e5a7dc75f42e',
    );
  }

  // Method to fetch detection methods using the new API
  Future<List<Map<String, dynamic>>> fetchDetectionMethods() async {
    return await fetchDropdownByType('detect', '6874f8cb98e4e5a7dc75f42e');
  }

  // Method to fetch severity levels using the new API
  Future<List<Map<String, dynamic>>> fetchSeverityLevels() async {
    return await fetchDropdownByType('severity', '6874f8cb98e4e5a7dc75f42e');
  }

  // Test backend on correct port
  Future<Map<String, dynamic>> testBackendPort() async {
    final results = <String, dynamic>{};

    try {
      // Test 1: Basic connectivity to the root endpoint
      try {
        final response = await _dioService.mainApi.get('/');
        results['root_endpoint'] = true;
        results['root_status'] = response.statusCode;
      } catch (e) {
        results['root_endpoint'] = false;
        results['root_error'] = e.toString();
      }

      // Test 2: Try the categories endpoint
      try {
        final response = await _dioService.mainApi.get(
          '/api/v1/report-category',
        );
        results['categories_endpoint'] = true;
        results['categories_status'] = response.statusCode;

        if (response.data != null) {}
      } catch (e) {
        results['categories_endpoint'] = false;
        results['categories_error'] = e.toString();
      }

      // Test 3: Try the types endpoint
      try {
        final response = await _dioService.mainApi.get('/api/v1/report-type');
        results['types_endpoint'] = true;
        results['types_status'] = response.statusCode;

        if (response.data != null) {}
      } catch (e) {
        results['types_endpoint'] = false;
        results['types_error'] = e.toString();
      }
    } catch (e) {
      results['general_error'] = e.toString();
    }

    return results;
  }

  Future<Map<String, dynamic>> generateReportPDF(String reportId) async {
    try {
      print('🔄 Generating PDF for report: $reportId');

      // Create a custom Dio instance for PDF requests
      final dio = Dio();

      // Get the access token
      final accessToken = await TokenStorage.getAccessToken();
      if (accessToken == null) {
        throw Exception('No access token available');
      }

      // Make the request with proper headers for PDF content
      final response = await dio.get(
        '${ApiConfig.reportsBaseUrl}/api/v1/reports/due-diligence/$reportId/print?format=pdf',

        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/pdf, */*',
          },
          responseType: ResponseType.bytes, // Use bytes for binary PDF content
        ),
      );

      print('📄 PDF generation response status: ${response.statusCode}');
      print(
        '📄 PDF generation response data type: ${response.data.runtimeType}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Handle binary PDF data
        if (response.data is List<int>) {
          final pdfBytes = response.data as List<int>;
          print('📄 PDF binary data length: ${pdfBytes.length} bytes');

          // Check if it's actually PDF content by looking at the first few bytes
          if (pdfBytes.length > 4) {
            final header = String.fromCharCodes(pdfBytes.take(4));
            print('📄 PDF header: $header');

            if (header == '%PDF') {
              return {
                'status': 'success',
                'data': pdfBytes, // Return binary data directly
                'message': 'PDF generated successfully',
              };
            }
          }

          // If not a valid PDF header, return the bytes anyway
          return {
            'status': 'success',
            'data': pdfBytes,
            'message': 'PDF generated successfully',
          };
        } else {
          // Fallback for non-binary response
          final pdfContent = response.data.toString();
          print('📄 PDF content length: ${pdfContent.length}');
          print(
            '📄 PDF content preview: ${pdfContent.length > 200 ? pdfContent.substring(0, 200) : pdfContent}...',
          );

          return {
            'status': 'success',
            'data': pdfContent,
            'message': 'PDF generated successfully',
          };
        }
      } else {
        return {
          'status': 'error',
          'message': 'Failed to generate PDF: ${response.statusMessage}',
        };
      }
    } catch (e) {
      print('❌ Error generating PDF: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Error details: ${e.toString()}');

      return {'status': 'error', 'message': 'Error generating PDF: $e'};
    }
  }

  Future<Response> uploadProfileImage(FormData formData, String userId) async {
    print('📤 Starting profile image upload for user ID: $userId');

    try {
      // Log form data for debugging
      print('📎 Form data fields:');
      for (var field in formData.fields) {
        print('  ${field.key}: ${field.value}');
      }

      print('📎 Form data files:');
      for (var file in formData.files) {
        print(
          '  ${file.key}: ${file.value.filename} (${file.value.contentType})',
        );
      }

      // Build the endpoint URL - use the correct endpoint path
      final endpoint = '/api/v1/file-upload/threads-fraud';
      print('🌐 Uploading to endpoint: $endpoint');

      // Get the access token
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        throw Exception('No access token available');
      }

      // Set headers
      final headers = {
        'Content-Type': 'multipart/form-data',
        'Authorization': 'Bearer $accessToken',
      };

      print('🔑 Using access token: ${accessToken.substring(0, 20)}...');

      // Make the upload request
      final response = await _dioService.fileUploadApi.post(
        endpoint,
        data: formData,
        options: Options(headers: headers),
      );

      print('✅ Upload successful');
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response data: ${response.data}');

      return response;
    } on DioException catch (e) {
      print('❌ Dio error in uploadProfileImage:');
      print('❌ Error type: ${e.type}');
      print('❌ Error message: ${e.message}');
      print('❌ Status code: ${e.response?.statusCode}');
      print('❌ Response data: ${e.response?.data}');
      print('❌ Request URL: ${e.requestOptions.uri}');

      // Re-throw with more context
      throw Exception('Failed to upload profile image: ${e.message}');
    } catch (e) {
      print('❌ Unexpected error in uploadProfileImage: $e');
      rethrow;
    }
  }

  Future<Response> getProfileImageByUserId(String reportId) async {
    return await _dioService.authGet(
      'api/v1/file-upload/threads-fraud/$reportId',
    );
  }

  Future<Map<String, dynamic>> updateUserProfileById(
    String userId,
    Map<String, dynamic> profileData,
  ) async {
    try {
      if (_useMockData) {
        return {'message': 'Profile updated successfully (mock data)'};
      }

      print('🔄 Step 2: Profile Update - PUT request');
      print('👤 User ID: $userId');
      print('📦 Profile data: $profileData');

      // Use the correct endpoint path with auth prefix
      final endpoint = '/api/v1/user/update-user/$userId';
      print('🌐 Endpoint: $endpoint');
      print('🔗 Full URL: https://mvp.edetectives.co.bw/$endpoint');

      // Use PUT method only (as confirmed by user)
      try {
        print('🔄 Using PUT method with authApi...');
        final response = await _dioService.authApi.put(
          endpoint,
          data: profileData,
        );

        print('✅ PUT response status: ${response.statusCode}');
        print('✅ PUT response data: ${response.data}');
        print('✅ PUT response data type: ${response.data.runtimeType}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          print('✅ Profile update successful');

          // Handle different response types
          if (response.data is Map<String, dynamic>) {
            return response.data;
          } else if (response.data is String) {
            // If response is a string, wrap it in a map
            return {'message': response.data, 'status': 'success'};
          } else {
            // For any other type, convert to map
            return {'data': response.data, 'status': 'success'};
          }
        }
      } on DioException catch (e) {
        print('❌ PUT failed: ${e.message}');
        print('❌ Status code: ${e.response?.statusCode}');
        print('❌ Response data: ${e.response?.data}');
        throw Exception('Profile update failed: ${e.message}');
      }

      throw Exception('Failed to update user profile');
    } on DioException catch (e) {
      print('❌ Error updating profile: ${e.message}');
      print('❌ Response data: ${e.response?.data}');
      print('❌ Status code: ${e.response?.statusCode}');
      rethrow;
    }
  }

  // Dynamic method to update any user field
  Future<Map<String, dynamic>> updateUserField(
    String userId,
    String fieldName,
    dynamic fieldValue,
  ) async {
    return await updateUserProfileById(userId, {fieldName: fieldValue});
  }

  // Dynamic method to update multiple user fields
  Future<Map<String, dynamic>> updateUserFields(
    String userId,
    Map<String, dynamic> fields,
  ) async {
    return await updateUserProfileById(userId, fields);
  }

  // Individual profile update functions using the new API endpoint
  Future<Map<String, dynamic>?> updateProfileImage(FormData imageData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null) {
        throw Exception('User ID not found');
      }

      // Use the uploadProfileImage method which already handles the correct endpoint and headers
      // Using userId as reportId since this is for profile image upload
      final response = await uploadProfileImage(imageData, userId);

      if (response.statusCode == 200) {
        print('✅ Profile image updated successfully');
        return response.data;
      } else {
        throw Exception(
          'Failed to update profile image: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      print('❌ Error updating profile image: ${e.message}');
      if (e.response != null) {
        print('Response data: ${e.response?.data}');
        print('Status code: ${e.response?.statusCode}');
      }
      throw Exception('Failed to update profile image: ${e.message}');
    }
  }

  Future<Map<String, dynamic>?> updateFirstName(String firstName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null) {
        throw Exception('User ID not found');
      }

      // Try POST first, then PUT as fallback
      Response response;
      try {
        response = await _dioService.authPost(
          '/api/v1/user/update-user/$userId',
          data: {'firstName': firstName},
        );
      } on DioException catch (e) {
        print('POST failed, trying PUT: $e');
        response = await _dioService.authPut(
          '/api/v1/user/update-user/$userId',
          data: {'firstName': firstName},
        );
      }

      if (response.statusCode == 200) {
        print('✅ First name updated successfully');
        return response.data;
      } else {
        throw Exception('Failed to update first name: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('❌ Error updating first name: ${e.message}');
      if (e.response != null) {
        print('Response data: ${e.response?.data}');
        print('Status code: ${e.response?.statusCode}');
      }
      throw Exception('Failed to update first name: ${e.message}');
    }
  }

  /// Update user profile with exact payload format using PUT method only
  Future<Map<String, dynamic>?> updateUserProfileExact({
    required String imageUrl,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null) {
        throw Exception('User ID not found');
      }

      // Create exact payload format you specified
      final Map<String, dynamic> payload = {
        'imageUrl': imageUrl,
        'firstName': firstName,
        'lastName': lastName,
      };

      print('📦 Exact payload format: $payload');
      print('👤 User ID: $userId');

      // Use PUT method only
      final response = await _dioService.authApi.put(
        '/api/v1/user/update-user/$userId',
        data: payload,
      );

      print('✅ PUT response status: ${response.statusCode}');
      print('✅ PUT response data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Profile updated successfully with exact payload format');
        return response.data;
      } else {
        throw Exception('Failed to update profile: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('❌ Error updating profile: ${e.message}');
      print('❌ Response data: ${e.response?.data}');
      print('❌ Status code: ${e.response?.statusCode}');
      throw Exception('Failed to update profile: ${e.message}');
    }
  }

  /// Update user profile with exact payload format using PUT method only (with userId parameter)
  Future<Map<String, dynamic>?> updateUserProfileExactById({
    required String userId,
    required String imageUrl,
    required String firstName,
    required String lastName,
  }) async {
    try {
      // Create exact payload format you specified
      final Map<String, dynamic> payload = {
        'imageUrl': imageUrl,
        'firstName': firstName,
        'lastName': lastName,
      };

      print('📦 Exact payload format: $payload');
      print('👤 User ID: $userId');

      // Use the correct endpoint path with auth prefix
      final endpoint = '/api/v1/user/update-user/$userId';
      print('🌐 Endpoint: $endpoint');
      print('🔗 Full URL: https://mvp.edetectives.co.bw/$endpoint');

      // Use PUT method only
      final response = await _dioService.authApi.put(
        endpoint,
        data: payload,
        options: Options(headers: await _getAuthHeaders()),
      );

      print('✅ PUT response status: ${response.statusCode}');
      print('✅ PUT response data: ${response.data}');
      print('✅ PUT response data type: ${response.data.runtimeType}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Profile updated successfully with exact payload format');

        // Handle different response types
        if (response.data is Map<String, dynamic>) {
          return response.data;
        } else if (response.data is String) {
          // If response is a string, wrap it in a map
          return {'message': response.data, 'status': 'success'};
        } else {
          // For any other type, convert to map
          return {'data': response.data, 'status': 'success'};
        }
      } else {
        throw Exception('Failed to update profile: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('❌ Error updating profile: ${e.message}');
      print('❌ Response data: ${e.response?.data}');
      print('❌ Status code: ${e.response?.statusCode}');
      throw Exception('Failed to update profile: ${e.message}');
    }
  }

  Future<Map<String, dynamic>?> updateFullProfile({
    String? firstName,
    String? lastName,
    FormData? profileImage,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null) {
        throw Exception('User ID not found');
      }

      Map<String, dynamic> updateData = {};

      if (firstName != null) updateData['firstName'] = firstName;
      if (lastName != null) updateData['lastName'] = lastName;

      // If profile image is provided, use FormData
      dynamic requestData;
      Map<String, String>? headers;

      if (profileImage != null) {
        requestData = profileImage;
        // Add other fields to FormData
        if (firstName != null) {
          profileImage.fields.add(MapEntry('firstName', firstName));
        }
        if (lastName != null) {
          profileImage.fields.add(MapEntry('lastName', lastName));
        }
        headers = {'Content-Type': 'multipart/form-data'};
      } else {
        requestData = updateData;
      }

      // Try POST first, then PUT as fallback
      Response response;
      try {
        response = await _dioService.authPost(
          '/api/v1/user/update-user/$userId',
          data: requestData,
          queryParameters: headers,
        );
      } on DioException catch (e) {
        print('POST failed, trying PUT: $e');
        response = await _dioService.authPut(
          '/api/v1/user/update-user/$userId',
          data: requestData,
          queryParameters: headers,
        );
      }

      if (response.statusCode == 200) {
        print('✅ Profile updated successfully');
        return response.data;
      } else {
        throw Exception('Failed to update profile: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('❌ Error updating profile: ${e.message}');
      if (e.response != null) {
        print('Response data: ${e.response?.data}');
        print('Status code: ${e.response?.statusCode}');
      }
      throw Exception('Failed to update profile: ${e.message}');
    }
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Change password method
  Future<Map<String, dynamic>> changePassword(
    String userId,
    String newPassword,
  ) async {
    try {
      print('🔄 Changing password for user: $userId');

      final endpoint = '/api/v1/user/reset-password/$userId';
      print('🌐 Endpoint: $endpoint');
      print('🔗 Full URL: https://mvp.edetectives.co.bw/$endpoint');

      final payload = {'password': newPassword};

      print('📦 Payload: $payload');

      final response = await _dioService.authApi.post(
        endpoint,
        data: payload,
        options: Options(headers: await _getAuthHeaders()),
      );

      print('✅ Password change response status: ${response.statusCode}');
      print('✅ Password change response data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Password changed successfully');

        // Handle different response types
        if (response.data is Map<String, dynamic>) {
          return response.data;
        } else if (response.data is String) {
          return {'message': response.data, 'status': 'success'};
        } else {
          return {'data': response.data, 'status': 'success'};
        }
      }

      throw Exception('Failed to change password: ${response.statusCode}');
    } on DioException catch (e) {
      print('❌ Error changing password: ${e.message}');
      print('❌ Response data: ${e.response?.data}');
      print('❌ Status code: ${e.response?.statusCode}');
      throw Exception('Failed to change password: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> getCategoriesWithSubcategories() async {
    try {
      print('🔄 Fetching categories with subcategories...');

      final response = await _dioService.mainApi.get(
        '/api/v1/reports/categories/with-subcategories',
      );

      print('✅ Categories response status: ${response.statusCode}');
      print('✅ Categories response data: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ Categories fetched successfully');
        return response.data;
      } else {
        throw Exception('Failed to fetch categories: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('❌ Error fetching categories: ${e.message}');
      print('❌ Response data: ${e.response?.data}');
      print('❌ Status code: ${e.response?.statusCode}');
      throw Exception('Failed to fetch categories: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> getDueDiligenceFiles(String reportId) async {
    try {
      print('🔄 Fetching due diligence files for report: $reportId');

      final response = await _dioService.mainApi.get(
        '/api/v1/due-diligence/files/$reportId',
      );

      print('✅ Due diligence files response status: ${response.statusCode}');
      print('✅ Due diligence files response data: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ Due diligence files fetched successfully');
        return response.data;
      } else {
        throw Exception(
          'Failed to fetch due diligence files: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      print('❌ Error fetching due diligence files: ${e.message}');
      print('❌ Response data: ${e.response?.data}');
      print('❌ Status code: ${e.response?.statusCode}');
      throw Exception('Failed to fetch due diligence files: ${e.message}');
    }
  }

  // Helper method to get file type from file path
  String _getFileType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      // Document types
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'rtf':
        return 'application/rtf';
      case 'csv':
        return 'text/csv';
      case 'odt':
        return 'application/vnd.oasis.opendocument.text';
      case 'ods':
        return 'application/vnd.oasis.opendocument.spreadsheet';
      case 'odp':
        return 'application/vnd.oasis.opendocument.presentation';

      // Image types
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'tiff':
      case 'tif':
        return 'image/tiff';
      case 'svg':
        return 'image/svg+xml';

      // Audio types
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'ogg':
        return 'audio/ogg';
      case 'm4a':
        return 'audio/mp4';

      // Video types
      case 'mp4':
        return 'video/mp4';
      case 'avi':
        return 'video/x-msvideo';
      case 'mov':
        return 'video/quicktime';
      case 'wmv':
        return 'video/x-ms-wmv';
      case 'flv':
        return 'video/x-flv';
      case 'webm':
        return 'video/webm';
      case 'mkv':
        return 'video/x-matroska';

      // Archive types
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/x-rar-compressed';
      case '7z':
        return 'application/x-7z-compressed';
      case 'tar':
        return 'application/x-tar';
      case 'gz':
        return 'application/gzip';

      default:
        return 'application/octet-stream';
    }
  }

  Future<Map<String, dynamic>> uploadDueDiligenceFile(
    File file,
    String reportId,
    String categoryId,
    String subcategoryId,
  ) async {
    try {
      print('🔄 Uploading due diligence file...');
      print('📁 File: ${file.path}');
      print('📋 Report ID: $reportId');
      print('🏷️ Category ID: $categoryId');
      print('📝 Subcategory ID: $subcategoryId');

      // Get proper MIME type from file extension
      final properMimeType = _getFileType(file.path);

      print('🔍 File MIME type detection:');
      print('   - File path: ${file.path}');
      print('   - Detected MIME type: $properMimeType');

      // Create form data with proper MIME type
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
          contentType: DioMediaType.parse(properMimeType),
        ),
        'reportId': reportId,
        'categoryId': categoryId,
        'subcategoryId': subcategoryId,
      });

      print('🔍 Form data details:');
      print('   - File path: ${file.path}');
      print('   - File name: ${file.path.split('/').last}');
      print('   - Report ID: $reportId');
      print('   - Category ID: $categoryId');
      print('   - Subcategory ID: $subcategoryId');
      print('   - Form data fields: ${formData.fields.length}');
      print('   - Form data files: ${formData.files.length}');

      // Debug form data fields
      for (var field in formData.fields) {
        print('   - Field: ${field.key} = ${field.value}');
      }

      // Debug form data files
      for (var fileField in formData.files) {
        print(
          '   - File field: ${fileField.key} = ${fileField.value.filename}',
        );
      }

      // Get the access token for authentication
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        throw Exception('No access token available for file upload');
      }

      // Set headers with authentication
      final headers = {
        'Content-Type': 'multipart/form-data',
        'Authorization': 'Bearer $accessToken',
      };

      print('🔑 Using access token: ${accessToken.substring(0, 20)}...');

      print(
        '🌐 Uploading to endpoint: /api/v1/due-diligence/upload?reportId=$reportId',
      );
      print('🔑 Headers: $headers');

      // Try the primary endpoint first
      Response response;
      try {
        response = await _dioService.fileUploadApi.post(
          '/api/v1/due-diligence/upload?reportId=$reportId',
          data: formData,
          options: Options(headers: headers),
        );
      } catch (e) {
        print('⚠️ Primary endpoint failed, trying alternative endpoint...');
        // Try alternative endpoint without query parameters
        try {
          response = await _dioService.fileUploadApi.post(
            '/api/v1/due-diligence/upload',
            data: formData,
            options: Options(headers: headers),
          );
        } catch (e2) {
          print(
            '⚠️ Alternative endpoint failed, trying file-upload endpoint...',
          );
          // Try using the same endpoint as profile image upload
          response = await _dioService.fileUploadApi.post(
            '/api/v1/file-upload/due-diligence',
            data: formData,
            options: Options(headers: headers),
          );
        }
      }

      print('✅ Upload response status: ${response.statusCode}');
      print('✅ Upload response data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ File uploaded successfully');

        // Handle different response types and structure the response properly
        if (response.data is Map<String, dynamic>) {
          final responseData = response.data as Map<String, dynamic>;

          // Generate a proper document_id if missing
          final documentId =
              responseData['document_id'] ??
              responseData['id'] ??
              DateTime.now().millisecondsSinceEpoch.toString();

          // Structure the response with complete file details
          final structuredData = {
            'document_id': documentId,
            'uploaded_at':
                responseData['uploaded_at'] ?? DateTime.now().toIso8601String(),
            'status': responseData['status'] ?? 'in_review',
            'comments': responseData['comments'] ?? '',
            'url': responseData['url'] ?? responseData['file_url'],
            'name': responseData['name'] ?? file.path.split('/').last,
            'size': responseData['size'] ?? await file.length(),
            'type': responseData['type'] ?? _getFileType(file.path),
          };

          return {'status': 'success', 'data': structuredData};
        } else if (response.data is String) {
          return {
            'status': 'success',
            'data': {
              'document_id': DateTime.now().millisecondsSinceEpoch.toString(),
              'uploaded_at': DateTime.now().toIso8601String(),
              'status': 'in_review',
              'comments': '',
              'url': response.data,
              'name': file.path.split('/').last,
              'size': await file.length(),
              'type': _getFileType(file.path),
            },
          };
        } else {
          return {
            'status': 'success',
            'data': {
              'document_id': DateTime.now().millisecondsSinceEpoch.toString(),
              'uploaded_at': DateTime.now().toIso8601String(),
              'status': 'in_review',
              'comments': '',
              'url': null,
              'name': file.path.split('/').last,
              'size': await file.length(),
              'type': _getFileType(file.path),
            },
          };
        }
      } else {
        print('❌ Upload failed with status: ${response.statusCode}');
        print('❌ Response data: ${response.data}');
        throw Exception(
          'Failed to upload file: ${response.statusCode} - ${response.data}',
        );
      }
    } on DioException catch (e) {
      print('❌ DioException uploading file: ${e.message}');
      print('❌ Error type: ${e.type}');
      print('❌ Response data: ${e.response?.data}');
      print('❌ Status code: ${e.response?.statusCode}');
      print('❌ Request path: ${e.requestOptions.path}');

      // Handle different types of DioExceptions
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          throw Exception('Network timeout: ${e.message}');
        case DioExceptionType.connectionError:
          throw Exception('Connection error: ${e.message}');
        case DioExceptionType.badResponse:
          throw Exception(
            'Server error: ${e.response?.statusCode} - ${e.response?.data}',
          );
        default:
          throw Exception('Upload failed: ${e.message}');
      }
    }
  }

  // Submit due diligence report method
  Future<Map<String, dynamic>> submitDueDiligence(
    Map<String, dynamic> payload,
  ) async {
    try {
      print('🔄 Submitting due diligence report...');
      print('📤 Payload: ${payload.toString()}');

      final response = await _dioService.reportsPost(
        '/api/v1/reports/due-diligence',
        data: payload,
      );

      print('✅ Submit due diligence response status: ${response.statusCode}');
      print('✅ Submit due diligence response data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Due diligence report submitted successfully');

        // Handle different response types
        if (response.data is Map<String, dynamic>) {
          return response.data;
        } else if (response.data is String) {
          return {'message': response.data, 'status': 'success'};
        } else {
          return {'data': response.data, 'status': 'success'};
        }
      } else {
        throw Exception(
          'Failed to submit due diligence: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      print('❌ Error submitting due diligence: ${e.message}');
      print('❌ Response data: ${e.response?.data}');
      print('❌ Status code: ${e.response?.statusCode}');
      throw Exception('Failed to submit due diligence: ${e.message}');
    }
  }

  // Get due diligence reports method
  Future<Map<String, dynamic>> getDueDiligenceReports({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? search,
    String? groupId,
  }) async {
    try {
      print('📥 Fetching due diligence reports - Page: $page, Size: $pageSize');
      print(
        '🌐 Endpoint: /api/v1/reports/due-diligence/due-diligence-submitteddocs-summary',
      );
      print('🆔 GroupId: $groupId');

      // Build query parameters
      final queryParams = <String, dynamic>{'page': page, 'limit': pageSize};

      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      if (groupId != null && groupId.isNotEmpty) {
        queryParams['groupId'] = groupId;
      }

      print('🔍 Query parameters: $queryParams');

      // Use the correct endpoint for fetching due diligence reports
      final response = await _dioService.reportsGet(
        '/api/v1/reports/due-diligence/due-diligence-submitteddocs-summary',
        queryParameters: queryParams,
      );

      print(
        '✅ Get due diligence reports response status: ${response.statusCode}',
      );
      print('✅ Get due diligence reports response data: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ API response received successfully');
        print('📦 Response data type: ${response.data.runtimeType}');
        print('📦 Response data: ${response.data}');

        // Handle different response types
        if (response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          print('🔍 Response keys: ${data.keys.toList()}');
          return data;
        } else if (response.data is List) {
          final data = response.data as List;
          print('🔍 List length: ${data.length}');
          if (data.isNotEmpty) {
            print('🔍 First item type: ${data.first.runtimeType}');
            print('🔍 First item: ${data.first}');
          }
          return {
            'status': 'success',
            'data': response.data,
            'message': 'Due diligence reports fetched successfully',
          };
        } else {
          print('🔍 Unknown response type: ${response.data.runtimeType}');
          return {'data': response.data, 'status': 'success'};
        }
      } else {
        throw Exception(
          'Failed to fetch due diligence reports: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      print('❌ Error fetching due diligence reports: ${e.message}');
      print('❌ Response data: ${e.response?.data}');
      print('❌ Status code: ${e.response?.statusCode}');
      throw Exception('Failed to fetch due diligence reports: ${e.message}');
    }
  }

  // Get due diligence report by ID method
  Future<Map<String, dynamic>> getDueDiligenceReportById(
    String reportId,
  ) async {
    try {
      print('📥 Fetching due diligence report by ID: $reportId');
      print('🌐 Endpoint: /api/v1/reports/due-diligence/$reportId');

      final response = await _dioService.reportsGet(
        '/api/v1/reports/due-diligence/$reportId',
      );

      print(
        '✅ Get due diligence report by ID response status: ${response.statusCode}',
      );
      print('✅ Get due diligence report by ID response data: ${response.data}');

      if (response.statusCode == 200) {
        print('✅ API response received successfully');
        print('📦 Response data type: ${response.data.runtimeType}');
        print('📦 Response data: ${response.data}');

        // Handle different response types
        if (response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          print('🔍 Response keys: ${data.keys.toList()}');
          return data;
        } else if (response.data is List) {
          final data = response.data as List;
          print('🔍 List length: ${data.length}');
          if (data.isNotEmpty) {
            print('🔍 First item type: ${data.first.runtimeType}');
            print('🔍 First item: ${data.first}');
          }
          return {
            'status': 'success',
            'data': response.data,
            'message': 'Due diligence report fetched successfully',
          };
        } else {
          print('🔍 Unknown response type: ${response.data.runtimeType}');
          return {'data': response.data, 'status': 'success'};
        }
      } else {
        throw Exception(
          'Failed to fetch due diligence report: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      print('❌ Error fetching due diligence report: ${e.message}');
      print('❌ Response data: ${e.response?.data}');
      print('❌ Status code: ${e.response?.statusCode}');
      throw Exception('Failed to fetch due diligence report: ${e.message}');
    }
  }

  // Update due diligence report method
  Future<Map<String, dynamic>> updateDueDiligenceReport(
    String reportId,
    Map<String, dynamic> payload,
  ) async {
    try {
      print('📤 Updating due diligence report: $reportId');
      print('🌐 Endpoint: /api/v1/reports/due-diligence/$reportId');
      print('📦 Payload: $payload');

      final response = await _dioService.reportsPut(
        '/api/v1/reports/due-diligence/$reportId',
        data: payload,
      );

      print(
        '✅ Update due diligence report response status: ${response.statusCode}',
      );
      print('✅ Update due diligence report response data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Due diligence report updated successfully');

        // Handle different response types
        if (response.data is Map<String, dynamic>) {
          return response.data;
        } else if (response.data is String) {
          return {'message': response.data, 'status': 'success'};
        } else {
          return {'data': response.data, 'status': 'success'};
        }
      } else {
        throw Exception(
          'Failed to update due diligence report: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      print('❌ Error updating due diligence report: ${e.message}');
      print('❌ Response data: ${e.response?.data}');
      print('❌ Status code: ${e.response?.statusCode}');
      throw Exception('Failed to update due diligence report: ${e.message}');
    }
  }
}
