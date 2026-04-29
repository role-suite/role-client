import 'package:relay/core/models/workspace_bundle.dart';
import 'package:relay/core/services/role_sdk_http_compat.dart';
import 'package:relay/core/utils/logger.dart';
import 'package:relay/core/services/workspace_api/workspace_api_client.dart';

/// REST implementation: GET/PUT [baseUrl]/workspace with WorkspaceBundle JSON.
class RestWorkspaceClient implements WorkspaceApiClient {
  RestWorkspaceClient({required String baseUrl, String? apiKey}) {
    final normalizedBase = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    _baseUrl = normalizedBase.isEmpty ? RoleSdkHttpClient.defaultBackendBaseUrl : normalizedBase;
    _sdkHttp = RoleSdkHttpClient(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      defaultHeaders: _buildHeaders(apiKey),
    );
  }

  late final RoleSdkHttpClient _sdkHttp;
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
    try {
      AppLogger.debug('REST: Fetching workspace from: $_workspaceUrl');
      final response = await _sdkHttp.get<Map<String, dynamic>>('/workspace');
      final data = response.data;
      if (data == null) {
        throw const FormatException('Empty response from workspace API');
      }
      return WorkspaceBundle.fromJson(data);
    } on RoleSdkHttpException catch (e) {
      final statusCode = e.statusCode;
      final statusMessage = e.statusMessage;
      final responseData = e.responseData;
      final url = _workspaceUrl;

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
    try {
      AppLogger.debug('REST: Pushing workspace to: $_workspaceUrl');
      await _sdkHttp.request<void>(method: 'PUT', path: '/workspace', data: bundle.toJson());
    } on RoleSdkHttpException catch (e) {
      final statusCode = e.statusCode;
      final url = _workspaceUrl;
      AppLogger.error('RestWorkspaceClient.putWorkspace failed: $url ($statusCode)');
      if (statusCode == 400) {
        throw Exception('Server returned 400 for PUT $url.');
      }
      rethrow;
    }
  }
}
