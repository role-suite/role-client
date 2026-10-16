import 'dart:convert';

class RequestResult {
  RequestResult({
    required this.ok,
    this.statusCode,
    this.statusMessage,
    this.headers = const {},
    this.body,
    required this.duration,
    this.errorMessage,
    this.isOffline = false,
  });

  final bool ok;
  final int? statusCode;
  final String? statusMessage;
  final Map<String, List<String>> headers;
  final dynamic body;
  final Duration duration;
  final String? errorMessage;
  final bool isOffline;

  /// Number of bytes in the body as sent over the wire. Computed once per
  /// result: this used to be a getter that re-encoded multi-megabyte bodies
  /// on every widget build.
  late final int sizeBytes = _computeSizeBytes();

  /// The body pretty-printed when it is JSON, else the raw text. Computed
  /// once per result for the same reason as [sizeBytes].
  late final String prettyBody = _computePrettyBody();

  int _computeSizeBytes() {
    final current = body;
    if (current == null) return 0;
    if (current is String) return utf8.encode(current).length;
    try {
      return utf8.encode(jsonEncode(current)).length;
    } catch (_) {
      return current.toString().length;
    }
  }

  String _computePrettyBody() {
    final current = body;
    if (current == null) return '';
    if (current is Map || current is List) {
      try {
        return const JsonEncoder.withIndent('  ').convert(current);
      } catch (_) {
        return current.toString();
      }
    }
    if (current is String) {
      try {
        return const JsonEncoder.withIndent('  ').convert(jsonDecode(current));
      } catch (_) {
        return current;
      }
    }
    return current.toString();
  }

  /// The `Content-Type` response header, lower-cased, ignoring any
  /// `; charset=...` suffix. Header lookup is case-insensitive since
  /// servers vary in how they capitalize it.
  String? get contentType {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'content-type') {
        if (entry.value.isEmpty) return null;
        return entry.value.first.split(';').first.trim().toLowerCase();
      }
    }
    return null;
  }

  /// Whether the body looks like HTML, so the UI can offer a rendered
  /// preview instead of (or alongside) the raw-text view.
  bool get isHtml {
    final ct = contentType;
    if (ct != null) return ct.contains('html');
    if (body is! String) return false;
    final trimmed = (body as String).trimLeft().toLowerCase();
    return trimmed.startsWith('<!doctype html') || trimmed.startsWith('<html');
  }

  Map<String, dynamic> toJson() => {
    'ok': ok,
    'statusCode': statusCode,
    'statusMessage': statusMessage,
    'headers': headers,
    'body': body,
    'durationMs': duration.inMilliseconds,
    'errorMessage': errorMessage,
    'isOffline': isOffline,
  };

  /// Same as [toJson] but with the response body omitted — used when
  /// persisting history, where bodies are stored separately so the
  /// always-loaded snapshot list stays cheap to read and hold in memory.
  Map<String, dynamic> toMetadataJson() => toJson()..['body'] = null;

  RequestResult withBody(dynamic newBody) => RequestResult(
    ok: ok,
    statusCode: statusCode,
    statusMessage: statusMessage,
    headers: headers,
    body: newBody,
    duration: duration,
    errorMessage: errorMessage,
    isOffline: isOffline,
  );

  factory RequestResult.fromJson(Map<String, dynamic> json) {
    return RequestResult(
      ok: json['ok'] as bool? ?? false,
      statusCode: json['statusCode'] as int?,
      statusMessage: json['statusMessage'] as String?,
      headers:
          (json['headers'] as Map?)?.map((key, value) => MapEntry(key.toString(), (value as List).map((e) => e.toString()).toList())) ?? const {},
      body: json['body'],
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      errorMessage: json['errorMessage'] as String?,
      isOffline: json['isOffline'] as bool? ?? false,
    );
  }
}
