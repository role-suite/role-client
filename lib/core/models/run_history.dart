import '../utils/json_utils.dart';
import 'enums.dart';

class RunItemResult {
  final String requestId;
  final String requestName;
  final HttpMethod method;
  final RunStatus status;
  final int? statusCode;
  final Duration? duration;
  final String? errorMessage;
  final int? assertionsPassed;
  final int? assertionsTotal;
  final List<String> failedAssertions;

  const RunItemResult({
    required this.requestId,
    required this.requestName,
    required this.method,
    required this.status,
    this.statusCode,
    this.duration,
    this.errorMessage,
    this.assertionsPassed,
    this.assertionsTotal,
    this.failedAssertions = const [],
  });

  RunItemResult copyWith({
    RunStatus? status,
    int? statusCode,
    Duration? duration,
    String? errorMessage,
    int? assertionsPassed,
    int? assertionsTotal,
    List<String>? failedAssertions,
  }) {
    return RunItemResult(
      requestId: requestId,
      requestName: requestName,
      method: method,
      status: status ?? this.status,
      statusCode: statusCode ?? this.statusCode,
      duration: duration ?? this.duration,
      errorMessage: errorMessage ?? this.errorMessage,
      assertionsPassed: assertionsPassed ?? this.assertionsPassed,
      assertionsTotal: assertionsTotal ?? this.assertionsTotal,
      failedAssertions: failedAssertions ?? this.failedAssertions,
    );
  }

  bool get isSuccess => status == RunStatus.success && (statusCode ?? 0) < 400;

  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'requestName': requestName,
    'method': method.name,
    'status': status.name,
    'statusCode': statusCode,
    'durationMs': duration?.inMilliseconds,
    'errorMessage': errorMessage,
    'assertionsPassed': assertionsPassed,
    'assertionsTotal': assertionsTotal,
    'failedAssertions': failedAssertions,
  };

  factory RunItemResult.fromJson(Map<String, dynamic> json) {
    return RunItemResult(
      requestId: json['requestId'] as String,
      requestName: json['requestName'] as String? ?? '',
      method: HttpMethodX.fromString(json['method'] as String? ?? 'get'),
      status: RunStatusX.fromString(json['status'] as String? ?? 'pending'),
      statusCode: json['statusCode'] as int?,
      duration: json['durationMs'] != null ? Duration(milliseconds: json['durationMs'] as int) : null,
      errorMessage: json['errorMessage'] as String?,
      assertionsPassed: json['assertionsPassed'] as int?,
      assertionsTotal: json['assertionsTotal'] as int?,
      failedAssertions: (json['failedAssertions'] as List? ?? const []).map((e) => e.toString()).toList(),
    );
  }
}

class RunHistoryEntry {
  final String id;
  final String collectionId;
  final String collectionName;
  final String? environmentName;
  final DateTime startedAt;
  final DateTime completedAt;
  final List<RunItemResult> results;

  const RunHistoryEntry({
    required this.id,
    required this.collectionId,
    required this.collectionName,
    this.environmentName,
    required this.startedAt,
    required this.completedAt,
    required this.results,
  });

  int get total => results.length;
  int get passed => results.where((r) => r.isSuccess).length;
  int get failed => results.where((r) => r.status == RunStatus.failed || (r.status == RunStatus.success && !r.isSuccess)).length;
  Duration get totalDuration => completedAt.difference(startedAt);

  Map<String, dynamic> toJson() => {
    'id': id,
    'collectionId': collectionId,
    'collectionName': collectionName,
    'environmentName': environmentName,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt.toIso8601String(),
    'results': results.map((r) => r.toJson()).toList(),
  };

  factory RunHistoryEntry.fromJson(Map<String, dynamic> json) {
    return RunHistoryEntry(
      id: json['id'] as String,
      collectionId: json['collectionId'] as String? ?? '',
      collectionName: json['collectionName'] as String? ?? '',
      environmentName: json['environmentName'] as String?,
      startedAt: dateTimeFrom(json['startedAt']),
      completedAt: dateTimeFrom(json['completedAt']),
      results: (json['results'] as List? ?? const []).whereType<Map>().map((e) => RunItemResult.fromJson(Map<String, dynamic>.from(e))).toList(),
    );
  }
}
