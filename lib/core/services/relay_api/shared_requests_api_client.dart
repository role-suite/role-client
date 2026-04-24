import 'package:relay/core/services/relay_api/relay_api_http.dart';
import 'package:role_sdk/role_sdk_endpoints.dart';

class SharedRequestsApiClient {
  SharedRequestsApiClient({required String baseUrl, required String accessToken, String? workspaceId})
    : _http = RelayApiHttp(baseUrl: baseUrl, accessToken: accessToken, workspaceId: workspaceId);

  final RelayApiHttp _http;

  String get baseUrl => _http.baseUrl;

  Future<String> resolveWorkspaceId() async {
    return _http.resolveWorkspaceId();
  }

  Future<List<Map<String, dynamic>>> listSharedRequests(String workspaceId) async {
    final data = await _http.get(RoleSdkEndpoints.workspaceSharedRequests(workspaceId));
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
    final data = await _http.post(RoleSdkEndpoints.workspaceShareRequest(workspaceId), data: payload);
    return _asMap(data);
  }

  Future<Map<String, dynamic>> importSharedRequest({required String workspaceId, required String sharedRequestId, String? collectionId}) async {
    final payload = <String, dynamic>{if (collectionId != null && collectionId.trim().isNotEmpty) 'collectionId': collectionId.trim()};
    final data = await _http.post(RoleSdkEndpoints.workspaceImportSharedRequest(workspaceId, sharedRequestId), data: payload);
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
