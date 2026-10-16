import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/request_result.dart';

void main() {
  test('prettyBody formats JSON strings', () {
    final result = RequestResult(ok: true, statusCode: 200, body: '{"a":1,"b":[1,2]}', duration: Duration.zero);
    expect(result.prettyBody, '{\n  "a": 1,\n  "b": [\n    1,\n    2\n  ]\n}');
  });

  test('prettyBody falls back to raw text for non-JSON bodies', () {
    final result = RequestResult(ok: true, statusCode: 200, body: 'plain text', duration: Duration.zero);
    expect(result.prettyBody, 'plain text');
  });

  test('prettyBody and sizeBytes are computed once and cached', () {
    final result = RequestResult(ok: true, statusCode: 200, body: '{"a":"b"}', duration: Duration.zero);
    expect(identical(result.prettyBody, result.prettyBody), isTrue);
    expect(identical(result.sizeBytes, result.sizeBytes), isTrue);
  });

  test('sizeBytes counts UTF-8 bytes', () {
    final result = RequestResult(ok: true, statusCode: 200, body: 'ü', duration: Duration.zero);
    expect(result.sizeBytes, 2);
  });

  test('withBody keeps cached fields reset for the new body', () {
    final result = RequestResult(ok: true, statusCode: 200, body: '{"a":1}', duration: Duration.zero);
    expect(result.prettyBody, contains('"a"'));
    final replaced = result.withBody('nope');
    expect(replaced.prettyBody, 'nope');
  });
}
