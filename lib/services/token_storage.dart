import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cookie_jar/cookie_jar.dart';

class TokenStorage {
  static final _storage = FlutterSecureStorage();

  static const _accessTokenKey = 'ACCESS_TOKEN';
  static const _refreshTokenKey = 'REFRESH_TOKEN';

  // CookieJar for managing cookies
  static final CookieJar cookieJar = CookieJar();

  // Access Token
  static Future<void> setAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  static Future<void> removeAccessToken() async {
    await _storage.delete(key: _accessTokenKey);
  }

  // Refresh Token
  static Future<void> setRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  static Future<void> removeRefreshToken() async {
    await _storage.delete(key: _refreshTokenKey);
  }

  // Clear All Tokens
  static Future<void> clearAllTokens() async {
    await _storage.deleteAll();
  }

  // Cookie Handling
  static Future<List<Cookie>> getCookies(String url) async {
    return await cookieJar.loadForRequest(Uri.parse(url));
  }

  static Future<void> clearCookies() async {
    await cookieJar.deleteAll();
    print('🍪 All cookies cleared.');
  }
}
