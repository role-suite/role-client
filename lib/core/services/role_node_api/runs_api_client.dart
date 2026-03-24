import 'package:relay/core/services/role_node_api/role_node_http.dart';

class RunsApiClient {
  RunsApiClient({required String baseUrl, required String accessToken}) : _http = RoleNodeHttp(baseUrl: baseUrl, accessToken: accessToken);

  final RoleNodeHttp _http;

  Future<Map<String, dynamic>> createRun({String? workspaceId, required Map<String, dynamic> payload}) async {
    final wid = workspaceId ?? await _http.resolveWorkspaceId();
    final data = await _http.post('/api/workspaces/$wid/runs', data: payload);
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getRun(String runId, {String? workspaceId}) async {
    final wid = workspaceId ?? await _http.resolveWorkspaceId();
    final data = await _http.get('/api/workspaces/$wid/runs/$runId');
    return _asMap(data);
  }

  Future<Map<String, dynamic>> cancelRun(String runId, {String? workspaceId}) async {
    final wid = workspaceId ?? await _http.resolveWorkspaceId();
    final data = await _http.post('/api/workspaces/$wid/runs/$runId/cancel');
    return _asMap(data);
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    return <String, dynamic>{};
  }
}
