import 'package:relay/core/services/relay_api/role_sdk_endpoints.dart';
import 'package:relay/core/services/relay_api/relay_api_http.dart';

class WorkspacesApiClient {
  WorkspacesApiClient({required String baseUrl, required String accessToken, String? workspaceId})
    : _http = RelayApiHttp(baseUrl: baseUrl, accessToken: accessToken, workspaceId: workspaceId);

  final RelayApiHttp _http;

  Future<List<Map<String, dynamic>>> listWorkspaces() async {
    final data = await _http.get(RoleSdkEndpoints.workspaces);
    return _asList(data);
  }

  Future<String> resolveWorkspaceId() async {
    return _http.resolveWorkspaceId();
  }

  Future<Map<String, dynamic>> createWorkspace(String name) async {
    final data = await _http.post(RoleSdkEndpoints.workspaces, data: {'name': name});
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getWorkspace(String workspaceId) async {
    final data = await _http.get(RoleSdkEndpoints.workspace(workspaceId));
    return _asMap(data);
  }

  Future<List<Map<String, dynamic>>> listMembers(String workspaceId) async {
    final data = await _http.get(RoleSdkEndpoints.workspaceMembers(workspaceId));
    return _asList(data);
  }

  Future<Map<String, dynamic>> addMember({required String workspaceId, required String email, required String role}) async {
    final data = await _http.post(RoleSdkEndpoints.workspaceMembers(workspaceId), data: {'email': email, 'role': role});
    return _asMap(data);
  }

  Future<Map<String, dynamic>> createInvitation({required String workspaceId, required String email, required String role}) async {
    final data = await _http.post(RoleSdkEndpoints.workspaceInvitations(workspaceId), data: {'email': email, 'role': role});
    return _asMap(data);
  }

  Future<Map<String, dynamic>> joinWorkspace({required String token}) async {
    final data = await _http.post(RoleSdkEndpoints.workspaceJoin, data: {'token': token});
    return _asMap(data);
  }

  Future<Map<String, dynamic>> updateMemberRole({required String workspaceId, required String memberUserId, required String role}) async {
    final data = await _http.patch(RoleSdkEndpoints.workspaceMember(workspaceId, memberUserId), data: {'role': role});
    return _asMap(data);
  }

  Future<void> removeMember({required String workspaceId, required String memberUserId}) async {
    await _http.delete(RoleSdkEndpoints.workspaceMember(workspaceId, memberUserId));
  }

  Future<void> leaveWorkspace(String workspaceId) async {
    await _http.post(RoleSdkEndpoints.workspaceLeave(workspaceId));
  }

  Future<Map<String, dynamic>> convertToTeam({required String workspaceId, String? teamName}) async {
    final data = await _http.post(
      RoleSdkEndpoints.workspaceConvertToTeam(workspaceId),
      data: {if (teamName != null && teamName.trim().isNotEmpty) 'name': teamName.trim()},
    );
    return _asMap(data);
  }

  static List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().toList();
    }

    if (value is Map<String, dynamic>) {
      final items = value['items'] ?? value['data'] ?? value['results'] ?? value['members'] ?? value['workspaces'] ?? value['invitations'];
      if (items is List) {
        return items.whereType<Map<String, dynamic>>().toList();
      }

      if (items is Map<String, dynamic>) {
        final nestedItems = items['items'] ?? items['data'] ?? items['results'];
        if (nestedItems is List) {
          return nestedItems.whereType<Map<String, dynamic>>().toList();
        }
      }
    }

    return const [];
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    return <String, dynamic>{};
  }
}
