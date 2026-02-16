import 'package:dio/dio.dart';

import 'package:relay/core/models/workspace_bundle.dart';
import 'package:relay/core/utils/logger.dart';
import 'package:relay/core/services/workspace_api/workspace_api_client.dart';

/// REST implementation: GET/PUT [baseUrl]/workspace with WorkspaceBundle JSON.
class RestWorkspaceClient implements WorkspaceApiClient {
  RestWorkspaceClient({required String baseUrl, String? apiKey}) {
    final normalizedBase = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    _baseUrl = normalizedBase.isEmpty ? '' : normalizedBase;
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: _buildHeaders(apiKey),
    ));
  }

  late final Dio _dio;
  late final String _baseUrl;

  Map<String, String>? _buildHeaders(String? apiKey) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (apiKey != null && apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    return headers;
  }

  String get _workspaceUrl => '$_baseUrl/workspace';

  @override
  Future<WorkspaceBundle> getWorkspace() async {
    if (_baseUrl.isEmpty) {
      throw ArgumentError('Remote workspace base URL is not set');
    }
    try {
      AppLogger.debug('REST: Fetching workspace from: $_workspaceUrl');
      final response = await _dio.get<Map<String, dynamic>>(_workspaceUrl);
      final data = response.data;
      if (data == null) {
        throw const FormatException('Empty response from workspace API');
      }
      return WorkspaceBundle.fromJson(data);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final statusMessage = e.response?.statusMessage;
      final responseData = e.response?.data;
      final url = e.requestOptions.uri.toString();

      AppLogger.error('RestWorkspaceClient.getWorkspace failed');
      AppLogger.error('  URL: $url');
      AppLogger.error('  Status: $statusCode $statusMessage');
      if (responseData != null) {
        AppLogger.error('  Response: $responseData');
      }

      if (statusCode == 400) {
        throw Exception(
          'Server returned 400 (Bad Request) for $url.\n'
          'Response: ${responseData ?? statusMessage}',
        );
      } else if (statusCode == 404) {
        throw Exception('Endpoint not found: $url');
      } else if (statusCode == 401 || statusCode == 403) {
        throw Exception('Authentication failed ($statusCode). Check your API key.');
      }
      rethrow;
    }
  }

  @override
  Future<void> putWorkspace(WorkspaceBundle bundle) async {
    if (_baseUrl.isEmpty) {
      throw ArgumentError('Remote workspace base URL is not set');
    }
    try {
      AppLogger.debug('REST: Pushing workspace to: $_workspaceUrl');
      await _dio.put(_workspaceUrl, data: bundle.toJson());
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final url = e.requestOptions.uri.toString();
      AppLogger.error('RestWorkspaceClient.putWorkspace failed: $url ($statusCode)');
      if (statusCode == 400) {
        throw Exception('Server returned 400 for PUT $url.');
      }
      rethrow;
    }
  }
}
