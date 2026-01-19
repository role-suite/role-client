import 'package:relay/core/models/api_request_model.dart';

/// Represents a single item in a request chain
class RequestChainItem {
  final String requestId;
  final String requestName;
  final int delayMs; // Delay in milliseconds before executing this request
  final bool usePreviousResponse; // Whether to inject previous response body

  RequestChainItem({
    required this.requestId,
    required this.requestName,
    this.delayMs = 0,
    this.usePreviousResponse = false,
  });

  RequestChainItem copyWith({
    String? requestId,
    String? requestName,
    int? delayMs,
    bool? usePreviousResponse,
  }) {
    return RequestChainItem(
      requestId: requestId ?? this.requestId,
      requestName: requestName ?? this.requestName,
      delayMs: delayMs ?? this.delayMs,
      usePreviousResponse: usePreviousResponse ?? this.usePreviousResponse,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'requestName': requestName,
      'delayMs': delayMs,
      'usePreviousResponse': usePreviousResponse,
    };
  }

  factory RequestChainItem.fromJson(Map<String, dynamic> json) {
    return RequestChainItem(
      requestId: json['requestId'] as String,
      requestName: json['requestName'] as String,
      delayMs: json['delayMs'] as int? ?? 0,
      usePreviousResponse: json['usePreviousResponse'] as bool? ?? false,
    );
  }
}
