import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/services/api_service.dart';
import 'package:relay/core/utils/template_resolver.dart';
import 'package:relay/features/request_chain/domain/models/request_chain_item.dart';
import 'package:relay/features/request_chain/domain/models/request_chain_result.dart';
import 'package:relay/features/home/domain/repositories/environment_repository.dart';

/// Service for executing request chains with delays and response body injection
class RequestChainService {
  final EnvironmentRepository _environmentRepository;

  RequestChainService(this._environmentRepository);

  /// Execute a chain of requests sequentially
  Future<RequestChainResult> executeChain({
    required List<RequestChainItem> chainItems,
    required List<ApiRequestModel> requests,
    required EnvironmentModel? environment,
    required Function(int index, ApiRequestModel request) onRequestStart,
    required Function(int index, RequestChainItemResult result) onRequestComplete,
  }) async {
    final results = <RequestChainItemResult>[];
    final stopwatch = Stopwatch()..start();
    String? previousResponseBody;

    for (int i = 0; i < chainItems.length; i++) {
      final chainItem = chainItems[i];
      
      // Find the request model
      final request = requests.firstWhere(
        (r) => r.id == chainItem.requestId,
        orElse: () => throw Exception('Request ${chainItem.requestId} not found'),
      );

      // Apply delay if specified
      if (chainItem.delayMs > 0 && i > 0) {
        await Future.delayed(Duration(milliseconds: chainItem.delayMs));
      }

      // Notify that request is starting
      onRequestStart(i, request);

      // Use request's saved environment if it exists, otherwise use chain's environment
      EnvironmentModel? requestEnvironment = environment;
      if (request.environmentName != null) {
        requestEnvironment = await _environmentRepository.getEnvironmentByName(request.environmentName!);
        // If the saved environment doesn't exist anymore, fall back to chain environment
        requestEnvironment ??= environment;
      }
      
      // Prepare request with previous response body if needed
      // First request (index 0) can never use previous response
      final canUsePreviousResponse = i > 0 && chainItem.usePreviousResponse;
      final requestBody = _prepareRequestBody(
        request: request,
        previousResponseBody: previousResponseBody,
        usePreviousResponse: canUsePreviousResponse,
        environment: requestEnvironment,
      );

      // Execute the request
      final result = await _executeRequest(
        request: request,
        body: requestBody,
        environment: requestEnvironment,
        index: i,
      );

      results.add(result);

      // Store response body for next request if available
      if (result.success && result.response != null) {
        previousResponseBody = _extractResponseBody(result.response!);
      } else {
        // If request failed, clear previous response body
        previousResponseBody = null;
      }

      // Notify that request completed
      onRequestComplete(i, result);
    }

    stopwatch.stop();

    final successCount = results.where((r) => r.success).length;
    final failureCount = results.length - successCount;

    return RequestChainResult(
      results: results,
      totalDuration: stopwatch.elapsed,
      allSucceeded: failureCount == 0,
      successCount: successCount,
      failureCount: failureCount,
    );
  }

  String? _prepareRequestBody({
    required ApiRequestModel request,
    String? previousResponseBody,
    required bool usePreviousResponse,
    required EnvironmentModel? environment,
  }) {
    String? body = request.body;

    if (body == null || body.trim().isEmpty) {
      return null;
    }

    // If we should use previous response and it exists, inject it
    if (usePreviousResponse && previousResponseBody != null) {
      // Create a variable map with the previous response
      final variables = <String, String>{
        'previousResponse': previousResponseBody,
      };

      // Merge with environment variables if available
      if (environment != null) {
        variables.addAll(environment.variables);
      }

      // Resolve templates in the body using TemplateResolver
      body = TemplateResolver.resolve(body, variables);
    } else if (environment != null) {
      // Just resolve environment variables
      body = _environmentRepository.resolveTemplate(body, environment);
    }

    return body;
  }

  Future<RequestChainItemResult> _executeRequest({
    required ApiRequestModel request,
    String? body,
    required EnvironmentModel? environment,
    required int index,
  }) async {
    final resolvedUrl = _environmentRepository.resolveTemplate(request.urlTemplate, environment);

    final resolvedHeaders = <String, String>{
      for (final entry in request.headers.entries)
        entry.key: _environmentRepository.resolveTemplate(entry.value, environment),
    };

    final resolvedQueryParams = <String, String>{
      for (final entry in request.queryParams.entries)
        entry.key: _environmentRepository.resolveTemplate(entry.value, environment),
    };

    final resolvedBody = (body != null && body.trim().isNotEmpty) ? body : null;

    final dio = ApiService.instance.dio;
    final stopwatch = Stopwatch()..start();

    try {
      final response = await dio.request<dynamic>(
        resolvedUrl,
        options: Options(
          method: request.method.name,
          headers: resolvedHeaders.isEmpty ? null : resolvedHeaders,
        ),
        queryParameters: resolvedQueryParams.isEmpty ? null : resolvedQueryParams,
        data: resolvedBody,
      );
      stopwatch.stop();

      return RequestChainItemResult(
        request: request,
        response: response,
        duration: stopwatch.elapsed,
        index: index,
        success: true,
      );
    } on DioException catch (e) {
      stopwatch.stop();
      return RequestChainItemResult(
        request: request,
        error: e,
        response: e.response,
        duration: stopwatch.elapsed,
        index: index,
        success: false,
      );
    } catch (e) {
      stopwatch.stop();
      return RequestChainItemResult(
        request: request,
        error: DioException(
          requestOptions: RequestOptions(path: resolvedUrl),
          error: e,
        ),
        duration: stopwatch.elapsed,
        index: index,
        success: false,
      );
    }
  }

  String _extractResponseBody(Response<dynamic> response) {
    if (response.data == null) return '';
    
    if (response.data is String) {
      return response.data as String;
    } else if (response.data is Map || response.data is List) {
      return const JsonEncoder.withIndent('  ').convert(response.data);
    } else {
      return response.data.toString();
    }
  }
}
