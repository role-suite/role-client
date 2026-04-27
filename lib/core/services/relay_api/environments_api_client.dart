import 'package:relay/core/services/relay_api/role_sdk_endpoints.dart';
import 'package:relay/core/services/relay_api/relay_api_http.dart';

class EnvironmentsApiClient {
  EnvironmentsApiClient({required String baseUrl, required String accessToken, String? workspaceId})
    : _http = RelayApiHttp(baseUrl: baseUrl, accessToken: accessToken, workspaceId: workspaceId);

  final RelayApiHttp _http;

  Future<String> resolveWorkspaceId() async {
    return _http.resolveWorkspaceId();
  }

  Future<List<Map<String, dynamic>>> listEnvironments({String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.get(RoleSdkEndpoints.workspaceEnvironments(wid));
    return _asList(data);
  }

  Future<Map<String, dynamic>> getEnvironment({required String environmentId, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.get(RoleSdkEndpoints.workspaceEnvironment(wid, environmentId));
    return _asMap(data);
  }

  Future<Map<String, dynamic>> createEnvironment({required String name, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.post(RoleSdkEndpoints.workspaceEnvironments(wid), data: {'name': name});
    return _asMap(data);
  }

  Future<Map<String, dynamic>> updateEnvironment({required String environmentId, required String name, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.patch(RoleSdkEndpoints.workspaceEnvironment(wid, environmentId), data: {'name': name});
    return _asMap(data);
  }

  Future<void> deleteEnvironment({required String environmentId, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    await _http.delete(RoleSdkEndpoints.workspaceEnvironment(wid, environmentId));
  }

  Future<List<Map<String, dynamic>>> listVariables({required String environmentId, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.get(RoleSdkEndpoints.workspaceEnvironmentVariables(wid, environmentId));
    return _asList(data);
  }

  Future<Map<String, dynamic>> getVariable({required String environmentId, required String variableId, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.get(RoleSdkEndpoints.workspaceEnvironmentVariable(wid, environmentId, variableId));
    return _asMap(data);
  }

  Future<Map<String, dynamic>> createVariable({required String environmentId, required Map<String, dynamic> payload, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.post(RoleSdkEndpoints.workspaceEnvironmentVariables(wid, environmentId), data: payload);
    return _asMap(data);
  }

  Future<Map<String, dynamic>> updateVariable({
    required String environmentId,
    required String variableId,
    required Map<String, dynamic> payload,
    String? workspaceId,
  }) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.patch(RoleSdkEndpoints.workspaceEnvironmentVariable(wid, environmentId, variableId), data: payload);
    return _asMap(data);
  }

  Future<void> deleteVariable({required String environmentId, required String variableId, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    await _http.delete(RoleSdkEndpoints.workspaceEnvironmentVariable(wid, environmentId, variableId));
  }

  Future<String> _resolveWorkspaceId(String? workspaceId) async {
    final trimmed = workspaceId?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return _http.resolveWorkspaceId();
  }

  static List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().toList();
    }

    if (value is Map<String, dynamic>) {
      final items = value['items'] ?? value['data'];
      if (items is List) {
        return items.whereType<Map<String, dynamic>>().toList();
      }
    }

    return const [];
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    return <String, dynamic>{};
  }
}
