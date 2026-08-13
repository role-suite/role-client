enum AssertionType { statusEquals, maxDurationMs, bodyContains, headerEquals, jsonPath }

extension AssertionTypeX on AssertionType {
  String get label {
    switch (this) {
      case AssertionType.statusEquals:
        return 'Status equals';
      case AssertionType.maxDurationMs:
        return 'Response time under (ms)';
      case AssertionType.bodyContains:
        return 'Body contains';
      case AssertionType.headerEquals:
        return 'Header equals';
      case AssertionType.jsonPath:
        return 'JSON path equals';
    }
  }

  /// Whether this type needs a [Assertion.target] (a header name or JSON
  /// path) in addition to the expected value.
  bool get needsTarget => this == AssertionType.headerEquals || this == AssertionType.jsonPath;

  static AssertionType fromString(String value) {
    return AssertionType.values.firstWhere((t) => t.name.toLowerCase() == value.toLowerCase(), orElse: () => AssertionType.statusEquals);
  }
}

/// A single declarative check run against a [RequestResult] — no scripting,
/// just typed comparisons, kept in the same spirit as the rest of the app's
/// dependency-free, local-only design.
class Assertion {
  final String id;
  final AssertionType type;
  final String? target;
  final String expected;
  final bool enabled;

  const Assertion({required this.id, required this.type, this.target, this.expected = '', this.enabled = true});

  Assertion copyWith({AssertionType? type, String? target, String? expected, bool? enabled}) {
    return Assertion(
      id: id,
      type: type ?? this.type,
      target: target ?? this.target,
      expected: expected ?? this.expected,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'type': type.name, 'target': target, 'expected': expected, 'enabled': enabled};

  factory Assertion.fromJson(Map<String, dynamic> json) {
    return Assertion(
      id: json['id'] as String,
      type: AssertionTypeX.fromString(json['type'] as String? ?? 'statusEquals'),
      target: json['target'] as String?,
      expected: json['expected'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

class AssertionResult {
  final Assertion assertion;
  final bool passed;
  final String message;

  const AssertionResult({required this.assertion, required this.passed, required this.message});
}
