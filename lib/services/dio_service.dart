import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';
import '../config/api_config.dart';
import 'jwt_service.dart';
import 'token_storage.dart';
import 'auth_interceptor.dart';

class DioService {
  static final DioService _instance = DioService._internal();

  factory DioService() => _instance;

  late Dio authApi;
  late Dio mainApi;
  late Dio fileUploadApi;
  late Dio reportsApi;

  // A lock to ensure single refresh at once
  final Lock _refreshLock = Lock();
  String? _cachedAccessToken;
  bool _isRefreshing = false;

  DioService._internal() {
    _initClients();
  }

  void _initClients() {
    // Auth API (for authentication endpoints) - Increased timeout for reliability
    authApi = Dio(
      BaseOptions(
        baseUrl: ApiConfig.authBaseUrl,
        connectTimeout: const Duration(seconds: ApiConfig.connectTimeout),
        receiveTimeout: const Duration(seconds: ApiConfig.receiveTimeout),
        contentType: 'application/json',
      ),
    );

    // Main API (for general endpoints)
    mainApi = Dio(
      BaseOptions(
        baseUrl: ApiConfig.mainBaseUrl,
        connectTimeout: const Duration(seconds: ApiConfig.connectTimeout),
        receiveTimeout: const Duration(seconds: ApiConfig.receiveTimeout),
        contentType: 'application/json',
      ),
    );

    // File Upload API (for multipart uploads)
    fileUploadApi = Dio(
      BaseOptions(
        baseUrl: ApiConfig.fileUploadBaseUrl,
        connectTimeout: const Duration(seconds: ApiConfig.connectTimeout),
        receiveTimeout: const Duration(seconds: ApiConfig.receiveTimeout),
        contentType: 'multipart/form-data',
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    // Reports API (for report-specific endpoints)
    reportsApi = Dio(
      BaseOptions(
        baseUrl: ApiConfig.reportsBaseUrl,
        connectTimeout: const Duration(seconds: ApiConfig.connectTimeout),
        receiveTimeout: const Duration(seconds: ApiConfig.receiveTimeout),
        contentType: 'application/json',
      ),
    );

    // Apply unified interceptors to all clients
    _applyUnifiedInterceptors(authApi);
    _applyUnifiedInterceptors(mainApi);
    _applyUnifiedInterceptors(fileUploadApi);
    _applyUnifiedInterceptors(reportsApi);
  }

  void _applyUnifiedInterceptors(Dio dio) {
    // Add AuthInterceptor for token management and logging
    // Pass authApi as the authDio for refresh token requests
    dio.interceptors.add(AuthInterceptor(dio, authDio: authApi));
  }

  Future<void> _handleTokenRefresh(
    DioException error,
    ErrorInterceptorHandler handler,
    Dio dio,
  ) async {
    await _refreshLock.synchronized(() async {
      try {
        if (_isRefreshing) {
          print(
            '🔄 DioService: Token refresh already in progress, skipping...',
          );
          return;
        }
        _isRefreshing = true;
        print('🔄 DioService: Starting token refresh...');
        print('🔄 DioService: Original request: ${error.requestOptions.path}');
        // If token was already refreshed by another waiting request, reuse it
        final currentAccess = await TokenStorage.getAccessToken();
        if (currentAccess != null &&
            currentAccess.isNotEmpty &&
            currentAccess != _cachedAccessToken) {
          print(
            '🔄 DioService: Token already refreshed by another request, reusing...',
          );
          _cachedAccessToken = currentAccess;
          return;
        }

        // Get refresh token
        String? refreshToken = await TokenStorage.getRefreshToken();

        // Fallback to SharedPreferences if secure storage is empty
        if (refreshToken == null || refreshToken.isEmpty) {
          final prefs = await SharedPreferences.getInstance();
          refreshToken = prefs.getString('refresh_token');
        }

        if (refreshToken == null || refreshToken.isEmpty) {
          print('❌ DioService: No refresh token available');
          await _clearAllTokens();
          return handler.next(error);
        }

        // Create a separate Dio instance for refresh request
        final refreshDio = Dio(
          BaseOptions(
            baseUrl: ApiConfig.authBaseUrl,
            contentType: 'application/json',
            connectTimeout: const Duration(seconds: ApiConfig.connectTimeout),
            receiveTimeout: const Duration(seconds: ApiConfig.receiveTimeout),
          ),
        );

        print('🔄 DioService: Making refresh token request...');
        print(
          '🔄 DioService: Refresh token: ${refreshToken.substring(0, 20)}...',
        );
        final refreshResponse = await refreshDio.post(
          '/api/v1/auth/refresh-token',
          data: {'refreshToken': refreshToken},
          options: Options(headers: {'Content-Type': 'application/json'}),
        );
        print(
          '🔄 DioService: Refresh response status: ${refreshResponse.statusCode}',
        );
        print('🔄 DioService: Refresh response data: ${refreshResponse.data}');

        final newAccessToken = refreshResponse.data['access_token'];
        final newRefreshToken = refreshResponse.data['refresh_token'];

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          print('✅ DioService: Token refresh successful');
          // Save new tokens to both storages
          await TokenStorage.setAccessToken(newAccessToken);
          if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
            await TokenStorage.setRefreshToken(newRefreshToken);
          }

          // Also save to JWT service for compatibility
          await JwtService.saveToken(newAccessToken);

          // Save refresh token to SharedPreferences as backup
          final prefs = await SharedPreferences.getInstance();
          if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
            await prefs.setString('refresh_token', newRefreshToken);
          }

          _cachedAccessToken = newAccessToken;

          // Retry original request with new token
          final requestOptions = error.requestOptions;
          requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          requestOptions.extra['retried'] = true;

          try {
            print('🔄 DioService: Retrying original request with new token...');
            final retryResponse = await dio.fetch(requestOptions);
            print('✅ DioService: Retry successful');
            _isRefreshing = false;
            return handler.resolve(retryResponse);
          } catch (retryError) {
            print('❌ DioService: Retry failed: $retryError');
            _isRefreshing = false;
            return handler.next(error);
          }
        } else {
          print('❌ DioService: Invalid refresh response - no access token');
          await _clearAllTokens();
          _isRefreshing = false;
          return handler.next(error);
        }
      } catch (e) {
        print('❌ DioService: Token refresh failed: $e');
        // Check if it's a 401 error on refresh token
        if (e.toString().contains('401')) {
          print('❌ DioService: Refresh token is invalid, clearing tokens');
          await _clearAllTokens();
          _isRefreshing = false;
          // Don't retry, just pass the error through
          return handler.next(error);
        }
        await _clearAllTokens();
        _isRefreshing = false;
        return handler.next(error);
      }
    });
  }

  Future<void> _clearAllTokens() async {
    try {
      print('🗑️ DioService: Clearing all tokens...');
      await TokenStorage.clearAllTokens();
      await JwtService.clearToken();

      // Clear from SharedPreferences as well
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('refresh_token');
      await prefs.remove('id_token');
      print('✅ DioService: All tokens cleared successfully');
    } catch (e) {
      print('❌ DioService: Error clearing tokens: $e');
    }
  }

  // Helper methods for common API operations
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return await mainApi.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return await mainApi.post(
      path,
      data: data,
      queryParameters: queryParameters,
    );
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return await mainApi.put(
      path,
      data: data,
      queryParameters: queryParameters,
    );
  }

  Future<Response> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return await mainApi.delete(path, queryParameters: queryParameters);
  }

  // Auth-specific methods
  Future<Response> authGet(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return await authApi.get(path, queryParameters: queryParameters);
  }

  Future<Response> authPost(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return await authApi.post(
      path,
      data: data,
      queryParameters: queryParameters,
    );
  }

  Future<Response> authPut(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return await authApi.put(
      path,
      data: data,
      queryParameters: queryParameters,
    );
  }

  // File upload method
  Future<Response> uploadFile(String path, FormData formData) async {
    return await fileUploadApi.post(path, data: formData);
  }

  // Reports-specific methods
  Future<Response> reportsGet(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return await reportsApi.get(path, queryParameters: queryParameters);
  }

  Future<Response> reportsPost(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return await reportsApi.post(
      path,
      data: data,
      queryParameters: queryParameters,
    );
  }

  Future<Response> reportsPut(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return await reportsApi.put(
      path,
      data: data,
      queryParameters: queryParameters,
    );
  }

  // Utility method to create FormData for file uploads
  static Future<FormData> createFormData({
    required String filePath,
    String? fieldName = 'file',
    String? fileName,
    Map<String, dynamic>? additionalFields,
  }) async {
    final formData = FormData();

    // Add file
    formData.files.add(
      MapEntry(
        fieldName!,
        await MultipartFile.fromFile(
          filePath,
          filename: fileName ?? filePath.split('/').last,
        ),
      ),
    );

    // Add additional fields
    if (additionalFields != null) {
      formData.fields.addAll(
        additionalFields.entries.map(
          (e) => MapEntry(e.key, e.value.toString()),
        ),
      );
    }

    return formData;
  }

  // Test method to verify interceptor functionality
  Future<void> testInterceptor() async {
    try {
      // Test 1: Check if token is attached to requests

      final token = await TokenStorage.getAccessToken();

      // Test 2: Make a request to see interceptor logs

      // Removed dashboard stats call - endpoint doesn't exist
    } catch (e) {
      // Test 3: Check if 401 handling works
      if (e.toString().contains('401')) {
        final newToken = await TokenStorage.getAccessToken();
        print(
          'Token after 401: ${newToken != null ? 'Present' : 'Not present'}',
        );
      }
    }
  }
}

