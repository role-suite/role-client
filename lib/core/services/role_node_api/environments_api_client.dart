import 'package:relay/core/services/role_node_api/role_node_endpoints.dart';
import 'package:relay/core/services/role_node_api/role_node_http.dart';

class EnvironmentsApiClient {
  EnvironmentsApiClient({required String baseUrl, required String accessToken, String? workspaceId})
    : _http = RoleNodeHttp(baseUrl: baseUrl, accessToken: accessToken, workspaceId: workspaceId);

  final RoleNodeHttp _http;

  Future<String> resolveWorkspaceId() async {
    return _http.resolveWorkspaceId();
  }

  Future<List<Map<String, dynamic>>> listEnvironments({String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.get(RoleNodeEndpoints.workspaceEnvironments(wid));
    return _asList(data);
  }

  Future<Map<String, dynamic>> getEnvironment({required String environmentId, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.get(RoleNodeEndpoints.workspaceEnvironment(wid, environmentId));
    return _asMap(data);
  }

  Future<Map<String, dynamic>> createEnvironment({required String name, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.post(RoleNodeEndpoints.workspaceEnvironments(wid), data: {'name': name});
    return _asMap(data);
  }

  Future<Map<String, dynamic>> updateEnvironment({required String environmentId, required String name, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.patch(RoleNodeEndpoints.workspaceEnvironment(wid, environmentId), data: {'name': name});
    return _asMap(data);
  }

  Future<void> deleteEnvironment({required String environmentId, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    await _http.delete(RoleNodeEndpoints.workspaceEnvironment(wid, environmentId));
  }

  Future<List<Map<String, dynamic>>> listVariables({required String environmentId, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.get(RoleNodeEndpoints.workspaceEnvironmentVariables(wid, environmentId));
    return _asList(data);
  }

  Future<Map<String, dynamic>> getVariable({required String environmentId, required String variableId, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.get(RoleNodeEndpoints.workspaceEnvironmentVariable(wid, environmentId, variableId));
    return _asMap(data);
  }

  Future<Map<String, dynamic>> createVariable({required String environmentId, required Map<String, dynamic> payload, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.post(RoleNodeEndpoints.workspaceEnvironmentVariables(wid, environmentId), data: payload);
    return _asMap(data);
  }

  Future<Map<String, dynamic>> updateVariable({
    required String environmentId,
    required String variableId,
    required Map<String, dynamic> payload,
    String? workspaceId,
  }) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.patch(RoleNodeEndpoints.workspaceEnvironmentVariable(wid, environmentId, variableId), data: payload);
    return _asMap(data);
  }

  Future<void> deleteVariable({required String environmentId, required String variableId, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    await _http.delete(RoleNodeEndpoints.workspaceEnvironmentVariable(wid, environmentId, variableId));
  }

  Future<String> _resolveWorkspaceId(String? workspaceId) async {
    final trimmed = workspaceId?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return _http.resolveWorkspaceId();
  }

  static List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map<String, dynamic>>().toList();
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    return <String, dynamic>{};
  }
}
