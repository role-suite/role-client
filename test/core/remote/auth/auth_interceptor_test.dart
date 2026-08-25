import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/remote/auth/auth_interceptor.dart';
import 'package:relay/core/remote/auth/token_store.dart';

ResponseBody _jsonBody(String json, int statusCode) => ResponseBody.fromString(
  json,
  statusCode,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  group('AuthInterceptor', () {
    test('attaches the stored access token as a bearer header', () async {
      TokenPair? stored = const TokenPair(accessToken: 'access-1', refreshToken: 'refresh-1');
      String? sentAuthHeader;

      final dio = Dio(BaseOptions(baseUrl: 'https://role.example.com/api/v1'));
      dio.httpClientAdapter = _RecordingAdapter((options) {
        sentAuthHeader = options.headers['Authorization'] as String?;
        return _jsonBody('{"success":true,"data":{}}', 200);
      });
      dio.interceptors.add(
        AuthInterceptor(
          readTokens: () async => stored,
          writeTokens: (t) async => stored = t,
          clearTokens: () async => stored = null,
          refreshTokens: (_) async => throw StateError('should not be called'),
          onRefreshFailed: () async {},
        ),
      );

      await dio.get('/workspaces');

      expect(sentAuthHeader, 'Bearer access-1');
    });

    test('refreshes once and replays the original request on a dead access token', () async {
      TokenPair? stored = const TokenPair(accessToken: 'expired', refreshToken: 'refresh-1');
      var callCount = 0;

      final sharedAdapter = _RecordingAdapter((options) {
        callCount++;
        final header = options.headers['Authorization'] as String?;
        if (header == 'Bearer expired') {
          return _jsonBody('{"success":false,"error":{"code":"INVALID_ACCESS_TOKEN","message":"Invalid access token"}}', 401);
        }
        return _jsonBody('{"success":true,"data":{"ok":true}}', 200);
      });

      final dio = Dio(BaseOptions(baseUrl: 'https://role.example.com/api/v1'))..httpClientAdapter = sharedAdapter;
      dio.interceptors.add(
        AuthInterceptor(
          readTokens: () async => stored,
          writeTokens: (t) async => stored = t,
          clearTokens: () async => stored = null,
          refreshTokens: (refreshToken) async {
            expect(refreshToken, 'refresh-1');
            return const TokenPair(accessToken: 'fresh', refreshToken: 'refresh-2');
          },
          onRefreshFailed: () async {},
          // Replay must go through the same fake adapter, never the real network.
          retryDioFactory: () => Dio(BaseOptions(baseUrl: 'https://role.example.com/api/v1'))..httpClientAdapter = sharedAdapter,
        ),
      );

      final response = await dio.get('/workspaces');

      expect(response.statusCode, 200);
      expect(callCount, 2);
      expect(stored?.accessToken, 'fresh');
    });

    test('clears tokens and calls onRefreshFailed when the refresh call itself fails', () async {
      TokenPair? stored = const TokenPair(accessToken: 'expired', refreshToken: 'refresh-1');
      var refreshFailedCalled = false;

      final dio = Dio(BaseOptions(baseUrl: 'https://role.example.com/api/v1'));
      dio.httpClientAdapter = _RecordingAdapter(
        (options) => _jsonBody('{"success":false,"error":{"code":"INVALID_ACCESS_TOKEN","message":"Invalid access token"}}', 401),
      );
      dio.interceptors.add(
        AuthInterceptor(
          readTokens: () async => stored,
          writeTokens: (t) async => stored = t,
          clearTokens: () async => stored = null,
          refreshTokens: (_) async => throw StateError('refresh token is dead too'),
          onRefreshFailed: () async => refreshFailedCalled = true,
        ),
      );

      await expectLater(dio.get('/workspaces'), throwsA(isA<DioException>()));

      expect(stored, isNull);
      expect(refreshFailedCalled, isTrue);
    });

    test('passes through a non-auth error untouched', () async {
      TokenPair? stored = const TokenPair(accessToken: 'access-1', refreshToken: 'refresh-1');

      final dio = Dio(BaseOptions(baseUrl: 'https://role.example.com/api/v1'));
      dio.httpClientAdapter = _RecordingAdapter(
        (options) => _jsonBody('{"success":false,"error":{"code":"VALIDATION_FAILED","message":"Bad input"}}', 422),
      );
      dio.interceptors.add(
        AuthInterceptor(
          readTokens: () async => stored,
          writeTokens: (t) async => stored = t,
          clearTokens: () async => stored = null,
          refreshTokens: (_) async => throw StateError('should not be called'),
          onRefreshFailed: () async {},
        ),
      );

      await expectLater(dio.get('/workspaces'), throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'statusCode', 422)));
      expect(stored?.accessToken, 'access-1');
    });
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this._respond);

  final ResponseBody Function(RequestOptions options) _respond;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    return _respond(options);
  }
}
