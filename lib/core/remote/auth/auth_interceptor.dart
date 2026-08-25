import 'package:dio/dio.dart';

import 'token_store.dart';

typedef ReadTokens = Future<TokenPair?> Function();
typedef WriteTokens = Future<void> Function(TokenPair tokens);
typedef ClearTokens = Future<void> Function();
typedef RefreshTokens = Future<TokenPair> Function(String refreshToken);
typedef OnRefreshFailed = Future<void> Function();

/// Attaches `Authorization: Bearer <accessToken>` to every request and
/// implements the retry rule role-node's guide specifies on a dead access
/// token: refresh once, then replay the original request once — never a
/// naive retry loop. See §4 of docs/08-ONLINE-MODE-INTEGRATION.md.
///
/// Takes plain read/write/clear callbacks rather than a concrete
/// [SecureTokenStore] so it's testable without a real secure-storage backend.
///
/// [refreshTokens] must not go through the same [Dio]/interceptor this is
/// attached to — this is a [QueuedInterceptor], so a nested call back into
/// the same instance from inside [onError] would deadlock waiting on itself.
/// Callers should hit `/auth/refresh` on a bare `Dio` with no interceptors.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.readTokens,
    required this.writeTokens,
    required this.clearTokens,
    required this.refreshTokens,
    required this.onRefreshFailed,
    Dio Function()? retryDioFactory,
  }) : _retryDioFactory = retryDioFactory ?? Dio.new;

  final ReadTokens readTokens;
  final WriteTokens writeTokens;
  final ClearTokens clearTokens;
  final RefreshTokens refreshTokens;
  final OnRefreshFailed onRefreshFailed;

  /// Builds the [Dio] used to replay the original request. Defaults to a
  /// bare `Dio()` in production; tests inject one wired to a fake adapter so
  /// the replay never hits the real network.
  final Dio Function() _retryDioFactory;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final tokens = await readTokens();
    if (tokens != null) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final alreadyRetried = err.requestOptions.extra['authRetried'] == true;
    if (alreadyRetried || !_isDeadAccessToken(err)) {
      handler.next(err);
      return;
    }

    final current = await readTokens();
    if (current == null) {
      handler.next(err);
      return;
    }

    try {
      final refreshed = await refreshTokens(current.refreshToken);
      await writeTokens(refreshed);

      final retryOptions = err.requestOptions;
      retryOptions.extra = {...retryOptions.extra, 'authRetried': true};
      retryOptions.headers['Authorization'] = 'Bearer ${refreshed.accessToken}';

      final response = await _retryDioFactory().fetch(retryOptions);
      handler.resolve(response);
    } catch (_) {
      await clearTokens();
      await onRefreshFailed();
      handler.next(err);
    }
  }

  bool _isDeadAccessToken(DioException err) {
    if (err.response?.statusCode != 401) return false;
    final data = err.response?.data;
    final code = (data is Map && data['error'] is Map) ? (data['error'] as Map)['code'] as String? : null;
    return code == 'INVALID_ACCESS_TOKEN' || code == 'MISSING_ACCESS_TOKEN';
  }
}
