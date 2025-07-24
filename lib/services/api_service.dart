import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  late Dio _dioAuth; // For Auth server
  late Dio _dioMain; // For Main server
  bool _useMockData = false;
  bool _isRefreshingToken = false;

  ApiService() {
    // Auth Server Dio
    _dioAuth = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl1,
        contentType: 'application/json',
        connectTimeout: Duration(seconds: ApiConfig.connectTimeout),
        receiveTimeout: Duration(seconds: ApiConfig.receiveTimeout),
        headers: ApiConfig.defaultHeaders,
      ),
    );

    // Main Server Dio
    _dioMain = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl2,
        contentType: 'application/json',
        connectTimeout: Duration(seconds: ApiConfig.connectTimeout),
        receiveTimeout: Duration(seconds: ApiConfig.receiveTimeout),
        headers: ApiConfig.defaultHeaders,
      ),
    );

    _setupInterceptors(_dioAuth);
    _setupInterceptors(_dioMain);
  }

  void _setupInterceptors(Dio dio) {
    if (ApiConfig.enableLogging) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) => print(obj),
        ),
      );
    }

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _getAccessToken();
          print(
            'Request to ${options.path} - Token: ${token != null ? "present" : "missing"}',
          );
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          print(
            'API Error: ${error.response?.statusCode} - ${error.requestOptions.path}',
          );
          if (error.response?.statusCode == 401 && !_isRefreshingToken) {
            print('401 error detected, checking for refresh token...');
            final refreshToken = await _getRefreshToken();
            if (refreshToken == null) {
              print('No refresh token available, cannot refresh');
              return handler.next(error);
            }
            print('Attempting token refresh...');
            _isRefreshingToken = true;
            final refreshed = await _refreshToken();
            _isRefreshingToken = false;
            if (refreshed) {
              print('Token refresh successful, retrying request...');
              final retryToken = await _getAccessToken();
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $retryToken';
              final retryResponse = await dio.fetch(opts);
              return handler.resolve(retryResponse);
            } else {
              print('Token refresh failed, proceeding with error');
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<void> setUseMockData(bool value) async {
    _useMockData = value;
  }

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<String?> _getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', accessToken);
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

      final response = await _dioAuth.post(
        'https://126306b857e5.ngrok-free.app/auth/refresh-token',
        data: {'refreshToken': refreshToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
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
    return _dioAuth.get(url);
  }

  Future<Response> post(String url, dynamic data) async {
    return _dioAuth.post(url, data: data);
  }

  Future<Response> getProfile() async {
    try {
      final response = await _dioAuth.get(
        'https://126306b857e5.ngrok-free.app/user/me',
      );
      return response;
    } catch (e) {
      print('Failed to get user profile: $e');
      rethrow;
    }
  }

  //////////////////////////////////////////////////////////////////////

  // Example: Login using Auth Server
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      print('Attempting login with username: $username');

      final response = await _dioAuth.post(
        'https://126306b857e5.ngrok-free.app/auth/login-user',
        data: {'username': username, 'password': password},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      print('Raw response: ${response}');
      print('Raw response data: ${response.data}');

      if (response.data == null || response.data is! Map<String, dynamic>) {
        throw Exception('Invalid response from server');
      }

      final Map<String, dynamic> responseData = response.data;

      final prefs = await SharedPreferences.getInstance();

      // Save tokens if available
      if (responseData.containsKey('access_token')) {
        await prefs.setString('auth_token', responseData['access_token']);
        print('access_token: ${responseData['access_token']}');
      }
      if (responseData.containsKey('refresh_token')) {
        await prefs.setString('refresh_token', responseData['refresh_token']);
        print('refresh_token: ${responseData['refresh_token']}');
      }
      if (responseData.containsKey('id_token')) {
        await prefs.setString('id_token', responseData['id_token']);
        print('id_token: ${responseData['id_token']}');
      }

      // Optional fallback if user data not available
      if (!responseData.containsKey('user')) {
        responseData['user'] = {
          'username': username, // fallback to input
          'email': '',
          'name': '',
        };
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
      final response = await _dioMain.get(ApiConfig.dashboardStatsEndpoint);

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

      final response = await _dioAuth.post(
        ApiConfig.registerEndpoint,
        data: payload,
      );

      print('Registration response: ${response.data}');
      print('Type of response.data: ${response.data.runtimeType}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data is Map<String, dynamic> &&
            response.data['user'] is Map<String, dynamic>) {
          Map<String, dynamic> responseData = response.data;
          // Save token if it exists in the response
          if (responseData.containsKey('token')) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('auth_token', responseData['token']);
          } else if (responseData.containsKey('access_token')) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('auth_token', responseData['access_token']);
          }
          return responseData;
        } else {
          print('Unexpected response format: ${response.data}');
          throw Exception('Invalid registration response format');
        }
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
        await _dioAuth.post(ApiConfig.logoutEndpoint);
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

      final response = await _dioMain.get(ApiConfig.securityAlertsEndpoint);
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

      final response = await _dioMain.post(
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

      final response = await _dioMain.get(
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

      final response = await _dioAuth.get(ApiConfig.userProfileEndpoint);

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

      final response = await _dioAuth.put(
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
      final response = await _dioMain.get('/report-category');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchReportTypesByCategory(
    String categoryId,
  ) async {
    try {
      final response = await _dioMain.get(
        '/report-type',
        queryParameters: {'id': categoryId},
      );
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      print('Error fetching types: $e');
      return [];
    }
  }

  Future<void> submitScamReport(Map<String, dynamic> data) async {
    try {
      print('Dio baseUrl: ${_dioMain.options.baseUrl}');
      print('Dio path: /reports');
      print('Data: $data');
      final response = await _dioMain.post('/reports', data: data);
      print('Backend response: ${response.data}');
    } catch (e) {
      print('Error sending to backend: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchReportTypes() async {
    try {
      final response = await _dioMain.get('/report-type');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      print('Error fetching types: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchCategoryById(String categoryId) async {
    try {
      final response = await _dioMain.get('/report-category/$categoryId');
      return response.data;
    } catch (e) {
      print('Error fetching category by ID: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchTypeById(String typeId) async {
    try {
      final response = await _dioMain.get('/report-type/$typeId');
      return response.data;
    } catch (e) {
      print('Error fetching type by ID: $e');
      return null;
    }
  }

  //Fetch the data in report-type
}




// //
// //
// // import 'package:dio/dio.dart';
// // import 'package:shared_preferences/shared_preferences.dart';
// // import '../config/api_config.dart';
// //
// // class ApiService {
// //   late Dio _dio;
// //   bool _useMockData = false;
// //
// //   ApiService() {
// //     _dio = Dio(BaseOptions(
// //       baseUrl: ApiConfig.baseUrl1,
// //       connectTimeout: Duration(seconds: ApiConfig.connectTimeout),
// //       receiveTimeout: Duration(seconds: ApiConfig.receiveTimeout),
// //       headers: ApiConfig.defaultHeaders,
// //     ));
// //
// //     _dio=Dio(BaseOptions(
// //         baseUrl: ApiConfig.baseUrl2,
// //         connectTimeout: Duration(seconds: ApiConfig.connectTimeout),
// //         receiveTimeout: Duration(seconds: ApiConfig.receiveTimeout),
// //         headers: ApiConfig.defaultHeaders,
// //     ));
// //
// //     // Add interceptors for logging and token management
// //     if (ApiConfig.enableLogging) {
// //       _dio.interceptors.add(LogInterceptor(
// //         requestBody: true,
// //         responseBody: true,
// //         logPrint: (obj) => print(obj),
// //       ));
// //     }
// //
// //     _dio.interceptors.add(InterceptorsWrapper(
// //       onRequest: (options, handler) async {
// //         // Add auth token if available
// //         final prefs = await SharedPreferences.getInstance();
// //         final token = prefs.getString('auth_token');
// //         if (token != null) {
// //           options.headers['Authorization'] = 'Bearer $token';
// //         }
// //         handler.next(options);
// //       },
// //       onError: (error, handler) {
// //         print('API Error: ${error.message}');
// //         print('API Error Response: ${error.response?.data}');
// //
// //         // If it's a connection error, switch to mock data
// //         if (error.type == DioExceptionType.connectionError ||
// //             error.type == DioExceptionType.connectionTimeout) {
// //           _useMockData = true;
// //         }
// //
// //         handler.next(error);
// //       },
// //     ));
// //   }
// //
// //   // Authentication endpoints
// //   Future<Map<String, dynamic>> login(String username, String password) async {
// //     try {
// //       print('Attempting login with username: $username');
// //
// //       // If using mock data, return mock response
// //       if (_useMockData) {
// //         return _getMockLoginResponse(username);
// //       }
// //
// //       final response = await _dio.post(ApiConfig.loginEndpoint, data: {
// //         'username': username,
// //         'password': password,
// //       });
// //
// //       print('Login response: ${response.data}');
// //
// //       if (response.statusCode == 200 || response.statusCode == 201) {
// //         // Handle different possible response structures
// //         Map<String, dynamic> responseData = response.data;
// //
// //         // Save token if it exists in the response
// //         if (responseData.containsKey('token')) {
// //           final prefs = await SharedPreferences.getInstance();
// //           await prefs.setString('auth_token', responseData['token']);
// //         } else if (responseData.containsKey('access_token')) {
// //           final prefs = await SharedPreferences.getInstance();
// //           await prefs.setString('auth_token', responseData['access_token']);
// //         }
// //
// //         // If the response doesn't contain user data, create a mock user
// //         if (!responseData.containsKey('user')) {
// //           responseData['user'] = {
// //             'id': responseData['id'] ?? '1',
// //             'username': username,
// //             'email': responseData['email'] ?? '$username@example.com',
// //             'created_at': DateTime.now().toIso8601String(),
// //             'updated_at': DateTime.now().toIso8601String(),
// //           };
// //         }
// //
// //         return responseData;
// //       }
// //       throw Exception('Login failed - Status: ${response.statusCode}');
// //     } on DioException catch (e) {
// //       print('DioException during login: ${e.message}');
// //       print('Response data: ${e.response?.data}');
// //       print('Response status: ${e.response?.statusCode}');
// //
// //       // If API is not available, use mock data
// //       if (e.type == DioExceptionType.connectionError ||
// //           e.type == DioExceptionType.connectionTimeout ||
// //           e.response?.statusCode == 404) {
// //         print('Using mock data for login');
// //         return _getMockLoginResponse(username);
// //       }
// //
// //       if (e.response?.statusCode == 401) {
// //         throw Exception('Invalid username or password');
// //       } else {
// //         throw Exception(e.response?.data?['message'] ?? 'Login failed: ${e.message}');
// //       }
// //     } catch (e) {
// //       print('General exception during login: $e');
// //       // Fallback to mock data
// //       return _getMockLoginResponse(username);
// //     }
// //   }
// //
// //   Map<String, dynamic> _getMockLoginResponse(String username) {
// //     return {
// //       'user': {
// //         'id': '1',
// //         'username': username,
// //         'email': '$username@example.com',
// //         'created_at': DateTime.now().toIso8601String(),
// //         'updated_at': DateTime.now().toIso8601String(),
// //       },
// //       'token': 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
// //       'message': 'Login successful (mock data)',
// //     };
// //   }
// //
// //   Future<Map<String, dynamic>> register(String username, String email, String password) async {
// //     try {
// //       print('Attempting registration with username: $username, email: $email');
// //
// //       // If using mock data, return mock response
// //       if (_useMockData) {
// //         return _getMockRegisterResponse(username, email);
// //       }
// //
// //       final response = await _dio.post(ApiConfig.registerEndpoint, data: {
// //         'username': username,
// //         'email': email,
// //         'password': password,
// //       });
// //
// //       print('Registration response: ${response.data}');
// //
// //       if (response.statusCode == 200 || response.statusCode == 201) {
// //         Map<String, dynamic> responseData = response.data;
// //
// //         // Save token if it exists in the response
// //         if (responseData.containsKey('token')) {
// //           final prefs = await SharedPreferences.getInstance();
// //           await prefs.setString('auth_token', responseData['token']);
// //         } else if (responseData.containsKey('access_token')) {
// //           final prefs = await SharedPreferences.getInstance();
// //           await prefs.setString('auth_token', responseData['access_token']);
// //         }
// //
// //         // If the response doesn't contain user data, create a mock user
// //         if (!responseData.containsKey('user')) {
// //           responseData['user'] = {
// //             'id': responseData['id'] ?? '1',
// //             'username': username,
// //             'email': email,
// //             'created_at': DateTime.now().toIso8601String(),
// //             'updated_at': DateTime.now().toIso8601String(),
// //           };
// //         }
// //
// //         return responseData;
// //       }
// //       throw Exception('Registration failed - Status: ${response.statusCode}');
// //     } on DioException catch (e) {
// //       print('DioException during registration: ${e.message}');
// //       print('Response data: ${e.response?.data}');
// //
// //       // If API is not available, use mock data
// //       if (e.type == DioExceptionType.connectionError ||
// //           e.type == DioExceptionType.connectionTimeout ||
// //           e.response?.statusCode == 404) {
// //         print('Using mock data for registration');
// //         return _getMockRegisterResponse(username, email);
// //       }
// //
// //       if (e.response?.statusCode == 409) {
// //         throw Exception('Username or email already exists');
// //       } else if (e.response?.statusCode == 400) {
// //         throw Exception('Invalid registration data');
// //       } else {
// //         throw Exception(e.response?.data?['message'] ?? 'Registration failed: ${e.message}');
// //       }
// //     } catch (e) {
// //       print('General exception during registration: $e');
// //       // Fallback to mock data
// //       return _getMockRegisterResponse(username, email);
// //     }
// //   }
// //
// //   Map<String, dynamic> _getMockRegisterResponse(String username, String email) {
// //     return {
// //       'user': {
// //         'id': '1',
// //         'username': username,
// //         'email': email,
// //       },
// //       'token': 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
// //       'message': 'Registration successful (mock data)',
// //     };
// //   }
// //
// //   Future<void> logout() async {
// //     try {
// //       if (!_useMockData) {
// //         await _dio.post(ApiConfig.logoutEndpoint);
// //       }
// //       // Clear token from shared preferences
// //       final prefs = await SharedPreferences.getInstance();
// //       await prefs.remove('auth_token');
// //     } on DioException catch (e) {
// //       print('Logout error: ${e.message}');
// //       // Even if logout fails, clear the token locally
// //       final prefs = await SharedPreferences.getInstance();
// //       await prefs.remove('auth_token');
// //     }
// //   }
// //
// //   // Security alerts endpoints
// //   Future<List<Map<String, dynamic>>> getSecurityAlerts() async {
// //     try {
// //       if (_useMockData) {
// //         return _getMockSecurityAlerts();
// //       }
// //
// //       final response = await _dio.get(ApiConfig.securityAlertsEndpoint);
// //       if (response.statusCode == 200) {
// //         // Handle different response structures
// //         if (response.data is List) {
// //           return List<Map<String, dynamic>>.from(response.data);
// //         } else if (response.data.containsKey('alerts')) {
// //           return List<Map<String, dynamic>>.from(response.data['alerts']);
// //         } else {
// //           return [];
// //         }
// //       }
// //       throw Exception('Failed to fetch security alerts');
// //     } on DioException catch (e) {
// //       print('Error fetching security alerts: ${e.message}');
// //       // Return mock data
// //       return _getMockSecurityAlerts();
// //     }
// //   }
// //
// //   List<Map<String, dynamic>> _getMockSecurityAlerts() {
// //     return [
// //       {
// //         'id': '1',
// //         'title': 'Suspicious Email Detected',
// //         'description': 'A phishing email was detected in your inbox',
// //         'severity': 'high',
// //         'type': 'phishing',
// //         'timestamp': DateTime.now().subtract(Duration(hours: 2)).toIso8601String(),
// //         'is_resolved': false,
// //       },
// //       {
// //         'id': '2',
// //         'title': 'Malware Alert',
// //         'description': 'Potential malware detected in downloaded file',
// //         'severity': 'critical',
// //         'type': 'malware',
// //         'timestamp': DateTime.now().subtract(Duration(hours: 1)).toIso8601String(),
// //         'is_resolved': true,
// //       },
// //     ];
// //   }
// //
// //   Future<Map<String, dynamic>> getDashboardStats() async {
// //     try {
// //       if (_useMockData) {
// //         return _getMockDashboardStats();
// //       }
// //
// //       final response = await _dio.get(ApiConfig.dashboardStatsEndpoint);
// //       if (response.statusCode == 200) {
// //         return response.data;
// //       }
// //       throw Exception('Failed to fetch dashboard stats');
// //     } on DioException catch (e) {
// //       print('Error fetching dashboard stats: ${e.message}');
// //       // Return mock data
// //       return _getMockDashboardStats();
// //     }
// //   }
// //
// //   Map<String, dynamic> _getMockDashboardStats() {
// //     return {
// //       'total_alerts': 50,
// //       'resolved_alerts': 35,
// //       'pending_alerts': 15,
// //       'alerts_by_type': {
// //         'spam': 20,
// //         'malware': 15,
// //         'fraud': 10,
// //         'other': 5,
// //       },
// //       'alerts_by_severity': {
// //         'low': 25,
// //         'medium': 15,
// //         'high': 8,
// //         'critical': 2,
// //       },
// //       'threat_trend_data': [30, 35, 40, 50, 45, 38, 42],
// //       'threat_bar_data': [10, 20, 15, 30, 25, 20, 10],
// //       'risk_score': 75.0,
// //     };
// //   }
// //
// //   Future<Map<String, dynamic>> reportSecurityIssue(Map<String, dynamic> issueData) async {
// //     try {
// //       if (_useMockData) {
// //         return {'message': 'Issue reported successfully (mock data)'};
// //       }
// //
// //       final response = await _dio.post(ApiConfig.reportSecurityIssueEndpoint, data: issueData);
// //       if (response.statusCode == 201) {
// //         return response.data;
// //       }
// //       throw Exception('Failed to report security issue');
// //     } on DioException catch (e) {
// //       print('Error reporting security issue: ${e.message}');
// //       return {'message': 'Issue reported successfully (mock data)'};
// //     }
// //   }
// //
// //   Future<List<Map<String, dynamic>>> getThreatHistory({String period = '1D'}) async {
// //     try {
// //       if (_useMockData) {
// //         return _getMockThreatHistory();
// //       }
// //
// //       final response = await _dio.get(ApiConfig.threatHistoryEndpoint, queryParameters: {
// //         'period': period,
// //       });
// //       if (response.statusCode == 200) {
// //         if (response.data is List) {
// //           return List<Map<String, dynamic>>.from(response.data);
// //         } else if (response.data.containsKey('threats')) {
// //           return List<Map<String, dynamic>>.from(response.data['threats']);
// //         } else {
// //           return [];
// //         }
// //       }
// //       throw Exception('Failed to fetch threat history');
// //     } on DioException catch (e) {
// //       print('Error fetching threat history: ${e.message}');
// //       return _getMockThreatHistory();
// //     }
// //   }
// //
// //   List<Map<String, dynamic>> _getMockThreatHistory() {
// //     return [
// //       {'date': '2024-01-01', 'count': 10},
// //       {'date': '2024-01-02', 'count': 15},
// //       {'date': '2024-01-03', 'count': 8},
// //       {'date': '2024-01-04', 'count': 20},
// //       {'date': '2024-01-05', 'count': 12},
// //     ];
// //   }
// //
// //   // User profile endpoints
// //   Future<Map<String, dynamic>> getUserProfile() async {
// //     try {
// //       if (_useMockData) {
// //         return _getMockUserProfile();
// //       }
// //
// //       final response = await _dio.get(ApiConfig.userProfileEndpoint);
// //       if (response.statusCode == 200) {
// //         return response.data;
// //       }
// //       throw Exception('Failed to fetch user profile');
// //     } on DioException catch (e) {
// //       print('Error fetching user profile: ${e.message}');
// //       // Return mock user data
// //       return _getMockUserProfile();
// //     }
// //   }
// //
// //   Map<String, dynamic> _getMockUserProfile() {
// //     return {
// //       'id': '1',
// //       'username': 'demo_user',
// //       'email': 'demo@example.com',
// //
// //     };
// //   }
// //
// //   Future<Map<String, dynamic>> updateUserProfile(Map<String, dynamic> profileData) async {
// //     try {
// //       if (_useMockData) {
// //         return {'message': 'Profile updated successfully (mock data)'};
// //       }
// //
// //       final response = await _dio.put(ApiConfig.updateProfileEndpoint, data: profileData);
// //       if (response.statusCode == 200) {
// //         return response.data;
// //       }
// //       throw Exception('Failed to update user profile');
// //     } on DioException catch (e) {
// //       print('Error updating user profile: ${e.message}');
// //       return {'message': 'Profile updated successfully (mock data)'};
// //     }
// //   }
// //
// //   // Helper method to handle network errors
// //   String _handleError(DioException error) {
// //     switch (error.type) {
// //       case DioExceptionType.connectionTimeout:
// //       case DioExceptionType.sendTimeout:
// //       case DioExceptionType.receiveTimeout:
// //         return 'Connection timeout. Please check your internet connection.';
// //       case DioExceptionType.badResponse:
// //         return error.response?.data['message'] ?? 'Server error occurred.';
// //       case DioExceptionType.cancel:
// //         return 'Request was cancelled.';
// //       case DioExceptionType.connectionError:
// //         return 'No internet connection.';
// //       default:
// //         return 'An unexpected error occurred.';
// //     }
// //   }
// // }

// import 'package:dio/dio.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../config/api_config.dart';

// class ApiService {
//   late Dio _dioAuth; // For Auth server
//   late Dio _dioMain; // For Main server
//   bool _useMockData = false;

//   ApiService() {
//     // Auth Server Dio
//     _dioAuth = Dio(
//       BaseOptions(
//         baseUrl: ApiConfig.baseUrl1,
//         contentType: 'application/json',
//         connectTimeout: Duration(seconds: ApiConfig.connectTimeout),
//         receiveTimeout: Duration(seconds: ApiConfig.receiveTimeout),
//         headers: ApiConfig.defaultHeaders,
//       ),
//     );

//     // Main Server Dio
//     _dioMain = Dio(
//       BaseOptions(
//         baseUrl: ApiConfig.baseUrl2,
//         contentType: 'application/json',
//         connectTimeout: Duration(seconds: ApiConfig.connectTimeout),
//         receiveTimeout: Duration(seconds: ApiConfig.receiveTimeout),
//         headers: ApiConfig.defaultHeaders,
//       ),
//     );

//     _setupInterceptors(_dioAuth);
//     _setupInterceptors(_dioMain);
//   }

//   void _setupInterceptors(Dio dio) {
//     if (ApiConfig.enableLogging) {
//       dio.interceptors.add(
//         LogInterceptor(
//           requestBody: true,
//           responseBody: true,
//           logPrint: (obj) => print(obj),
//         ),
//       );
//     }

//     dio.interceptors.add(
//       InterceptorsWrapper(
//         onRequest: (options, handler) async {
//           final token = await _getAccessToken();
//           if (token != null) {
//             options.headers['Authorization'] = 'Bearer $token';
//           }
//           return handler.next(options);
//         },
//         onError: (DioException error, handler) async {
//           if (error.response?.statusCode == 401) {
//             final refreshed = await _refreshToken();
//             if (refreshed) {
//               final retryToken = await _getAccessToken();
//               final opts = error.requestOptions;
//               opts.headers['Authorization'] = 'Bearer $retryToken';
//               final retryResponse = await dio.fetch(opts);
//               return handler.resolve(retryResponse);
//             }
//           }
//           return handler.next(error);
//         },
//       ),
//     );
//   }

//   Future<void> setUseMockData(bool value) async {
//     _useMockData = value;
//   }

//   Future<String?> _getAccessToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString('access_token');
//   }

//   Future<String?> _getRefreshToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString('refresh_token');
//   }

//   Future<void> _saveTokens(String accessToken, String refreshToken) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('access_token', accessToken);
//     await prefs.setString('refresh_token', refreshToken);
//   }

//   Future<bool> _refreshToken() async {
//     try {
//       final refreshToken = await _getRefreshToken();
//       print('Attempting token refresh with: $refreshToken');
//       if (refreshToken == null) return false;

//       final response = await _dioAuth.post(
//         'http://4795a8bab1f1.ngrok-free.app/auth/refresh-token',
//         data: {'refreshToken': refreshToken},
//         options: Options(headers: {'Content-Type': 'application/json'}),
//       );

//       final newAccessToken = response.data['access_token'];
//       final newRefreshToken = response.data['refresh_token'];

//       print('New access token: $newAccessToken');
//       await _saveTokens(newAccessToken, newRefreshToken);
//       return true;
//     } catch (e) {
//       print('Token refresh failed: $e');
//       return false;
//     }
//   }

//   Future<Response> get(String url) async {
//     return _dioAuth.get(url);
//   }

//   Future<Response> post(String url, dynamic data) async {
//     return _dioAuth.post(url, data: data);
//   }

//   Future<Response> getProfile() async {
//     try {
//       final response = await _dioAuth.get(
//         'http://4795a8bab1f1.ngrok-free.app/user/me',
//       );
//       return response;
//     } catch (e) {
//       print('Failed to get user profile: $e');
//       rethrow;
//     }
//   }

//   //////////////////////////////////////////////////////////////////////

//   // Example: Login using Auth Server
//   Future<Map<String, dynamic>> login(String username, String password) async {
//     try {
//       print('Attempting login with username: $username');

//       final response = await _dioAuth.post(
//         ApiConfig.loginEndpoint,
//         data: {'username': username, 'password': password},
//         options: Options(headers: {'Content-Type': 'application/json'}),
//       );

//       print('Raw response: ${response}');
//       print('Raw response data: ${response.data}');

//       if (response.data == null || response.data is! Map<String, dynamic>) {
//         throw Exception('Invalid response from server');
//       }

//       final Map<String, dynamic> responseData = response.data;

//       final prefs = await SharedPreferences.getInstance();

//       // Save tokens if available
//       if (responseData.containsKey('access_token')) {
//         await prefs.setString('auth_token', responseData['access_token']);
//         print('access_token: ${responseData['access_token']}');
//       }
//       if (responseData.containsKey('refresh_token')) {
//         await prefs.setString('refresh_token', responseData['refresh_token']);
//         print('refresh_token: ${responseData['refresh_token']}');
//       }
//       if (responseData.containsKey('id_token')) {
//         await prefs.setString('id_token', responseData['id_token']);
//         print('id_token: ${responseData['id_token']}');
//       }

//       // Optional fallback if user data not available
//       if (!responseData.containsKey('user')) {
//         responseData['user'] = {
//           'username': username, // fallback to input
//           'email': '',
//           'name': '',
//         };
//       }

//       return responseData;
//     } on DioException catch (e) {
//       print('DioException during login: ${e.message}');
//       print('DioException response data: ${e.response?.data}');
//       print('DioException status code: ${e.response?.statusCode}');

//       final errMsg = e.response?.data is Map<String, dynamic>
//           ? e.response?.data['message'] ?? 'Unknown error'
//           : e.message;

//       throw Exception('Login failed: $errMsg');
//     } catch (e) {
//       print('General exception during login: $e');
//       throw Exception('Login failed: Invalid response from server');
//     }
//   }

//   // Example: Fetch dashboard stats using Main Server
//   Future<Map<String, dynamic>?> getDashboardStats() async {
//     try {
//       final response = await _dioMain.get(ApiConfig.dashboardStatsEndpoint);

//       if (response.statusCode == 200 && response.data != null) {
//         return response.data as Map<String, dynamic>;
//       } else {
//         throw Exception('Failed to load dashboard stats');
//       }
//     } catch (e) {
//       print("Error fetching stats: $e");
//       return null;
//     }
//   }

//   Future<Map<String, dynamic>> register(
//     String firstname,
//     String lastname,
//     String username,
//     String password,
//   ) async {
//     try {
//       // Print the payload for debugging
//       final payload = {
//         'firstName': firstname,
//         'lastName': lastname,
//         'username': username,
//         'password': password,
//       };
//       print('Registration payload: $payload');

//       final response = await _dioAuth.post(
//         ApiConfig.registerEndpoint,
//         data: payload,
//       );

//       print('Registration response: ${response.data}');
//       print('Type of response.data: ${response.data.runtimeType}');

//       if (response.statusCode == 200 || response.statusCode == 201) {
//         if (response.data is Map<String, dynamic> &&
//             response.data['user'] is Map<String, dynamic>) {
//           Map<String, dynamic> responseData = response.data;
//           // Save token if it exists in the response
//           if (responseData.containsKey('token')) {
//             final prefs = await SharedPreferences.getInstance();
//             await prefs.setString('auth_token', responseData['token']);
//           } else if (responseData.containsKey('access_token')) {
//             final prefs = await SharedPreferences.getInstance();
//             await prefs.setString('auth_token', responseData['access_token']);
//           }
//           return responseData;
//         } else {
//           print('Unexpected response format: ${response.data}');
//           throw Exception('Invalid registration response format');
//         }
//       } else {
//         // Print backend error message if available
//         if (response.data is Map<String, dynamic> &&
//             response.data['message'] != null) {
//           throw Exception(response.data['message']);
//         }
//         throw Exception('Registration failed - Status: ${response.statusCode}');
//       }
//     } on DioException catch (e) {
//       print('DioException during registration: ${e.message}');
//       print('Response data: ${e.response?.data}');
//       // If API is not available, use mock data
//       if (e.type == DioExceptionType.connectionError ||
//           e.type == DioExceptionType.connectionTimeout ||
//           e.response?.statusCode == 404) {
//         print('Using mock data for registration');
//         return _getMockRegisterResponse(firstname, lastname, username);
//       }
//       if (e.response?.statusCode == 409) {
//         throw Exception('Username or email already exists');
//       } else if (e.response?.statusCode == 400) {
//         // Print backend error message if available
//         if (e.response?.data is Map<String, dynamic> &&
//             e.response?.data['message'] != null) {
//           throw Exception(e.response?.data['message']);
//         }
//         throw Exception('Invalid registration data');
//       } else {
//         throw Exception(
//           e.response?.data?['message'] ?? 'Registration failed: ${e.message}',
//         );
//       }
//     } catch (e) {
//       print('General exception during registration: $e');
//       // Fallback to mock data
//       return _getMockRegisterResponse(firstname, lastname, username);
//     }
//   }

//   Map<String, dynamic> _getMockLoginResponse(String username) {
//     return {
//       'user': {
//         'id': '1',
//         'username': username,
//         'email': '$username@example.com',
//         'created_at': DateTime.now().toIso8601String(),
//         'updated_at': DateTime.now().toIso8601String(),
//       },
//       'token': 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
//       'message': 'Login successful (mock data)',
//     };
//   }

//   Map<String, dynamic> _getMockRegisterResponse(
//     String firstname,
//     String lastname,
//     String username,
//   ) {
//     return {
//       'user': {
//         'id': '1',
//         'firstName': firstname,
//         'lastName': lastname,
//         'username': username,
//       },
//       'token': 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
//       'message': 'Registration successful (mock data)',
//     };
//   }

//   Future<void> logout() async {
//     try {
//       if (!_useMockData) {
//         await _dioAuth.post(ApiConfig.logoutEndpoint);
//       }
//       // Clear token from shared preferences
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.remove('auth_token');
//     } on DioException catch (e) {
//       print('Logout error: ${e.message}');
//       // Even if logout fails, clear the token locally
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.remove('auth_token');
//     }
//   }

//   // Security alerts endpoints
//   Future<List<Map<String, dynamic>>> getSecurityAlerts() async {
//     try {
//       if (_useMockData) {
//         return _getMockSecurityAlerts();
//       }

//       final response = await _dioMain.get(ApiConfig.securityAlertsEndpoint);
//       if (response.statusCode == 200) {
//         // Handle different response structures
//         if (response.data is List) {
//           return List<Map<String, dynamic>>.from(response.data);
//         } else if (response.data.containsKey('alerts')) {
//           return List<Map<String, dynamic>>.from(response.data['alerts']);
//         } else {
//           return [];
//         }
//       }
//       throw Exception('Failed to fetch security alerts');
//     } on DioException catch (e) {
//       print('Error fetching security alerts: ${e.message}');
//       // Return mock data
//       return _getMockSecurityAlerts();
//     }
//   }

//   List<Map<String, dynamic>> _getMockSecurityAlerts() {
//     return [
//       {
//         'id': '1',
//         'title': 'Suspicious Email Detected',
//         'description': 'A phishing email was detected in your inbox',
//         'severity': 'high',
//         'type': 'phishing',
//         'timestamp': DateTime.now()
//             .subtract(Duration(hours: 2))
//             .toIso8601String(),
//         'is_resolved': false,
//       },
//       {
//         'id': '2',
//         'title': 'Malware Alert',
//         'description': 'Potential malware detected in downloaded file',
//         'severity': 'critical',
//         'type': 'malware',
//         'timestamp': DateTime.now()
//             .subtract(Duration(hours: 1))
//             .toIso8601String(),
//         'is_resolved': true,
//       },
//     ];
//   }

//   // Future<Map<String, dynamic>> getDashboardStats() async {
//   //   try {
//   //     if (_useMockData) {
//   //       return _getMockDashboardStats();
//   //     }
//   //
//   //     final response = await _dioMain.get(ApiConfig.dashboardStatsEndpoint);
//   //     if (response.statusCode == 200) {
//   //       return response.data;
//   //     }
//   //     throw Exception('Failed to fetch dashboard stats');
//   //   } on DioException catch (e) {
//   //     print('Error fetching dashboard stats: ${e.message}');
//   //     // Return mock data
//   //     return _getMockDashboardStats();
//   //   }
//   // }

//   Map<String, dynamic> _getMockDashboardStats() {
//     return {
//       'total_alerts': 50,
//       'resolved_alerts': 35,
//       'pending_alerts': 15,
//       'alerts_by_type': {'spam': 20, 'malware': 15, 'fraud': 10, 'other': 5},
//       'alerts_by_severity': {'low': 25, 'medium': 15, 'high': 8, 'critical': 2},
//       'threat_trend_data': [30, 35, 40, 50, 45, 38, 42],
//       'threat_bar_data': [10, 20, 15, 30, 25, 20, 10],
//       'risk_score': 75.0,
//     };
//   }

//   Future<Map<String, dynamic>> reportSecurityIssue(
//     Map<String, dynamic> issueData,
//   ) async {
//     try {
//       if (_useMockData) {
//         return {'message': 'Issue reported successfully (mock data)'};
//       }

//       final response = await _dioMain.post(
//         ApiConfig.reportSecurityIssueEndpoint,
//         data: issueData,
//       );
//       if (response.statusCode == 201) {
//         return response.data;
//       }
//       throw Exception('Failed to report security issue');
//     } on DioException catch (e) {
//       print('Error reporting security issue: ${e.message}');
//       return {'message': 'Issue reported successfully (mock data)'};
//     }
//   }

//   Future<List<Map<String, dynamic>>> getThreatHistory({
//     String period = '1D',
//   }) async {
//     try {
//       if (_useMockData) {
//         return _getMockThreatHistory();
//       }

//       final response = await _dioMain.get(
//         ApiConfig.threatHistoryEndpoint,
//         queryParameters: {'period': period},
//       );
//       if (response.statusCode == 200) {
//         if (response.data is List) {
//           return List<Map<String, dynamic>>.from(response.data);
//         } else if (response.data.containsKey('threats')) {
//           return List<Map<String, dynamic>>.from(response.data['threats']);
//         } else {
//           return [];
//         }
//       }
//       throw Exception('Failed to fetch threat history');
//     } on DioException catch (e) {
//       print('Error fetching threat history: ${e.message}');
//       return _getMockThreatHistory();
//     }
//   }

//   List<Map<String, dynamic>> _getMockThreatHistory() {
//     return [
//       {'date': '2024-01-01', 'count': 10},
//       {'date': '2024-01-02', 'count': 15},
//       {'date': '2024-01-03', 'count': 8},
//       {'date': '2024-01-04', 'count': 20},
//       {'date': '2024-01-05', 'count': 12},
//     ];
//   }

//   // User profile endpoints
//   Future<Map<String, dynamic>?> getUserProfile() async {
//     try {
//       if (_useMockData) {
//         return _getMockUserProfile();
//       }

//       final response = await _dioAuth.get(ApiConfig.userProfileEndpoint);

//       print(
//         'response datasssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss$response',
//       );
//       if (response.statusCode == 200) {
//         return response.data;
//       }
//       throw Exception('Failed to fetch user profile');
//     } on DioException catch (e) {
//       print('Error fetching user profile: ${e.message}');
//       // Return mock user data
//       return _getMockUserProfile();
//     }
//   }

//   Map<String, dynamic> _getMockUserProfile() {
//     return {'id': '1', 'username': 'demo_user', 'email': 'demo@example.com'};
//   }

//   Future<Map<String, dynamic>> updateUserProfile(
//     Map<String, dynamic> profileData,
//   ) async {
//     try {
//       if (_useMockData) {
//         return {'message': 'Profile updated successfully (mock data)'};
//       }

//       final response = await _dioAuth.put(
//         ApiConfig.updateProfileEndpoint,
//         data: profileData,
//       );
//       if (response.statusCode == 200) {
//         return response.data;
//       }
//       throw Exception('Failed to update user profile');
//     } on DioException catch (e) {
//       print('Error updating user profile: ${e.message}');
//       return {'message': 'Profile updated successfully (mock data)'};
//     }
//   }

//   Future<List<Map<String, dynamic>>> fetchReportCategories() async {
//     try {
//       final response = await _dioMain.get('/report-category');
//       return List<Map<String, dynamic>>.from(response.data);
//     } catch (e) {
//       print('Error fetching categories: $e');
//       return [];
//     }
//   }

//   Future<List<Map<String, dynamic>>> fetchReportTypesByCategory(
//     String categoryId,
//   ) async {
//     try {
//       final response = await _dioMain.get(
//         '/report-type',
//         queryParameters: {'id': categoryId},
//       );
//       return List<Map<String, dynamic>>.from(response.data);
//     } catch (e) {
//       print('Error fetching types: $e');
//       return [];
//     }
//   }

//   Future<void> submitScamReport(Map<String, dynamic> data) async {
//     try {
//       print('Dio baseUrl: ${_dioMain.options.baseUrl}');
//       print('Dio path: /reports');
//       print('Data: $data');
//       final response = await _dioMain.post('/reports', data: data);
//       print('Backend response: ${response.data}');
//     } catch (e) {
//       print('Error sending to backend: $e');
//     }
//   }

//   Future<List<Map<String, dynamic>>> fetchReportTypes() async {
//     try {
//       final response = await _dioMain.get('/report-type');
//       return List<Map<String, dynamic>>.from(response.data);
//     } catch (e) {
//       print('Error fetching types: $e');
//       return [];
//     }
//   }

//   //Fetch the data in report-type
// }


