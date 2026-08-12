import 'dart:convert';

class RequestResult {
  final bool ok;
  final int? statusCode;
  final String? statusMessage;
  final Map<String, List<String>> headers;
  final dynamic body;
  final Duration duration;
  final String? errorMessage;
  final bool isOffline;

  const RequestResult({
    required this.ok,
    this.statusCode,
    this.statusMessage,
    this.headers = const {},
    this.body,
    required this.duration,
    this.errorMessage,
    this.isOffline = false,
  });

  int get sizeBytes {
    if (body == null) return 0;
    if (body is String) return utf8.encode(body as String).length;
    try {
      return utf8.encode(jsonEncode(body)).length;
    } catch (_) {
      return body.toString().length;
    }
  }

  String get prettyBody {
    if (body == null) return '';
    if (body is Map || body is List) {
      try {
        return const JsonEncoder.withIndent('  ').convert(body);
      } catch (_) {
        return body.toString();
      }
    }
    if (body is String) {
      final text = body as String;
      try {
        return const JsonEncoder.withIndent('  ').convert(jsonDecode(text));
      } catch (_) {
        return text;
      }
    }
    return body.toString();
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

  factory RequestResult.fromJson(Map<String, dynamic> json) {
    return RequestResult(
      ok: json['ok'] as bool? ?? false,
      statusCode: json['statusCode'] as int?,
      statusMessage: json['statusMessage'] as String?,
      headers:
          (json['headers'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), (value as List).map((e) => e.toString()).toList()),
          ) ??
          const {},
      body: json['body'],
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      errorMessage: json['errorMessage'] as String?,
      isOffline: json['isOffline'] as bool? ?? false,
    );
  }
}