// Global instance
final dioService = DioService();

// Example usage functions (you can remove these if not needed)
Future<void> fetchUsers() async {
  try {
    final response = await dioService.get('/users');
  } catch (e) {}
}

Future<void> uploadImage(String imagePath) async {
  try {
    final formData = await DioService.createFormData(
      filePath: imagePath,
      fieldName: 'file',
      fileName: 'upload.jpg',
    );

    final response = await dioService.uploadFile('/upload', formData);
  } catch (e) {}
}

// import 'package:dio/dio.dart';
// import 'package:dio_cookie_manager/dio_cookie_manager.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:synchronized/synchronized.dart';
// import '../config/api_config.dart';
// import 'jwt_service.dart';
// import 'token_storage.dart';

// class DioService {
//   static final DioService _instance = DioService._internal();

//   factory DioService() => _instance;

//   late Dio authApi;
//   late Dio mainApi;
//   late Dio fileUploadApi;
//   late Dio reportsApi;

//   // A lock to ensure single refresh at once
//   final Lock _refreshLock = Lock();
//   String? _cachedAccessToken;

//   DioService._internal() {
//     _initClients();
//   }

//   void _initClients() {
//     // Auth API (for authentication endpoints)
//     authApi = Dio(
//       BaseOptions(
//         baseUrl: ApiConfig.authBaseUrl,
//         connectTimeout: const Duration(seconds: ApiConfig.connectTimeout),
//         receiveTimeout: const Duration(seconds: ApiConfig.receiveTimeout),
//         contentType: 'application/json',
//       ),
//     );

