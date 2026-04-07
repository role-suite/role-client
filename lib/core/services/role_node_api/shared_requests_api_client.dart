import 'package:relay/core/services/role_node_api/role_node_http.dart';

class SharedRequestsApiClient {
  SharedRequestsApiClient({required String baseUrl, required String accessToken, String? workspaceId})
    : _http = RoleNodeHttp(baseUrl: baseUrl, accessToken: accessToken, workspaceId: workspaceId);

  final RoleNodeHttp _http;

  String get baseUrl => _http.baseUrl;

  Future<String> resolveWorkspaceId() async {
    return _http.resolveWorkspaceId();
  }

  Future<List<Map<String, dynamic>>> listSharedRequests(String workspaceId) async {
    final data = await _http.get('/api/workspaces/$workspaceId/requests/shared');
    return _asList(data);
  }

  Future<Map<String, dynamic>> shareRequest({
    required String workspaceId,
    required String targetWorkspaceId,
    required Map<String, dynamic> request,
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'targetWorkspaceId': targetWorkspaceId,
      'request': request,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };
    final data = await _http.post('/api/workspaces/$workspaceId/requests/share', data: payload);
    return _asMap(data);
  }

  Future<Map<String, dynamic>> importSharedRequest({required String workspaceId, required String sharedRequestId, String? collectionId}) async {
    final payload = <String, dynamic>{if (collectionId != null && collectionId.trim().isNotEmpty) 'collectionId': collectionId.trim()};
    final data = await _http.post('/api/workspaces/$workspaceId/requests/shared/$sharedRequestId/import', data: payload);
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
