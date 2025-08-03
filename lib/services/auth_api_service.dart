import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import '../config/api_config.dart';
import 'token_storage.dart';
import 'dio_service.dart';

class AuthApiService {
  static final DioService _dioService = DioService();

  // Authentication methods using unified DioService
  static Future<Response> login(String email, String password) async {
    return await _dioService.authPost(
      ApiConfig.loginEndpoint,
      data: {'username': email, 'password': password},
    );
  }

  static Future<Response> register(Map<String, dynamic> userData) async {
    return await _dioService.authPost('/auth/create-user', data: userData);
  }

  static Future<Response> logout() async {
    final response = await _dioService.authPost('/auth/logout');
    await TokenStorage.clearAllTokens();
    await TokenStorage.clearCookies();
    return response;
  }

  static Future<Response> refreshToken() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw Exception('No refresh token available');
    }

    return await _dioService.authPost(
      '/auth/refresh-token',
      data: {'refreshToken': refreshToken},
    );
  }

  static Future<Response> getUserProfile() async {
    return await _dioService.authGet('/user/me');
  }

  static Future<Response> updateProfile(
    Map<String, dynamic> profileData,
  ) async {
    return await _dioService.authPut('/auth/profile', data: profileData);
  }

  static Future<Response> forgotPassword(String email) async {
    return await _dioService.authPost(
      '/auth/forgot-password',
      data: {'email': email},
    );
  }

  static Future<Response> resetPassword(
    String token,
    String newPassword,
  ) async {
    return await _dioService.authPost(
      '/auth/reset-password',
      data: {'token': token, 'newPassword': newPassword},
    );
  }

  static Future<Response> verifyEmail(String token) async {
    return await _dioService.authPost(
      '/auth/verify-email',
      data: {'token': token},
    );
  }

  static Future<Response> resendVerificationEmail(String email) async {
    return await _dioService.authPost(
      '/auth/resend-verification',
      data: {'email': email},
    );
  }

  static Future<Response> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    return await _dioService.authPost(
      '/auth/change-password',
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  static Future<Response> deleteAccount(String password) async {
    return await _dioService.authPost(
      '/auth/delete-account',
      data: {'password': password},
    );
  }

  static Future<Response> getSessionInfo() async {
    return await _dioService.authGet('/auth/session');
  }

  static Future<Response> revokeAllSessions() async {
    return await _dioService.authPost('/auth/revoke-all-sessions');
  }

  static Future<Response> getLoginHistory() async {
    return await _dioService.authGet('/auth/login-history');
  }

  static Future<Response> enableTwoFactor() async {
    return await _dioService.authPost('/auth/2fa/enable');
  }

  static Future<Response> disableTwoFactor(String code) async {
    return await _dioService.authPost(
      '/auth/2fa/disable',
      data: {'code': code},
    );
  }

  static Future<Response> verifyTwoFactor(String code) async {
    return await _dioService.authPost('/auth/2fa/verify', data: {'code': code});
  }
}
