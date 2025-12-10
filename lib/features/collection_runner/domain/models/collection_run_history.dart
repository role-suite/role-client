import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/features/collection_runner/domain/models/collection_run_result.dart';

class CollectionRunHistory {
  const CollectionRunHistory({
    required this.id,
    required this.collection,
    this.environment,
    required this.completedAt,
    required this.results,
  });

  final String id;
  final CollectionModel collection;
  final EnvironmentModel? environment;
  final DateTime completedAt;
  final List<CollectionRunResult> results;

  int get totalRequests => results.length;
  int get completedRequests => results.where((r) => r.isComplete).length;
  int get successfulRequests => results.where((r) => r.isSuccess).length;
  int get failedRequests => results.where((r) => r.status == CollectionRunStatus.failed).length;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collection': collection.toJson(),
      'environment': environment?.toJson(),
      'completedAt': completedAt.toIso8601String(),
      'summary': {
        'totalRequests': totalRequests,
        'completedRequests': completedRequests,
        'successfulRequests': successfulRequests,
        'failedRequests': failedRequests,
      },
      'results': results.map((result) {
        return {
          'request': result.request.toJson(),
          'status': result.status.name,
          'statusCode': result.statusCode,
          'statusMessage': result.statusMessage,
          'duration': result.duration?.inMilliseconds,
          'durationFormatted': result.duration != null
              ? '${result.duration!.inSeconds}s ${result.duration!.inMilliseconds % 1000}ms'
              : null,
          'errorMessage': result.errorMessage,
          'isSuccess': result.isSuccess,
          'isComplete': result.isComplete,
        };
      }).toList(),
    };
  }

  factory CollectionRunHistory.fromJson(Map<String, dynamic> json) {
    // Note: This is a simplified version. For full deserialization,
    // you'd need to reconstruct CollectionRunResult objects from JSON.
    // For now, we'll store the raw JSON and reconstruct when needed.
    throw UnimplementedError('Use CollectionRunHistoryService to load history');
  }
}
