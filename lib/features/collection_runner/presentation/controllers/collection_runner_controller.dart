import 'package:dio/dio.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/services/api_service.dart';
import 'package:relay/features/collection_runner/data/services/collection_run_history_service.dart';
import 'package:relay/features/collection_runner/domain/models/collection_run_result.dart';
import 'package:relay/features/home/domain/repositories/environment_repository.dart';
import 'package:relay/features/home/domain/usecases/get_requests_by_collection_usecase.dart';

class CollectionRunnerState {
  static const _sentinel = Object();

  const CollectionRunnerState({
    required this.isRunning,
    required this.isLoadingRequests,
    required this.results,
    this.collection,
    this.environment,
    this.errorMessage,
    this.completedAt,
  });

  final bool isRunning;
  final bool isLoadingRequests;
  final List<CollectionRunResult> results;
  final CollectionModel? collection;
  final EnvironmentModel? environment;
  final String? errorMessage;
  final DateTime? completedAt;

  int get totalRequests => results.length;
  int get completedRequests =>
      results.where((result) => result.isComplete).length;

  double? get progress {
    if (totalRequests == 0) {
      return null;
    }
    return completedRequests / totalRequests;
  }

  bool get hasResults => results.isNotEmpty;

  CollectionRunnerState copyWith({
    bool? isRunning,
    bool? isLoadingRequests,
    List<CollectionRunResult>? results,
    Object? collection = _sentinel,
    Object? environment = _sentinel,
    Object? errorMessage = _sentinel,
    Object? completedAt = _sentinel,
  }) {
    return CollectionRunnerState(
      isRunning: isRunning ?? this.isRunning,
      isLoadingRequests: isLoadingRequests ?? this.isLoadingRequests,
      results: results ?? this.results,
      collection: identical(collection, _sentinel)
          ? this.collection
          : collection as CollectionModel?,
      environment: identical(environment, _sentinel)
          ? this.environment
          : environment as EnvironmentModel?,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      completedAt: identical(completedAt, _sentinel)
          ? this.completedAt
          : completedAt as DateTime?,
    );
  }

  factory CollectionRunnerState.initial() {
    return const CollectionRunnerState(
      isRunning: false,
      isLoadingRequests: false,
      results: [],
    );
  }
}

class CollectionRunnerController extends StateNotifier<CollectionRunnerState> {
  CollectionRunnerController(
    this._getRequestsByCollectionUseCase,
    this._environmentRepository,
    this._historyService,
  ) : super(CollectionRunnerState.initial());

  final GetRequestsByCollectionUseCase _getRequestsByCollectionUseCase;
  final EnvironmentRepository _environmentRepository;
  final CollectionRunHistoryService _historyService;

  Future<void> runCollection({
    required CollectionModel collection,
    required EnvironmentModel? environment,
  }) async {
    state = state.copyWith(
      isRunning: true,
      isLoadingRequests: true,
      collection: collection,
      environment: environment,
      results: const [],
      errorMessage: null,
      completedAt: null,
    );

    try {
      final requests = await _getRequestsByCollectionUseCase(collection.id);
      if (requests.isEmpty) {
        state = state.copyWith(
          isRunning: false,
          isLoadingRequests: false,
          results: const [],
          errorMessage: 'Collection "${collection.name}" has no requests.',
        );
        return;
      }

      var resultList = requests.map(CollectionRunResult.pending).toList();
      state = state.copyWith(
        results: resultList,
        isLoadingRequests: false,
        errorMessage: null,
      );

      for (var index = 0; index < requests.length; index++) {
        resultList = List.of(resultList);
        resultList[index] =
            resultList[index].copyWith(status: CollectionRunStatus.running);
        state = state.copyWith(results: resultList);

        final outcome = await _executeRequest(
          requests[index],
          environment,
        );

        resultList = List.of(resultList);
        resultList[index] = outcome;
        state = state.copyWith(results: resultList);
      }

      final completedAt = DateTime.now();
      state = state.copyWith(
        isRunning: false,
        completedAt: completedAt,
      );

      // Auto-save results to history
      if (state.collection != null && state.results.isNotEmpty) {
        try {
          await _historyService.saveHistory(
            collection: state.collection!,
            environment: state.environment,
            completedAt: completedAt,
            results: state.results,
          );
        } catch (e) {
          // Log error but don't fail the run
          print('Failed to save collection run history: $e');
        }
      }
    } catch (e) {
      state = state.copyWith(
        isRunning: false,
        isLoadingRequests: false,
        errorMessage: 'Failed to run collection: $e',
      );
    }
  }

  Future<CollectionRunResult> _executeRequest(
    ApiRequestModel request,
    EnvironmentModel? environment,
  ) async {
    final resolvedUrl =
        _environmentRepository.resolveTemplate(request.urlTemplate, environment);

    final resolvedHeaders = <String, String>{
      for (final entry in request.headers.entries)
        entry.key: _environmentRepository.resolveTemplate(
          entry.value,
          environment,
        ),
    };

    final resolvedQueryParams = <String, String>{
      for (final entry in request.queryParams.entries)
        entry.key: _environmentRepository.resolveTemplate(
          entry.value,
          environment,
        ),
    };

    final rawBody = request.body;
    final resolvedBody = (rawBody != null && rawBody.trim().isNotEmpty)
        ? _environmentRepository.resolveTemplate(rawBody, environment)
        : null;

    final dio = ApiService.instance.dio;
    final stopwatch = Stopwatch()..start();

    try {
      final response = await dio.request<dynamic>(
        resolvedUrl,
        options: Options(
          method: request.method.name,
          headers: resolvedHeaders.isEmpty ? null : resolvedHeaders,
        ),
        queryParameters:
            resolvedQueryParams.isEmpty ? null : resolvedQueryParams,
        data: resolvedBody,
      );
      stopwatch.stop();

      return CollectionRunResult(
        request: request,
        status: CollectionRunStatus.success,
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        duration: stopwatch.elapsed,
      );
    } on DioException catch (e) {
      stopwatch.stop();
      return CollectionRunResult(
        request: request,
        status: CollectionRunStatus.failed,
        statusCode: e.response?.statusCode,
        statusMessage: e.response?.statusMessage ?? e.message,
        duration: stopwatch.elapsed,
        errorMessage: e.message ?? e.error?.toString(),
      );
    } catch (e) {
      stopwatch.stop();
      return CollectionRunResult(
        request: request,
        status: CollectionRunStatus.failed,
        duration: stopwatch.elapsed,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() {
    state = CollectionRunnerState.initial();
  }
}


