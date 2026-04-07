import 'package:relay/core/services/role_node_api/role_node_endpoints.dart';
import 'package:relay/core/services/role_node_api/role_node_http.dart';

class WorkspacesApiClient {
  WorkspacesApiClient({required String baseUrl, required String accessToken, String? workspaceId})
    : _http = RoleNodeHttp(baseUrl: baseUrl, accessToken: accessToken, workspaceId: workspaceId);

  final RoleNodeHttp _http;

  Future<List<Map<String, dynamic>>> listWorkspaces() async {
    final data = await _http.get(RoleNodeEndpoints.workspaces);
    return _asList(data);
  }

  Future<String> resolveWorkspaceId() async {
    return _http.resolveWorkspaceId();
  }

  Future<Map<String, dynamic>> createWorkspace(String name) async {
    final data = await _http.post(RoleNodeEndpoints.workspaces, data: {'name': name});
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getWorkspace(String workspaceId) async {
    final data = await _http.get(RoleNodeEndpoints.workspace(workspaceId));
    return _asMap(data);
  }

  Future<List<Map<String, dynamic>>> listMembers(String workspaceId) async {
    final data = await _http.get(RoleNodeEndpoints.workspaceMembers(workspaceId));
    return _asList(data);
  }

  Future<Map<String, dynamic>> addMember({required String workspaceId, required String email, required String role}) async {
    final data = await _http.post(RoleNodeEndpoints.workspaceMembers(workspaceId), data: {'email': email, 'role': role});
    return _asMap(data);
  }

  Future<Map<String, dynamic>> createInvitation({required String workspaceId, required String email, required String role}) async {
    final data = await _http.post(RoleNodeEndpoints.workspaceInvitations(workspaceId), data: {'email': email, 'role': role});
    return _asMap(data);
  }

  Future<Map<String, dynamic>> joinWorkspace({required String token}) async {
    final data = await _http.post(RoleNodeEndpoints.workspaceJoin, data: {'token': token});
    return _asMap(data);
  }

  Future<Map<String, dynamic>> updateMemberRole({required String workspaceId, required String memberUserId, required String role}) async {
    final data = await _http.patch(RoleNodeEndpoints.workspaceMember(workspaceId, memberUserId), data: {'role': role});
    return _asMap(data);
  }

  Future<void> removeMember({required String workspaceId, required String memberUserId}) async {
    await _http.delete(RoleNodeEndpoints.workspaceMember(workspaceId, memberUserId));
  }

  Future<void> leaveWorkspace(String workspaceId) async {
    await _http.post(RoleNodeEndpoints.workspaceLeave(workspaceId));
  }

  Future<Map<String, dynamic>> convertToTeam({required String workspaceId, String? teamName}) async {
    final data = await _http.post(
      RoleNodeEndpoints.workspaceConvertToTeam(workspaceId),
      data: {if (teamName != null && teamName.trim().isNotEmpty) 'name': teamName.trim()},
    );
    return _asMap(data);
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
