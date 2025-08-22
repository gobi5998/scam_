import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import '../models/scam_report_model.dart';
import '../models/fraud_report_model.dart';
import '../models/malware_report_model.dart';
import '../screens/scam/scam_report_service.dart';
import '../screens/Fraud/fraud_report_service.dart';
import '../screens/malware/malware_report_service.dart';
import '../services/dio_service.dart';
import '../config/api_config.dart';

class TokenStorage {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: const AndroidOptions(encryptedSharedPreferences: true),
  );

  // Access Token
  static Future<void> setAccessToken(String token) async {
    await _secureStorage.write(key: _accessTokenKey, value: token);
    print(
      '💾 TokenStorage: Setting access token: ${token.substring(0, token.length > 20 ? 20 : token.length)}...',
    );
  }

  static Future<String?> getAccessToken() async {
    final token = await _secureStorage.read(key: _accessTokenKey);
    print('🔍 TokenStorage: Getting access token: ${token ?? 'null'}');
    return token;
  }

  static Future<void> removeAccessToken() async {
    await _secureStorage.delete(key: _accessTokenKey);
  }

  // Refresh Token
  static Future<void> setRefreshToken(String token) async {
    await _secureStorage.write(key: _refreshTokenKey, value: token);
    print(
      '💾 TokenStorage: Setting refresh token: ${token.substring(0, token.length > 20 ? 20 : token.length)}...',
    );
  }

  static Future<String?> getRefreshToken() async {
    final token = await _secureStorage.read(key: _refreshTokenKey);
    print('🔍 TokenStorage: Getting refresh token: ${token ?? 'null'}');
    return token;
  }

  static Future<void> removeRefreshToken() async {
    await _secureStorage.delete(key: _refreshTokenKey);
  }

  // Clear All Tokens
  static Future<void> clearAllTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    print('🗑️ TokenStorage: All tokens cleared');
  }

  // Test method to verify storage is working
  static Future<void> testStorage() async {
    print('🧪 TokenStorage: Testing secure storage...');

    // Test writing and reading
    const testToken = 'test_token_12345';
    await setAccessToken(testToken);

    final retrievedToken = await getAccessToken();
    print('🧪 TokenStorage: Test token retrieved: $retrievedToken');
    print('🧪 TokenStorage: Test passed: ${retrievedToken == testToken}');

    // Clean up
    await removeAccessToken();
  }

  // Cookie Handling (keeping for compatibility)
  static Future<void> clearCookies() async {
    // No-op for secure storage
  }

  // Diagnostic method to check token status
  static Future<void> diagnoseTokenStorage() async {
    print('🔍 TokenStorage: Running diagnostics...');

    final accessToken = await getAccessToken();
    final refreshToken = await getRefreshToken();

    print(
      '🔍 TokenStorage: Access token present: ${accessToken != null && accessToken.isNotEmpty}',
    );
    print(
      '🔍 TokenStorage: Refresh token present: ${refreshToken != null && refreshToken.isNotEmpty}',
    );

    if (accessToken == null || accessToken.isEmpty) {
      print('❌ TokenStorage: Access token is missing or empty');
    }

    if (refreshToken == null || refreshToken.isEmpty) {
      print('❌ TokenStorage: Refresh token is missing or empty');
      print('💡 TokenStorage: You need to re-login to get fresh tokens');
    }
  }

  // Check if tokens are valid for sync
  static Future<bool> areTokensValid() async {
    final accessToken = await getAccessToken();
    final refreshToken = await getRefreshToken();

    return accessToken != null &&
        accessToken.isNotEmpty &&
        refreshToken != null &&
        refreshToken.isNotEmpty;
  }

  // Check if access token is expired (JWT expiration check)
  static Future<bool> isAccessTokenExpired() async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        return true; // No token means expired
      }

      // Decode JWT to check expiration
      final parts = accessToken.split('.');
      if (parts.length != 3) {
        return true; // Invalid JWT format
      }

      // Decode payload
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(resp);

      // Check expiration
      final exp = payloadMap['exp'];
      if (exp == null) {
        return true; // No expiration claim
      }

      final expirationTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final currentTime = DateTime.now();

      // Add 5-minute buffer for safety
      final bufferTime = currentTime.add(const Duration(minutes: 5));

      return expirationTime.isBefore(bufferTime);
    } catch (e) {
      print('❌ TokenStorage: Error checking token expiration: $e');
      return true; // Assume expired on error
    }
  }

  // Check if refresh token is expired
  static Future<bool> isRefreshTokenExpired() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return true; // No token means expired
      }

      // For refresh tokens, we'll try to use them and see if they work
      // This is more reliable than trying to decode them
      return false; // Assume valid, will be tested when used
    } catch (e) {
      print('❌ TokenStorage: Error checking refresh token: $e');
      return true;
    }
  }

  // Comprehensive token validation
  static Future<Map<String, dynamic>> validateTokens() async {
    try {
      final accessToken = await getAccessToken();
      final refreshToken = await getRefreshToken();

      final hasAccessToken = accessToken != null && accessToken.isNotEmpty;
      final hasRefreshToken = refreshToken != null && refreshToken.isNotEmpty;

      if (!hasAccessToken && !hasRefreshToken) {
        return {
          'valid': false,
          'reason': 'no_tokens',
          'message': 'No tokens available. Please login.',
          'action': 'login',
        };
      }

      if (!hasRefreshToken) {
        return {
          'valid': false,
          'reason': 'no_refresh_token',
          'message': 'No refresh token available. Please login.',
          'action': 'login',
        };
      }

      final isAccessExpired = await isAccessTokenExpired();

      if (isAccessExpired) {
        return {
          'valid': false,
          'reason': 'access_expired',
          'message': 'Access token expired. Attempting refresh...',
          'action': 'refresh',
        };
      }

      return {
        'valid': true,
        'reason': 'valid',
        'message': 'Tokens are valid',
        'action': 'continue',
      };
    } catch (e) {
      return {
        'valid': false,
        'reason': 'error',
        'message': 'Error validating tokens: $e',
        'action': 'login',
      };
    }
  }

  // Force clear tokens to trigger re-login
  static Future<void> forceReLogin() async {
    print('🔄 TokenStorage: Forcing re-login by clearing tokens...');
    await clearAllTokens();
    print('✅ TokenStorage: Tokens cleared. User must re-login.');
  }

  // Robust token refresh with retry logic
  static Future<Map<String, dynamic>> refreshTokensWithRetry({
    int maxRetries = 3,
  }) async {
    try {
      print('🔄 TokenStorage: Starting robust token refresh...');

      final refreshToken = await getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        print('❌ TokenStorage: No refresh token available');
        return {
          'success': false,
          'reason': 'no_refresh_token',
          'message': 'No refresh token available for refresh',
        };
      }

      print('🔄 TokenStorage: Refresh token length: ${refreshToken.length}');

      // Try multiple times with different timeouts
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          print('🔄 TokenStorage: Attempt $attempt of $maxRetries...');

          // Create a dedicated Dio instance with shorter timeout for auth
          final authDio = Dio(
            BaseOptions(
              baseUrl: ApiConfig.authBaseUrl,
              connectTimeout: Duration(
                seconds: 5 + attempt,
              ), // Increasing timeout
              receiveTimeout: Duration(
                seconds: 5 + attempt,
              ), // Increasing timeout
              contentType: 'application/json',
            ),
          );

          final response = await authDio.post(
            ApiConfig.refreshTokenEndpoint,
            data: {"refresh_token": refreshToken},
            options: Options(
              headers: {'Content-Type': 'application/json'},
              validateStatus: (status) => status != null && status < 500,
            ),
          );

          print(
            '🔄 TokenStorage: Refresh response status: ${response.statusCode}',
          );
          print('🔄 TokenStorage: Refresh response data: ${response.data}');

          // Accept both 200 and 201 status codes
          if ((response.statusCode == 200 || response.statusCode == 201) &&
              response.data != null) {
            print('🔍 TokenStorage: Checking response data structure...');

            // Log the response structure for debugging
            if (response.data is Map) {
              print(
                '🔍 TokenStorage: Response keys: ${response.data.keys.toList()}',
              );
            }

            // Try different possible field names
            String? newAccessToken =
                response.data["access_token"] ??
                response.data["accessToken"] ??
                response.data["token"] ??
                response.data["access"];

            String? newRefreshToken =
                response.data["refresh_token"] ??
                response.data["refreshToken"] ??
                response.data["refresh"];

            print(
              '🔍 TokenStorage: Access token present: ${newAccessToken != null}',
            );
            print(
              '🔍 TokenStorage: Refresh token present: ${newRefreshToken != null}',
            );

            if (newAccessToken != null && newRefreshToken != null) {
              await setAccessToken(newAccessToken);
              await setRefreshToken(newRefreshToken);
              print(
                '✅ TokenStorage: Tokens refreshed successfully on attempt $attempt',
              );
              print(
                '✅ TokenStorage: New access token length: ${newAccessToken.length}',
              );
              print(
                '✅ TokenStorage: New refresh token length: ${newRefreshToken.length}',
              );

              return {
                'success': true,
                'reason': 'success',
                'message': 'Tokens refreshed successfully',
                'attempt': attempt,
              };
            } else {
              print('❌ TokenStorage: Missing token fields in response');
              print('❌ TokenStorage: Expected access_token and refresh_token');
              print('❌ TokenStorage: Got: ${response.data}');
            }
          } else {
            print('❌ TokenStorage: Invalid response status or data');
            print('❌ TokenStorage: Status: ${response.statusCode}');
            print('❌ TokenStorage: Data: ${response.data}');
          }

          print('❌ TokenStorage: Invalid response on attempt $attempt');
        } catch (e) {
          print('❌ TokenStorage: Error on attempt $attempt: $e');

          // Check if it's a timeout error
          if (e.toString().contains('timeout') ||
              e.toString().contains('408')) {
            print('⏰ TokenStorage: Backend timeout on attempt $attempt');
            if (attempt < maxRetries) {
              print('🔄 TokenStorage: Retrying with longer timeout...');
              await Future.delayed(
                Duration(seconds: attempt),
              ); // Exponential backoff
              continue;
            }
          }

          // If it's the last attempt, return error
          if (attempt == maxRetries) {
            return {
              'success': false,
              'reason': 'max_retries_exceeded',
              'message':
                  'Failed to refresh tokens after $maxRetries attempts: $e',
            };
          }
        }
      }

      return {
        'success': false,
        'reason': 'unknown_error',
        'message': 'Unknown error during token refresh',
      };
    } catch (e) {
      print('❌ TokenStorage: Critical error in token refresh: $e');
      return {
        'success': false,
        'reason': 'critical_error',
        'message': 'Critical error: $e',
      };
    }
  }

  // Force refresh tokens using refresh token (legacy method for compatibility)
  static Future<bool> forceRefreshTokens() async {
    final result = await refreshTokensWithRetry();
    return result['success'] == true;
  }

  // Test backend response format
  static Future<Map<String, dynamic>> testBackendResponse() async {
    try {
      print('🧪 TokenStorage: Testing backend response format...');

      final refreshToken = await getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return {
          'success': false,
          'message': 'No refresh token available for testing',
        };
      }

      // Create a test Dio instance
      final authDio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.authBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          contentType: 'application/json',
        ),
      );

      final response = await authDio.post(
        ApiConfig.refreshTokenEndpoint,
        data: {"refresh_token": refreshToken},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      print('🧪 TokenStorage: Test response status: ${response.statusCode}');
      print('🧪 TokenStorage: Test response data: ${response.data}');
      print(
        '🧪 TokenStorage: Test response type: ${response.data.runtimeType}',
      );

      if (response.data is Map) {
        print('🧪 TokenStorage: Response keys: ${response.data.keys.toList()}');

        // Check for different possible token field names
        final possibleAccessFields = [
          'access_token',
          'accessToken',
          'token',
          'access',
        ];
        final possibleRefreshFields = [
          'refresh_token',
          'refreshToken',
          'refresh',
        ];

        for (final field in possibleAccessFields) {
          if (response.data.containsKey(field)) {
            print('🧪 TokenStorage: Found access token in field: $field');
          }
        }

        for (final field in possibleRefreshFields) {
          if (response.data.containsKey(field)) {
            print('🧪 TokenStorage: Found refresh token in field: $field');
          }
        }
      }

      return {
        'success': true,
        'status': response.statusCode,
        'data': response.data,
        'message': 'Backend response test completed',
      };
    } catch (e) {
      print('❌ TokenStorage: Error testing backend response: $e');
      return {
        'success': false,
        'message': 'Error testing backend response: $e',
      };
    }
  }

  // Comprehensive token management system
  static Future<Map<String, dynamic>> manageTokensForSync() async {
    try {
      print('🔧 TokenStorage: Managing tokens for sync...');

      // Step 1: Validate current tokens
      final validation = await validateTokens();
      print('🔍 TokenStorage: Validation result: ${validation['reason']}');

      if (validation['valid']) {
        print('✅ TokenStorage: Tokens are valid, proceeding with sync');
        return {
          'success': true,
          'action': 'continue',
          'message': 'Tokens are valid',
        };
      }

      // Step 2: Handle different validation failures
      switch (validation['reason']) {
        case 'no_tokens':
        case 'no_refresh_token':
          return {
            'success': false,
            'action': 'login',
            'message': 'No valid tokens available. Please login.',
            'reason': validation['reason'],
          };

        case 'access_expired':
          print('🔄 TokenStorage: Access token expired, attempting refresh...');
          final refreshResult = await refreshTokensWithRetry();

          if (refreshResult['success']) {
            print('✅ TokenStorage: Token refresh successful');
            return {
              'success': true,
              'action': 'continue',
              'message': 'Tokens refreshed successfully',
              'reason': 'refreshed',
            };
          } else {
            print(
              '❌ TokenStorage: Token refresh failed: ${refreshResult['reason']}',
            );

            // If refresh failed due to backend timeout, try again with longer timeout
            if (refreshResult['reason'] == 'max_retries_exceeded') {
              print('🔄 TokenStorage: Trying with longer timeout...');
              final retryResult = await refreshTokensWithRetry(maxRetries: 5);

              if (retryResult['success']) {
                return {
                  'success': true,
                  'action': 'continue',
                  'message': 'Tokens refreshed after retry',
                  'reason': 'refreshed_after_retry',
                };
              }
            }

            return {
              'success': false,
              'action': 'login',
              'message': 'Token refresh failed. Please login.',
              'reason': refreshResult['reason'],
            };
          }

        default:
          return {
            'success': false,
            'action': 'login',
            'message': validation['message'],
            'reason': validation['reason'],
          };
      }
    } catch (e) {
      print('❌ TokenStorage: Error in token management: $e');
      return {
        'success': false,
        'action': 'login',
        'message': 'Error managing tokens: $e',
        'reason': 'error',
      };
    }
  }

  // Handle backend timeout issues specifically
  static Future<Map<String, dynamic>> handleBackendTimeout() async {
    try {
      print('🔧 TokenStorage: Handling backend timeout issue...');

      // First, check if we have valid tokens
      final hasValidTokens = await areTokensValid();
      if (!hasValidTokens) {
        return {
          'success': false,
          'message': 'No valid tokens available. Please re-login.',
          'action': 're_login',
        };
      }

      // Try to refresh tokens with very short timeout
      print('🔄 TokenStorage: Attempting token refresh with short timeout...');
      final refreshSuccess = await forceRefreshTokens();

      if (refreshSuccess) {
        return {
          'success': true,
          'message': 'Tokens refreshed successfully despite backend timeout.',
          'action': 'continue',
        };
      } else {
        return {
          'success': false,
          'message':
              'Backend timeout issue detected. Please re-login for fresh tokens.',
          'action': 're_login',
          'reason': 'backend_timeout',
        };
      }
    } catch (e) {
      print('❌ TokenStorage: Error handling backend timeout: $e');
      return {
        'success': false,
        'message': 'Error handling timeout: $e',
        'action': 're_login',
      };
    }
  }

  // Update offline reports with fresh tokens
  static Future<bool> updateOfflineReportsWithFreshTokens() async {
    try {
      print('🔧 TokenStorage: Updating offline reports with fresh tokens...');

      // Check if we have valid tokens
      final accessToken = await getAccessToken();
      final refreshToken = await getRefreshToken();

      if (accessToken == null ||
          accessToken.isEmpty ||
          refreshToken == null ||
          refreshToken.isEmpty) {
        print(
          '❌ TokenStorage: No valid tokens available for offline report update',
        );
        return false;
      }

      print('✅ TokenStorage: Valid tokens found, updating offline reports...');

      // Update scam reports
      final scamBox = Hive.box<ScamReportModel>('scam_reports');
      int updatedScamReports = 0;

      for (var report in scamBox.values) {
        if (report.isSynced != true) {
          // Update the report with fresh tokens by re-syncing
          final success = await ScamReportService.sendToBackend(report);
          if (success) {
            updatedScamReports++;
            print('✅ TokenStorage: Updated scam report ${report.id}');
          }
        }
      }

      // Update fraud reports
      final fraudBox = Hive.box<FraudReportModel>('fraud_reports');
      int updatedFraudReports = 0;

      for (var report in fraudBox.values) {
        if (report.isSynced != true) {
          // Update the report with fresh tokens by re-syncing
          final success = await FraudReportService.sendToBackend(report);
          if (success) {
            updatedFraudReports++;
            print('✅ TokenStorage: Updated fraud report ${report.id}');
          }
        }
      }

      // Update malware reports
      final malwareBox = Hive.box<MalwareReportModel>('malware_reports');
      int updatedMalwareReports = 0;

      for (var report in malwareBox.values) {
        if (report.isSynced != true) {
          // Update the report with fresh tokens by re-syncing
          final success = await MalwareReportService.sendToBackend(report);
          if (success) {
            updatedMalwareReports++;
            print('✅ TokenStorage: Updated malware report ${report.id}');
          }
        }
      }

      final totalUpdated =
          updatedScamReports + updatedFraudReports + updatedMalwareReports;
      print(
        '✅ TokenStorage: Successfully updated $totalUpdated offline reports with fresh tokens',
      );
      print(
        '📊 TokenStorage: - Scam: $updatedScamReports, Fraud: $updatedFraudReports, Malware: $updatedMalwareReports',
      );

      return totalUpdated > 0;
    } catch (e) {
      print(
        '❌ TokenStorage: Error updating offline reports with fresh tokens: $e',
      );
      return false;
    }
  }
}