//     // Main API (for general endpoints)
//     mainApi = Dio(
//       BaseOptions(
//         baseUrl: ApiConfig.mainBaseUrl,
//         connectTimeout: const Duration(seconds: ApiConfig.connectTimeout),
//         receiveTimeout: const Duration(seconds: ApiConfig.receiveTimeout),
//         contentType: 'application/json',
//       ),
//     );

//     // File Upload API (for multipart uploads)
//     fileUploadApi = Dio(
//       BaseOptions(
//         baseUrl: ApiConfig.fileUploadBaseUrl,
//         connectTimeout: const Duration(seconds: ApiConfig.connectTimeout),
//         receiveTimeout: const Duration(seconds: ApiConfig.receiveTimeout),
//         contentType: 'multipart/form-data',
//         validateStatus: (status) => status != null && status < 500,
//       ),
//     );

//     // Reports API (for report-specific endpoints)
//     reportsApi = Dio(
//       BaseOptions(
//         baseUrl: ApiConfig.reportsBaseUrl,
//         connectTimeout: const Duration(seconds: ApiConfig.connectTimeout),
//         receiveTimeout: const Duration(seconds: ApiConfig.receiveTimeout),
//         contentType: 'application/json',
//       ),
//     );

//     // Apply unified interceptors to all clients
//     _applyUnifiedInterceptors(authApi);
//     _applyUnifiedInterceptors(mainApi);
//     _applyUnifiedInterceptors(fileUploadApi);
//     _applyUnifiedInterceptors(reportsApi);
//   }

