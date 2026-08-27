import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/remote/api_client.dart';
import 'package:relay/core/remote/remote_api_exception.dart';

void main() {
  group('parseEnvelope', () {
    test('returns data on a success envelope', () {
      final data = parseEnvelope({
        'success': true,
        'data': {'id': 1},
      });
      expect(data, {'id': 1});
    });

    test('throws RemoteApiException from an error envelope', () {
      expect(
        () => parseEnvelope({
          'success': false,
          'error': {
            'code': 'VALIDATION_FAILED',
            'message': 'Bad input',
            'requestId': 'req-1',
            'details': {'fieldErrors': {}},
          },
        }),
        throwsA(
          isA<RemoteApiException>()
              .having((e) => e.code, 'code', 'VALIDATION_FAILED')
              .having((e) => e.message, 'message', 'Bad input')
              .having((e) => e.requestId, 'requestId', 'req-1'),
        ),
      );
    });

    test('throws malformed-response on a shape that is neither envelope form', () {
      expect(() => parseEnvelope({'unexpected': true}), throwsA(isA<RemoteApiException>().having((e) => e.code, 'code', 'MALFORMED_RESPONSE')));
    });

    test('throws malformed-response on a non-Map body', () {
      expect(() => parseEnvelope('not json'), throwsA(isA<RemoteApiException>().having((e) => e.code, 'code', 'MALFORMED_RESPONSE')));
    });
  });

  group('mapDioError', () {
    RequestOptions options() => RequestOptions(path: '/api/v1/auth/login');

    test('prefers the server error envelope when the response carries one', () {
      final error = DioException(
        requestOptions: options(),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: options(),
          statusCode: 401,
          data: {
            'success': false,
            'error': {'code': 'INVALID_ACCESS_TOKEN', 'message': 'Token expired'},
          },
        ),
      );

      final mapped = mapDioError(error);
      expect(mapped.code, 'INVALID_ACCESS_TOKEN');
      expect(mapped.message, 'Token expired');
    });

    test('classifies timeouts and connection errors as NETWORK_ERROR', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
      ]) {
        final mapped = mapDioError(DioException(requestOptions: options(), type: type));
        expect(mapped.code, 'NETWORK_ERROR', reason: 'for $type');
      }
    });

    test('falls back to UNKNOWN_ERROR for an unclassified DioException with no envelope', () {
      final mapped = mapDioError(DioException(requestOptions: options(), type: DioExceptionType.unknown, message: 'boom'));
      expect(mapped.code, 'UNKNOWN_ERROR');
      expect(mapped.message, 'boom');
    });
  });

  group('RemoteApiClient', () {
    test('unwraps a successful response through the injected Dio adapter', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://role.example.com/api/v1'));
      dio.httpClientAdapter = _FakeAdapter((options) {
        return ResponseBody.fromString(
          '{"success":true,"data":{"id":42}}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final client = RemoteApiClient(baseUrl: 'https://role.example.com', dio: dio);
      final data = await client.get('/workspaces');

      expect(data, {'id': 42});
    });

    test('throws RemoteApiException when the adapter reports a connection error', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://role.example.com/api/v1'));
      dio.httpClientAdapter = _ThrowingAdapter();

      final client = RemoteApiClient(baseUrl: 'https://role.example.com', dio: dio);

      await expectLater(client.get('/workspaces'), throwsA(isA<RemoteApiException>().having((e) => e.code, 'code', 'NETWORK_ERROR')));
    });
  });
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._respond);

  final ResponseBody Function(RequestOptions options) _respond;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    return _respond(options);
  }
}

class _ThrowingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    throw DioException(requestOptions: options, type: DioExceptionType.connectionError, message: 'Failed host lookup');
  }
}
