import 'package:relay/core/models/api_request_model.dart';

enum CollectionRunStatus {
  pending,
  running,
  success,
  failed,
}

class CollectionRunResult {
  const CollectionRunResult({
    required this.request,
    required this.status,
    this.statusCode,
    this.statusMessage,
    this.duration,
    this.errorMessage,
  });

  final ApiRequestModel request;
  final CollectionRunStatus status;
  final int? statusCode;
  final String? statusMessage;
  final Duration? duration;
  final String? errorMessage;

  bool get isComplete =>
      status == CollectionRunStatus.success || status == CollectionRunStatus.failed;

  bool get isSuccess => status == CollectionRunStatus.success;

  CollectionRunResult copyWith({
    CollectionRunStatus? status,
    int? statusCode,
    String? statusMessage,
    Duration? duration,
    String? errorMessage,
  }) {
    return CollectionRunResult(
      request: request,
      status: status ?? this.status,
      statusCode: statusCode ?? this.statusCode,
      statusMessage: statusMessage ?? this.statusMessage,
      duration: duration ?? this.duration,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  factory CollectionRunResult.pending(ApiRequestModel request) {
    return CollectionRunResult(
      request: request,
      status: CollectionRunStatus.pending,
    );
  }
}


