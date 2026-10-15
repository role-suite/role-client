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

ResponseBody _json(Object body, {int status = 200}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  test('parses the latest release and sends the headers GitHub requires', () async {
    RequestOptions? captured;
    final checker = _checker((options) async {
      captured = options;
      return _json({
        'tag_name': 'v1.2.0',
        'html_url': 'https://github.com/role-suite/role-client/releases/tag/v1.2.0',
        'name': 'v1.2.0',
        'body': 'Notes',
        'published_at': '2026-10-15T00:00:00Z',
      });
    });

    final release = await checker.fetchLatest();
    expect(release.tagName, 'v1.2.0');
    expect(release.htmlUrl, contains('/v1.2.0'));
    expect(release.body, 'Notes');
    expect(release.publishedAt, DateTime.utc(2026, 10, 15));
    expect(captured?.headers['User-Agent'], 'role-client');
    expect(captured?.headers['Accept'], 'application/vnd.github+json');
  });

  test('throws when the payload is not a release', () async {
    final checker = _checker((_) async => _json({'message': 'hello'}));
    await expectLater(checker.fetchLatest(), throwsA(isA<ReleaseCheckException>().having((e) => e.message, 'message', contains('unexpected'))));
  });

  test('maps rate limiting to a friendly message', () async {
    final checker = _checker((_) async => _json({'message': 'rate limited'}, status: 403));
    await expectLater(checker.fetchLatest(), throwsA(isA<ReleaseCheckException>().having((e) => e.message, 'message', contains('rate limit'))));
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
