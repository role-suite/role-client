import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/updates/release_checker.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);

  final Future<ResponseBody> Function(RequestOptions options) _respond;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) => _respond(options);
}

ReleaseChecker _checker(Future<ResponseBody> Function(RequestOptions options) respond) {
  final dio = Dio()..httpClientAdapter = _ScriptedAdapter(respond);
  return ReleaseChecker(dio: dio);
}

ResponseBody _redirect(String location) => ResponseBody.fromString(
  '',
  302,
  headers: {
    'location': [location],
  },
);

ResponseBody _status(int status, {Map<String, List<String>> headers = const {}}) => ResponseBody.fromString(
  jsonEncode({'message': 'error'}),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    ...headers,
  },
);

void main() {
  test('reads the release tag from the redirect and sends the required headers', () async {
    RequestOptions? captured;
    final checker = _checker((options) async {
      captured = options;
      return _redirect('https://github.com/role-suite/role-client/releases/tag/v1.2.0');
    });

    final release = await checker.fetchLatest();
    expect(release.tagName, 'v1.2.0');
    expect(release.htmlUrl, 'https://github.com/role-suite/role-client/releases/tag/v1.2.0');
    expect(captured?.headers['User-Agent'], 'role-client');
    expect(captured?.followRedirects, isFalse);
    expect(captured?.path, ReleaseChecker.latestReleaseUrl);
  });

  test('parses relative redirect locations too', () async {
    final checker = _checker((_) async => _redirect('/role-suite/role-client/releases/tag/v1.2.1'));
    expect((await checker.fetchLatest()).tagName, 'v1.2.1');
  });

  test('throws when the redirect has no release tag', () async {
    final checker = _checker((_) async => _redirect('https://github.com/role-suite/role-client/releases'));
    await expectLater(checker.fetchLatest(), throwsA(isA<ReleaseCheckException>().having((e) => e.message, 'message', contains('unexpected'))));
  });

  test('maps 404 to a request-failed message', () async {
    final checker = _checker((_) async => _status(404));
    await expectLater(checker.fetchLatest(), throwsA(isA<ReleaseCheckException>().having((e) => e.message, 'message', contains('404'))));
  });

  test('only claims rate limiting when GitHub says so', () async {
    final limited = _checker(
      (_) async => _status(
        403,
        headers: {
          'x-ratelimit-remaining': ['0'],
        },
      ),
    );
    await expectLater(limited.fetchLatest(), throwsA(isA<ReleaseCheckException>().having((e) => e.message, 'message', contains('rate-limiting'))));

    final refused = _checker((_) async => _status(403));
    await expectLater(
      refused.fetchLatest(),
      throwsA(isA<ReleaseCheckException>().having((e) => e.message, 'message', contains('refused the request'))),
    );
  });

  test('maps connection failures to an offline message', () async {
    final checker = _checker((options) async {
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
    });
    await expectLater(
      checker.fetchLatest(),
      throwsA(isA<ReleaseCheckException>().having((e) => e.message, 'message', contains('Could not reach GitHub'))),
    );
  });
}
