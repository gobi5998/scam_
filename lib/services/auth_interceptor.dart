import 'package:dio/dio.dart';
import 'package:synchronized/synchronized.dart';
import '../config/api_config.dart';
import 'token_storage.dart';

class AuthInterceptor extends Interceptor {
  final Dio _dio;

  // A lock to ensure single refresh at once
  final Lock _refreshLock = Lock();
  String? _cachedAccessToken;

  AuthInterceptor(this._dio);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      // Attach access token if available
      String? accessToken = await TokenStorage.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
      // Default headers
      options.headers.addAll(ApiConfig.defaultHeaders);

      if (ApiConfig.enableLogging) {
        print('→ [Request] ${options.method} ${options.uri}');
      }
      handler.next(options);
    } catch (e) {
      handler.next(options); // still proceed
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    final requestOptions = err.requestOptions;

    if (ApiConfig.enableLogging) {
      print(
        '✖ [Error] ${requestOptions.method} ${requestOptions.uri} '
        'Status: ${response?.statusCode} Message: ${err.message}',
      );
    }

    // Only attempt refresh on 401 and if not already retried
    if (response?.statusCode == 401 &&
        requestOptions.extra['retried'] != true) {
      await _refreshLock.synchronized(() async {
        // If token was already refreshed by another waiting request, reuse it
        final currentAccess = await TokenStorage.getAccessToken();
        if (currentAccess != null &&
            currentAccess.isNotEmpty &&
            currentAccess != _cachedAccessToken) {
          _cachedAccessToken = currentAccess;
          return;
        }

        // Attempt refresh
        final refreshToken = await TokenStorage.getRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          // No refresh token, force logout
          await TokenStorage.clearAllTokens();
          return;
        }

        try {
          final refreshDio = Dio(
            BaseOptions(
              baseUrl: ApiConfig.authBaseUrl,
              contentType: 'application/json',
              receiveTimeout: const Duration(seconds: ApiConfig.receiveTimeout),
            ),
          );
          final refreshResp = await refreshDio.post(
            '/auth/refresh-token',
            data: {'refreshToken': refreshToken},
          );

          final newAccess = refreshResp.data['access_token'];
          final newRefresh = refreshResp.data['refresh_token'];

          if (newAccess != null && newAccess.isNotEmpty) {
            await TokenStorage.setAccessToken(newAccess);
            if (newRefresh != null && newRefresh.isNotEmpty) {
              await TokenStorage.setRefreshToken(newRefresh);
            }
            _cachedAccessToken = newAccess;
            if (ApiConfig.enableLogging) {
              print('✔ Token refreshed successfully.');
            }
          } else {
            // Invalid refresh response; clear everything
            await TokenStorage.clearAllTokens();
            if (ApiConfig.enableLogging) {
              print('✖ Token refresh response invalid.');
            }
          }
        } catch (e) {
          // Refresh failed
          await TokenStorage.clearAllTokens();
          if (ApiConfig.enableLogging) {
            print('✖ Token refresh failed: $e');
          }
        }
      });

      // If access token now exists, retry original request
      final updatedAccess = await TokenStorage.getAccessToken();
      if (updatedAccess != null && updatedAccess.isNotEmpty) {
        final opts = requestOptions.copyWith();
        opts.headers['Authorization'] = 'Bearer $updatedAccess';
        opts.extra['retried'] = true;
        try {
          final cloneResp = await _dio.fetch(opts);
          return handler.resolve(cloneResp);
        } catch (retryError) {
          return handler.next(err);
        }
      }
    }

    // Otherwise propagate original error
    handler.next(err);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (ApiConfig.enableLogging) {
      print(
        '✔ [Response] ${response.statusCode} ${response.requestOptions.uri}',
      );
    }
    handler.next(response);
  }
}
