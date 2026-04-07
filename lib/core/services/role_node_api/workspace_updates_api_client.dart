import 'package:relay/core/services/role_node_api/role_node_endpoints.dart';
import 'package:relay/core/services/role_node_api/role_node_http.dart';

abstract class WorkspaceUpdatesApi {
  Future<String> resolveWorkspaceId();
  Future<Map<String, dynamic>> getUpdates({required String workspaceId, required int since, required int limit});
}

class WorkspaceUpdatesApiClient implements WorkspaceUpdatesApi {
  WorkspaceUpdatesApiClient({required String baseUrl, required String accessToken, String? workspaceId})
    : _http = RoleNodeHttp(baseUrl: baseUrl, accessToken: accessToken, workspaceId: workspaceId);

  final RoleNodeHttp _http;

  @override
  Future<String> resolveWorkspaceId() => _http.resolveWorkspaceId();

  @override
  Future<Map<String, dynamic>> getUpdates({required String workspaceId, required int since, required int limit}) async {
    final data = await _http.get(RoleNodeEndpoints.workspaceUpdates(workspaceId), queryParameters: {'since': since, 'limit': limit});
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }
}
