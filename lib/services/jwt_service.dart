import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'token_storage.dart';

class JwtService {
  static const String _tokenKey = 'auth_token';
  static const String _backupTokenKey = 'auth_token_backup';

  static Map<String, dynamic>? decodeToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return null;
      }

      // Decode the payload (second part)
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(resp);

      return payloadMap;
    } catch (e) {

      return null;
    }
  }

  static String? getUserIdFromToken(String token) {
    try {
      print('🔑 Decoding token to get user ID...');
      final payload = decodeToken(token);
      if (payload != null) {
        print('📋 Token payload: $payload');
        if (payload.containsKey('sub')) {
          final userId = payload['sub'];
          print('✅ Extracted user ID: $userId');
          return userId;
        } else {
          print('❌ No "sub" claim found in token payload');
        }
      } else {
        print('❌ Failed to decode token or token is invalid');
      }
    } catch (e) {
      print('❌ Error in getUserIdFromToken: $e');
    }
    return null;
  }

  static String? getKeycloakUserIdFromToken(String token) {
    final payload = decodeToken(token);
    if (payload != null && payload.containsKey('sub')) {
      return payload['sub'];
    }
    return null;
  }

  static String? getUserEmailFromToken(String token) {
    final payload = decodeToken(token);
    if (payload != null && payload.containsKey('email')) {
      return payload['email'];
    }
    return null;
  }

  static Future<String?> getCurrentUserEmail() async {
    try {
      final token = await getTokenWithFallback();
      if (token != null) {
        final email = getUserEmailFromToken(token);

        return email;
      }
      return null;
    } catch (e) {

      return null;
    }
  }

  static Future<String?> getCurrentUserId() async {
    try {
      print('🔍 Getting current user ID...');
      final token = await getTokenWithFallback();
      
      if (token == null) {
        print('❌ No token found in any storage');
        return null;
      }
      
      print('🔑 Token found, extracting user ID...');
      final userId = getUserIdFromToken(token);
      
      if (userId == null) {
        print('❌ Failed to extract user ID from token');
      } else {
        print('✅ Successfully retrieved user ID: $userId');
      }
      
      return userId;
    } catch (e) {

      return null;
    }
  }

  static Future<String?> getTokenWithFallback() async {
    try {
      // First try to get token from secure storage (TokenStorage)
      String? token = await TokenStorage.getAccessToken();
      
      if (token?.isNotEmpty ?? false) {
        // Also save to SharedPreferences for backward compatibility
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token!); // Add ! to assert non-null since we checked with isNotEmpty
        return token;
      }
      
      // Fall back to SharedPreferences if secure storage is empty
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString(_tokenKey);

      if (token != null && token.isNotEmpty) {
        // If found in SharedPreferences, migrate to secure storage
        await TokenStorage.setAccessToken(token);
        return token;
      }
      
      // Try backup token storage as last resort
      token = prefs.getString(_backupTokenKey);
      if (token != null && token.isNotEmpty) {
        // Migrate to secure storage and update primary storage
        await TokenStorage.setAccessToken(token);
        await prefs.setString(_tokenKey, token);
        return token;
      }


      return null;
    } catch (e) {

      return null;
    }
  }

  static Future<bool> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save to primary storage
      await prefs.setString(_tokenKey, token);

      // Also save to backup storage for device compatibility
      await prefs.setString(_backupTokenKey, token);


      return true;
    } catch (e) {

      return false;
    }
  }

  static Future<bool> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear from both storages
      await prefs.remove(_tokenKey);
      await prefs.remove(_backupTokenKey);


      return true;
    } catch (e) {

      return false;
    }
  }

  static Future<bool> hasValidToken() async {
    try {
      final token = await getTokenWithFallback();
      if (token == null) return false;

      final payload = decodeToken(token);
      if (payload == null) return false;

      // Check if token has expiration
      if (payload.containsKey('exp')) {
        final exp = payload['exp'] as int;
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        return exp > now;
      }

      return true; // If no expiration, assume valid
    } catch (e) {

      return false;
    }
  }

  // Diagnostic method for device-specific issues
  static Future<Map<String, dynamic>> diagnoseTokenStorage() async {
    final diagnostics = <String, dynamic>{
      'device': defaultTargetPlatform.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      'primary_storage': null,
      'backup_storage': null,
      'jwt_service_token': null,
      'errors': <String>[],
    };

    try {
      final prefs = await SharedPreferences.getInstance();

      // Check primary storage
      try {
        final primaryToken = prefs.getString(_tokenKey);
        diagnostics['primary_storage'] = {
          'exists': primaryToken != null,
          'length': primaryToken?.length ?? 0,
          'preview': primaryToken != null
              ? '${primaryToken!.substring(0, 20)}...'
              : null,
        };
      } catch (e) {
        diagnostics['errors'].add('Primary storage error: $e');
      }

      // Check backup storage
      try {
        final backupToken = prefs.getString(_backupTokenKey);
        diagnostics['backup_storage'] = {
          'exists': backupToken != null,
          'length': backupToken?.length ?? 0,
          'preview': backupToken != null
              ? '${backupToken!.substring(0, 20)}...'
              : null,
        };
      } catch (e) {
        diagnostics['errors'].add('Backup storage error: $e');
      }

      // Check JWT service
      try {
        final jwtToken = await getTokenWithFallback();
        diagnostics['jwt_service_token'] = {
          'exists': jwtToken != null,
          'length': jwtToken?.length ?? 0,
          'preview': jwtToken != null
              ? '${jwtToken!.substring(0, 20)}...'
              : null,
        };
      } catch (e) {
        diagnostics['errors'].add('JWT service error: $e');
      }
    } catch (e) {
      diagnostics['errors'].add('General error: $e');
    }


    return diagnostics;
  }
}
