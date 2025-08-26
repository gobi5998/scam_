import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'token_storage.dart';
import '../config/api_config.dart';

const ACCESS_TOKEN_KEY = "access_token";
const REFRESH_TOKEN_KEY = "refresh_token";

Future<void> saveTokens(String access, String refresh) async {
  await TokenStorage.setAccessToken(access);
  await TokenStorage.setRefreshToken(refresh);
}

Future<String?> getAccessToken() async {
  return await TokenStorage.getAccessToken();
}

Future<String?> getRefreshToken() async {
  return await TokenStorage.getRefreshToken();
}

class AuthInterceptor extends Interceptor {
  final Dio _dio;
  final Dio? _authDio; // Separate Dio instance for auth requests

  AuthInterceptor(this._dio, {Dio? authDio}) : _authDio = authDio;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException e, handler) async {
    // Only attempt refresh token if this is NOT a refresh token request itself
    if (e.response?.statusCode == 401 &&
        !e.requestOptions.path.contains('refresh-token')) {
      final refreshToken = await getRefreshToken();

      print("🔄 Refresh token: $refreshToken");
      print("🔄 Refresh token length: ${refreshToken?.length ?? 0}");
      print("🔄 Using auth endpoint: ${ApiConfig.refreshTokenEndpoint}");

      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          // Use authDio if available, otherwise use the current dio
          final dioToUse = _authDio ?? _dio;
          final refreshResponse = await dioToUse.post(
            ApiConfig.refreshTokenEndpoint,
            data: {"refresh_token": refreshToken},
          );

          print("🔄 Refresh response status: ${refreshResponse.statusCode}");
          print("🔄 Refresh response data: ${refreshResponse.data}");

          if (refreshResponse.data["refresh_token"] != null) {
            final newAccess = refreshResponse.data["access_token"];
            final newRefresh = refreshResponse.data["refresh_token"];
            await saveTokens(newAccess, newRefresh);

            // retry original request
            e.requestOptions.headers["Authorization"] = "Bearer $newAccess";
            final cloneReq = await _dio.fetch(e.requestOptions);
            return handler.resolve(cloneReq);
          }
        } catch (err) {
          // Only clear refresh token, keep access token for retry
          await TokenStorage.setRefreshToken("");
        }
      }
    }
    return handler.next(e);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }
}
