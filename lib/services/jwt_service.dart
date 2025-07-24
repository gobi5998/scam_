import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class JwtService {
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
      print('Error decoding JWT token: $e');
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

  static Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    print('JWT Service - Token exists: ${token != null}');

    if (token != null) {
      final userId = getUserIdFromToken(token);
      print('JWT Service - User ID from token: $userId');
      return userId;
    }

    print('JWT Service - No auth token found');
    return null;
  }
}