//   void _applyUnifiedInterceptors(Dio dio) {
//     // Add CookieManager interceptor for cookie handling
//     dio.interceptors.add(CookieManager(TokenStorage.cookieJar));

//     dio.interceptors.add(
//       InterceptorsWrapper(
//         onRequest: (options, handler) async {
//           try {
//             // Add default headers
//             options.headers.addAll(ApiConfig.defaultHeaders);

//             // Add authorization token from secure storage with fallback
//             String? accessToken = await TokenStorage.getAccessToken();

//             // Fallback to JWT service if secure storage is empty
//             if (accessToken == null || accessToken.isEmpty) {
//               accessToken = await JwtService.getTokenWithFallback();
//             }

//             if (accessToken != null && accessToken.isNotEmpty) {
//               options.headers['Authorization'] = 'Bearer $accessToken';
//             }

//             // Add logging if enabled
//             if (ApiConfig.enableLogging) {
//               print('🌐 API Request: ${options.method} ${options.path}');
//               print('🌐 Full URL: ${options.uri}');
//               print('🌐 Base URL: ${ApiConfig.authBaseUrl}');
//               print('📋 Headers: ${options.headers}');
//               if (options.data != null) {
//                 print('📦 Data: ${options.data}');
//               }
//             }

//             handler.next(options);
//           } catch (e) {
//             print('❌ Error in request interceptor: $e');
//             handler.next(options); // still proceed
//           }
//         },
//         onResponse: (response, handler) {
//           if (ApiConfig.enableLogging) {
//             print(
//               '✅ API Response: ${response.statusCode} ${response.requestOptions.path}',
//             );
//             print('📄 Response Data: ${response.data}');
//           }
//           handler.next(response);
//         },
//         onError: (DioException error, handler) async {
//           if (ApiConfig.enableLogging) {
//             print(
//               '❌ API Error: ${error.response?.statusCode} ${error.requestOptions.path}',
//             );
//             print('🌐 Full Error URL: ${error.requestOptions.uri}');
//             print('🚨 Error Message: ${error.message}');
//             print('📄 Error Response: ${error.response?.data}');
//             print('📋 Error Headers: ${error.response?.headers}');
//             print('📦 Error Request Data: ${error.requestOptions.data}');
//           }

//           // Handle 401 Unauthorized with token refresh
//           if (error.response?.statusCode == 401 &&
//               !error.requestOptions.extra.containsKey('retried')) {
//             await _handleTokenRefresh(error, handler, dio);
//           } else {
//             handler.next(error);
//           }
//         },
//       ),
//     );
//   }

//   Future<void> _handleTokenRefresh(
//     DioException error,
//     ErrorInterceptorHandler handler,
//     Dio dio,
//   ) async {
//     await _refreshLock.synchronized(() async {
//       try {
//         print('🔄 Attempting token refresh...');

//         // If token was already refreshed by another waiting request, reuse it
//         final currentAccess = await TokenStorage.getAccessToken();
//         if (currentAccess != null &&
//             currentAccess.isNotEmpty &&
//             currentAccess != _cachedAccessToken) {
//           _cachedAccessToken = currentAccess;
//           return;
//         }

