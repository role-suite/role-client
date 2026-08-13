import '../utils/json_utils.dart';
import 'enums.dart';
import 'request_result.dart';

class ResponseSnapshot {
  final String id;
  final String requestId;
  final String requestName;
  final HttpMethod method;
  final String url;
  final DateTime timestamp;
  final RequestResult result;

  const ResponseSnapshot({
    required this.id,
    required this.requestId,
    required this.requestName,
    required this.method,
    required this.url,
    required this.timestamp,
    required this.result,
  });

  Map<String, dynamic> toJson({bool includeBody = true}) => {
    'id': id,
    'requestId': requestId,
    'requestName': requestName,
    'method': method.name,
    'url': url,
    'timestamp': timestamp.toIso8601String(),
    'result': includeBody ? result.toJson() : result.toMetadataJson(),
  };

  /// For history persistence — body is stored in a separate per-snapshot
  /// file, so the list every request keeps in memory never holds bodies.
  Map<String, dynamic> toMetadataJson() => toJson(includeBody: false);

  ResponseSnapshot withResult(RequestResult newResult) =>
      ResponseSnapshot(id: id, requestId: requestId, requestName: requestName, method: method, url: url, timestamp: timestamp, result: newResult);

  factory ResponseSnapshot.fromJson(Map<String, dynamic> json) {
    return ResponseSnapshot(
      id: json['id'] as String,
      requestId: json['requestId'] as String,
      requestName: json['requestName'] as String? ?? '',
      method: HttpMethodX.fromString(json['method'] as String? ?? 'get'),
      url: json['url'] as String? ?? '',
      timestamp: dateTimeFrom(json['timestamp']),
      result: RequestResult.fromJson(Map<String, dynamic>.from(json['result'] as Map? ?? const {})),
    );
  }
}
