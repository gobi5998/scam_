import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
}
