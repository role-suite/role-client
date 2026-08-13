import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/assertion.dart';
import 'package:relay/core/models/request_result.dart';
import 'package:relay/core/network/assertion_evaluator.dart';

RequestResult _result({
  int? statusCode,
  Duration duration = const Duration(milliseconds: 100),
  Map<String, List<String>> headers = const {},
  dynamic body,
}) {
  return RequestResult(ok: (statusCode ?? 0) < 400, statusCode: statusCode, headers: headers, body: body, duration: duration);
}

Assertion _assertion(AssertionType type, {String? target, String expected = '', bool enabled = true}) {
  return Assertion(id: 'a', type: type, target: target, expected: expected, enabled: enabled);
}

void main() {
  group('AssertionEvaluator', () {
    test('statusEquals passes on match and fails otherwise', () {
      final result = _result(statusCode: 200);
      final pass = AssertionEvaluator.evaluate([_assertion(AssertionType.statusEquals, expected: '200')], result);
      final fail = AssertionEvaluator.evaluate([_assertion(AssertionType.statusEquals, expected: '201')], result);
      expect(pass.single.passed, isTrue);
      expect(fail.single.passed, isFalse);
    });

    test('maxDurationMs passes at or under the limit', () {
      final result = _result(statusCode: 200, duration: const Duration(milliseconds: 300));
      final pass = AssertionEvaluator.evaluate([_assertion(AssertionType.maxDurationMs, expected: '300')], result);
      final fail = AssertionEvaluator.evaluate([_assertion(AssertionType.maxDurationMs, expected: '299')], result);
      expect(pass.single.passed, isTrue);
      expect(fail.single.passed, isFalse);
    });

    test('bodyContains matches a substring of the pretty-printed body', () {
      final result = _result(statusCode: 200, body: {'name': 'ada'});
      final pass = AssertionEvaluator.evaluate([_assertion(AssertionType.bodyContains, expected: 'ada')], result);
      final fail = AssertionEvaluator.evaluate([_assertion(AssertionType.bodyContains, expected: 'missing')], result);
      expect(pass.single.passed, isTrue);
      expect(fail.single.passed, isFalse);
    });

    test('headerEquals is case-insensitive on the header name', () {
      final result = _result(
        statusCode: 200,
        headers: {
          'Content-Type': ['application/json'],
        },
      );
      final results = AssertionEvaluator.evaluate([
        _assertion(AssertionType.headerEquals, target: 'content-type', expected: 'application/json'),
      ], result);
      expect(results.single.passed, isTrue);
    });

    test('headerEquals fails when the header is missing', () {
      final result = _result(statusCode: 200);
      final results = AssertionEvaluator.evaluate([
        _assertion(AssertionType.headerEquals, target: 'x-missing', expected: 'anything'),
      ], result);
      expect(results.single.passed, isFalse);
      expect(results.single.message, contains('missing'));
    });

    test('jsonPath resolves nested map keys', () {
      final result = _result(
        statusCode: 200,
        body: {
          'data': {'id': 42},
        },
      );
      final results = AssertionEvaluator.evaluate([_assertion(AssertionType.jsonPath, target: 'data.id', expected: '42')], result);
      expect(results.single.passed, isTrue);
    });

    test('jsonPath resolves list indices', () {
      final result = _result(
        statusCode: 200,
        body: {
          'items': [
            {'id': 1},
            {'id': 2},
          ],
        },
      );
      final results = AssertionEvaluator.evaluate([
        _assertion(AssertionType.jsonPath, target: 'items[1].id', expected: '2'),
      ], result);
      expect(results.single.passed, isTrue);
    });

    test('jsonPath fails when the path does not exist', () {
      final result = _result(statusCode: 200, body: {'data': {}});
      final results = AssertionEvaluator.evaluate([
        _assertion(AssertionType.jsonPath, target: 'data.missing', expected: 'x'),
      ], result);
      expect(results.single.passed, isFalse);
      expect(results.single.message, contains('not found'));
    });

    test('jsonPath fails gracefully when indexing past the end of a list', () {
      final result = _result(
        statusCode: 200,
        body: {
          'items': [1],
        },
      );
      final results = AssertionEvaluator.evaluate([
        _assertion(AssertionType.jsonPath, target: 'items[5]', expected: 'x'),
      ], result);
      expect(results.single.passed, isFalse);
    });

    test('disabled assertions are skipped entirely', () {
      final result = _result(statusCode: 500);
      final results = AssertionEvaluator.evaluate([_assertion(AssertionType.statusEquals, expected: '200', enabled: false)], result);
      expect(results, isEmpty);
    });
  });
}