//         // Get refresh token
//         String? refreshToken = await TokenStorage.getRefreshToken();

//         // Fallback to SharedPreferences if secure storage is empty
//         if (refreshToken == null || refreshToken.isEmpty) {
//           final prefs = await SharedPreferences.getInstance();
//           refreshToken = prefs.getString('refresh_token');
//         }

//         if (refreshToken == null || refreshToken.isEmpty) {
//           print('❌ No refresh token available');
//           await _clearAllTokens();
//           return handler.next(error);
//         }

//         // Create a separate Dio instance for refresh request
//         final refreshDio = Dio(
//           BaseOptions(
//             baseUrl: ApiConfig.authBaseUrl,
//             contentType: 'application/json',
//             connectTimeout: const Duration(seconds: ApiConfig.connectTimeout),
//             receiveTimeout: const Duration(seconds: ApiConfig.receiveTimeout),
//           ),
//         );

//         final refreshResponse = await refreshDio.post(
//           '/auth/refresh-token',
//           data: {'refreshToken': refreshToken},
//           options: Options(headers: {'Content-Type': 'application/json'}),
//         );

//         final newAccessToken = refreshResponse.data['access_token'];
//         final newRefreshToken = refreshResponse.data['refresh_token'];

//         if (newAccessToken != null && newAccessToken.isNotEmpty) {
//           // Save new tokens to both storages
//           await TokenStorage.setAccessToken(newAccessToken);
//           if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
//             await TokenStorage.setRefreshToken(newRefreshToken);
//           }

//           // Also save to JWT service for compatibility
//           await JwtService.saveToken(newAccessToken);

//           // Save refresh token to SharedPreferences as backup
//           final prefs = await SharedPreferences.getInstance();
//           if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
//             await prefs.setString('refresh_token', newRefreshToken);
//           }

//           _cachedAccessToken = newAccessToken;
//           print('✅ Token refresh successful');

//           // Retry original request with new token
//           final requestOptions = error.requestOptions;
//           requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
//           requestOptions.extra['retried'] = true;

//           try {
//             final retryResponse = await dio.fetch(requestOptions);
//             return handler.resolve(retryResponse);
//           } catch (retryError) {
//             print('❌ Retry request failed: $retryError');
//             return handler.next(error);
//           }
//         } else {
//           print('❌ Invalid refresh response');
//           await _clearAllTokens();
//           return handler.next(error);
//         }
//       } catch (e) {
//         print('❌ Token refresh failed: $e');
//         await _clearAllTokens();
//         return handler.next(error);
//       }
//     });
//   }

//   Future<void> _clearAllTokens() async {
//     try {
//       await TokenStorage.clearAllTokens();
//       await JwtService.clearToken();

//       // Clear from SharedPreferences as well
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.remove('auth_token');
//       await prefs.remove('refresh_token');
//       await prefs.remove('id_token');

//       print('🗑️ All tokens cleared');
//     } catch (e) {
//       print('❌ Error clearing tokens: $e');
//     }
//   }

//   // Helper methods for common API operations
//   Future<Response> get(
//     String path, {
//     Map<String, dynamic>? queryParameters,
//   }) async {
//     return await mainApi.get(path, queryParameters: queryParameters);
//   }

//   Future<Response> post(
//     String path, {
//     dynamic data,
//     Map<String, dynamic>? queryParameters,
//   }) async {
//     return await mainApi.post(
//       path,
//       data: data,
//       queryParameters: queryParameters,
//     );
//   }

//   Future<Response> put(
//     String path, {
//     dynamic data,
//     Map<String, dynamic>? queryParameters,
//   }) async {
//     return await mainApi.put(
//       path,
//       data: data,
//       queryParameters: queryParameters,
//     );
//   }

//   Future<Response> delete(
//     String path, {
//     Map<String, dynamic>? queryParameters,
//   }) async {
//     return await mainApi.delete(path, queryParameters: queryParameters);
//   }

