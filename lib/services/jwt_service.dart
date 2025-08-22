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
    final payload = decodeToken(token);
    if (payload != null && payload.containsKey('sub')) {
      return payload['sub'];
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
      final token = await TokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        print('❌ No access token found for user ID extraction');
        return null;
      }

      print('🔍 Extracting user ID from JWT token...');
      print('🔍 Token length: ${token.length}');
      print('🔍 Token preview: ${token.substring(0, 50)}...');

      final decoded = decodeToken(token);
      print('🔍 Decoded JWT payload: $decoded');

      if (decoded == null) {
        print('❌ Failed to decode JWT token');
        return null;
      }

      // Try different possible field names for user ID
      final userId =
          decoded['sub'] ??
          decoded['user_id'] ??
          decoded['userId'] ??
          decoded['id'] ??
          decoded['user']?['id'] ??
          decoded['user']?['sub'];

      if (userId != null) {
        print('✅ Extracted user ID: $userId');
        return userId.toString();
      } else {
        print('❌ No user ID found in JWT payload');
        print('🔍 Available fields: ${decoded.keys.toList()}');

        // Try to get email as fallback
        final email = decoded['email'] ?? decoded['preferred_username'];
        if (email != null) {
          print('✅ Using email as user ID: $email');
          return email.toString();
        }

        return null;
      }
    } catch (e) {
      print('❌ Error extracting user ID from JWT: $e');
      return null;
    }
  }

  static Future<String?> getTokenWithFallback() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Try primary token storage
      String? token = prefs.getString(_tokenKey);

      if (token != null && token.isNotEmpty) {
        return token;
      }

      // Try backup token storage
      token = prefs.getString(_backupTokenKey);
      if (token != null && token.isNotEmpty) {
        // Restore to primary storage
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
