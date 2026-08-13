import '../models/assertion.dart';
import '../models/request_result.dart';
import '../utils/iterable_ext.dart';

/// Evaluates a request's [Assertion] list against the [RequestResult] it
/// just produced. Pure and synchronous — no scripting, just typed
/// comparisons against data already resolved by [RequestRunner].
abstract class AssertionEvaluator {
  static List<AssertionResult> evaluate(List<Assertion> assertions, RequestResult result) {
    return assertions.where((a) => a.enabled).map((a) => _evaluateOne(a, result)).toList();
  }

  static AssertionResult _evaluateOne(Assertion assertion, RequestResult result) {
    switch (assertion.type) {
      case AssertionType.statusEquals:
        final expected = int.tryParse(assertion.expected.trim());
        if (expected == null) return _fail(assertion, 'expected value must be a status code');
        return result.statusCode == expected
            ? _pass(assertion, 'status is $expected')
            : _fail(assertion, 'expected status $expected, got ${result.statusCode ?? '—'}');

      case AssertionType.maxDurationMs:
        final maxMs = int.tryParse(assertion.expected.trim());
        if (maxMs == null) return _fail(assertion, 'expected value must be a duration in ms');
        final actual = result.duration.inMilliseconds;
        return actual <= maxMs ? _pass(assertion, '${actual}ms ≤ ${maxMs}ms') : _fail(assertion, '${actual}ms exceeds ${maxMs}ms');

      case AssertionType.bodyContains:
        final body = result.prettyBody;
        return body.contains(assertion.expected)
            ? _pass(assertion, 'body contains "${assertion.expected}"')
            : _fail(assertion, 'body does not contain "${assertion.expected}"');

      case AssertionType.headerEquals:
        final name = assertion.target?.trim() ?? '';
        final values = result.headers.entries.where((e) => e.key.toLowerCase() == name.toLowerCase()).map((e) => e.value).firstOrNull;
        final actual = values?.join(', ');
        return actual == assertion.expected
            ? _pass(assertion, 'header "$name" is "${assertion.expected}"')
            : _fail(assertion, 'header "$name" was ${actual == null ? 'missing' : '"$actual"'}, expected "${assertion.expected}"');

      case AssertionType.jsonPath:
        final path = assertion.target?.trim() ?? '';
        final found = _resolveJsonPath(result.body, path);
        if (!found.exists) return _fail(assertion, 'path "$path" not found in response body');
        final actual = found.value?.toString() ?? 'null';
        return actual == assertion.expected
            ? _pass(assertion, '"$path" is "${assertion.expected}"')
            : _fail(assertion, '"$path" was "$actual", expected "${assertion.expected}"');
    }
  }

  static AssertionResult _pass(Assertion a, String message) => AssertionResult(assertion: a, passed: true, message: message);
  static AssertionResult _fail(Assertion a, String message) => AssertionResult(assertion: a, passed: false, message: message);

  /// Walks a dot-separated path with optional trailing `[index]` per
  /// segment (e.g. `data.items[0].id`) through a decoded JSON value.
  static _JsonLookup _resolveJsonPath(dynamic body, String path) {
    if (path.isEmpty) return const _JsonLookup.notFound();
    dynamic current = body;

    for (final rawSegment in path.split('.')) {
      final match = RegExp(r'^([^\[\]]*)((?:\[\d+\])*)$').firstMatch(rawSegment);
      if (match == null) return const _JsonLookup.notFound();

      final key = match.group(1) ?? '';
      if (key.isNotEmpty) {
        if (current is Map) {
          if (!current.containsKey(key)) return const _JsonLookup.notFound();
          current = current[key];
        } else {
          return const _JsonLookup.notFound();
        }
      }

      final indices = RegExp(r'\[(\d+)\]').allMatches(match.group(2) ?? '');
      for (final indexMatch in indices) {
        final index = int.parse(indexMatch.group(1)!);
        if (current is! List || index >= current.length) return const _JsonLookup.notFound();
        current = current[index];
      }
    }

    return _JsonLookup.found(current);
  }
}

class _JsonLookup {
  const _JsonLookup.found(this.value) : exists = true;
  const _JsonLookup.notFound() : exists = false, value = null;

  final bool exists;
  final dynamic value;
}