//   // Auth-specific methods
//   Future<Response> authGet(
//     String path, {
//     Map<String, dynamic>? queryParameters,
//   }) async {
//     return await authApi.get(path, queryParameters: queryParameters);
//   }

//   Future<Response> authPost(
//     String path, {
//     dynamic data,
//     Map<String, dynamic>? queryParameters,
//   }) async {
//     return await authApi.post(
//       path,
//       data: data,
//       queryParameters: queryParameters,
//     );
//   }

//   Future<Response> authPut(
//     String path, {
//     dynamic data,
//     Map<String, dynamic>? queryParameters,
//   }) async {
//     return await authApi.put(
//       path,
//       data: data,
//       queryParameters: queryParameters,
//     );
//   }

//   // File upload method
//   Future<Response> uploadFile(String path, FormData formData) async {
//     return await fileUploadApi.post(path, data: formData);
//   }

//   // Reports-specific methods
//   Future<Response> reportsGet(
//     String path, {
//     Map<String, dynamic>? queryParameters,
//   }) async {
//     return await reportsApi.get(path, queryParameters: queryParameters);
//   }

//   Future<Response> reportsPost(
//     String path, {
//     dynamic data,
//     Map<String, dynamic>? queryParameters,
//   }) async {
//     return await reportsApi.post(
//       path,
//       data: data,
//       queryParameters: queryParameters,
//     );
//   }

//   // Utility method to create FormData for file uploads
//   static Future<FormData> createFormData({
//     required String filePath,
//     String? fieldName = 'file',
//     String? fileName,
//     Map<String, dynamic>? additionalFields,
//   }) async {
//     final formData = FormData();

//     // Add file
//     formData.files.add(
//       MapEntry(
//         fieldName!,
//         await MultipartFile.fromFile(
//           filePath,
//           filename: fileName ?? filePath.split('/').last,
//         ),
//       ),
//     );

//     // Add additional fields
//     if (additionalFields != null) {
//       formData.fields.addAll(
//         additionalFields.entries.map(
//           (e) => MapEntry(e.key, e.value.toString()),
//         ),
//       );
//     }

//     return formData;
//   }

//   // Test method to verify interceptor functionality
//   Future<void> testInterceptor() async {
//     print('🔍 Testing Unified Interceptor...');

//     try {
//       // Test 1: Check if token is attached to requests
//       print('📝 Test 1: Checking token attachment...');
//       final token = await TokenStorage.getAccessToken();
//       print('Current token: ${token != null ? 'Present' : 'Not present'}');

//       // Test 2: Make a request to see interceptor logs
//       print('📝 Test 2: Making test request...');
//       final response = await mainApi.get('/dashboard/stats');
//       print('✅ Test request successful: ${response.statusCode}');
//     } catch (e) {
//       print('❌ Test failed: $e');

//       // Test 3: Check if 401 handling works
//       if (e.toString().contains('401')) {
//         print('📝 Test 3: 401 error detected - checking refresh logic...');
//         final newToken = await TokenStorage.getAccessToken();
//         print(
//           'Token after 401: ${newToken != null ? 'Present' : 'Not present'}',
//         );
//       }
//     }
//   }
// }

// // Global instance
// final dioService = DioService();

// // Example usage functions (you can remove these if not needed)
// Future<void> fetchUsers() async {
//   try {
//     final response = await dioService.get('/users');
//     print('Users: ${response.data}');
//   } catch (e) {
//     print("Error fetching users: $e");
//   }
// }

// Future<void> uploadImage(String imagePath) async {
//   try {
//     final formData = await DioService.createFormData(
//       filePath: imagePath,
//       fieldName: 'file',
//       fileName: 'upload.jpg',
//     );

//     final response = await dioService.uploadFile('/upload', formData);
//     print('Upload response: ${response.data}');
//   } catch (e) {
//     print("Error uploading image: $e");
//   }
// }
