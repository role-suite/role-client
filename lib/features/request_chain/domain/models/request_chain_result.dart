import 'package:dio/dio.dart';
import 'package:relay/core/models/api_request_model.dart';

/// Result of executing a single request in a chain
class RequestChainItemResult {
  final ApiRequestModel request;
  final Response<dynamic>? response;
  final DioException? error;
  final Duration duration;
  final int index; // Position in the chain
  final bool success;

  RequestChainItemResult({
    required this.request,
    this.response,
    this.error,
    required this.duration,
    required this.index,
    required this.success,
  });
}

/// Result of executing an entire request chain
class RequestChainResult {
  final List<RequestChainItemResult> results;
  final Duration totalDuration;
  final bool allSucceeded;
  final int successCount;
  final int failureCount;

  RequestChainResult({
    required this.results,
    required this.totalDuration,
    required this.allSucceeded,
    required this.successCount,
    required this.failureCount,
  });
}
