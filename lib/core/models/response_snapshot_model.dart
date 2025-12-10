import 'package:relay/core/models/request_result_model.dart';

import 'api_request_model.dart';

class ResponseSnapshotModel {
  final String id;
  final String requestId;
  final String requestName;
  final DateTime timestamp;
  final RequestResultModel result;

  ResponseSnapshotModel({required this.id, required this.requestId, required this.requestName, required this.timestamp, required this.result});

  Map<String, dynamic> toJson() {
    return {'id': id, 'requestId': requestId, 'requestName': requestName, 'timestamp': timestamp.toIso8601String(), 'result': result.toJson()};
  }

  factory ResponseSnapshotModel.fromJson(Map<String, dynamic> json) {
    return ResponseSnapshotModel(
      id: json['id'] as String,
      requestId: json['requestId'] as String,
      requestName: json['requestName'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      result: RequestResultModel.fromJson(Map<String, dynamic>.from(json['result'] ?? const {})),
    );
  }

  /// Helper to create from an ApiRequest + RequestResult
  factory ResponseSnapshotModel.fromRequestAndResult(ApiRequestModel request, RequestResultModel result, String snapshotId) {
    return ResponseSnapshotModel(id: snapshotId, requestId: request.id, requestName: request.name, timestamp: DateTime.now().toUtc(), result: result);
  }
}
