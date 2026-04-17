import 'package:relay/core/services/role_node_api/role_node_endpoints.dart';
import 'package:relay/core/services/role_node_api/role_node_http.dart';

class CollectionsApiClient {
  CollectionsApiClient({required String baseUrl, required String accessToken, String? workspaceId})
    : _http = RoleNodeHttp(baseUrl: baseUrl, accessToken: accessToken, workspaceId: workspaceId);

  final RoleNodeHttp _http;

  Future<String> resolveWorkspaceId() async {
    return _http.resolveWorkspaceId();
  }

  Future<List<Map<String, dynamic>>> listCollections({String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.get(RoleNodeEndpoints.workspaceCollections(wid));
    return _asList(data);
  }

  Future<Map<String, dynamic>> getCollection({required String collectionId, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.get(RoleNodeEndpoints.workspaceCollection(wid, collectionId));
    return _asMap(data);
  }

  Future<Map<String, dynamic>> createCollection({required String name, String? description, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final payload = {
      'name': name,
      ...?description != null ? {'description': description} : null,
    };
    final data = await _http.post(RoleNodeEndpoints.workspaceCollections(wid), data: payload);
    return _asMap(data);
  }

  Future<Map<String, dynamic>> updateCollection({required String collectionId, String? name, String? description, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (description != null) payload['description'] = description;
    final data = await _http.patch(RoleNodeEndpoints.workspaceCollection(wid, collectionId), data: payload);
    return _asMap(data);
  }

  Future<void> deleteCollection({required String collectionId, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    await _http.delete(RoleNodeEndpoints.workspaceCollection(wid, collectionId));
  }

  Future<List<Map<String, dynamic>>> listEndpoints({required String collectionId, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.get(RoleNodeEndpoints.workspaceCollectionEndpoints(wid, collectionId));
    return _asList(data);
  }

  Future<Map<String, dynamic>> getEndpoint({required String collectionId, required String endpointId, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.get(RoleNodeEndpoints.workspaceCollectionEndpoint(wid, collectionId, endpointId));
    return _asMap(data);
  }

  Future<Map<String, dynamic>> createEndpoint({required String collectionId, required Map<String, dynamic> payload, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.post(RoleNodeEndpoints.workspaceCollectionEndpoints(wid, collectionId), data: payload);
    return _asMap(data);
  }

  Future<Map<String, dynamic>> updateEndpoint({
    required String collectionId,
    required String endpointId,
    required Map<String, dynamic> payload,
    String? workspaceId,
  }) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.patch(RoleNodeEndpoints.workspaceCollectionEndpoint(wid, collectionId, endpointId), data: payload);
    return _asMap(data);
  }

  Future<void> deleteEndpoint({required String collectionId, required String endpointId, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    await _http.delete(RoleNodeEndpoints.workspaceCollectionEndpoint(wid, collectionId, endpointId));
  }

  Future<List<Map<String, dynamic>>> listEndpointExamples({required String collectionId, required String endpointId, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.get(RoleNodeEndpoints.workspaceEndpointExamples(wid, collectionId, endpointId));
    return _asList(data);
  }

  Future<Map<String, dynamic>> createEndpointExample({
    required String collectionId,
    required String endpointId,
    required Map<String, dynamic> payload,
    String? workspaceId,
  }) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.post(RoleNodeEndpoints.workspaceEndpointExamples(wid, collectionId, endpointId), data: payload);
    return _asMap(data);
  }

  Future<Map<String, dynamic>> updateEndpointExample({
    required String collectionId,
    required String endpointId,
    required String exampleId,
    required Map<String, dynamic> payload,
    String? workspaceId,
  }) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.patch(RoleNodeEndpoints.workspaceEndpointExample(wid, collectionId, endpointId, exampleId), data: payload);
    return _asMap(data);
  }

  Future<void> deleteEndpointExample({
    required String collectionId,
    required String endpointId,
    required String exampleId,
    String? workspaceId,
  }) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    await _http.delete(RoleNodeEndpoints.workspaceEndpointExample(wid, collectionId, endpointId, exampleId));
  }

  Future<List<Map<String, dynamic>>> listFolders({required String collectionId, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final data = await _http.get(RoleNodeEndpoints.workspaceCollectionFolders(wid, collectionId));
    return _asList(data);
  }

  Future<Map<String, dynamic>> createFolder({
    required String collectionId,
    required String name,
    String? parentFolderId,
    int? position,
    String? workspaceId,
  }) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final payload = <String, dynamic>{'name': name};
    if (parentFolderId != null) payload['parentFolderId'] = parentFolderId;
    if (position != null) payload['position'] = position;
    final data = await _http.post(RoleNodeEndpoints.workspaceCollectionFolders(wid, collectionId), data: payload);
    return _asMap(data);
  }

  Future<Map<String, dynamic>> updateFolder({
    required String collectionId,
    required String folderId,
    String? name,
    int? position,
    String? workspaceId,
  }) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (position != null) payload['position'] = position;
    final data = await _http.patch(RoleNodeEndpoints.workspaceCollectionFolder(wid, collectionId, folderId), data: payload);
    return _asMap(data);
  }

  Future<void> deleteFolder({required String collectionId, required String folderId, String? workspaceId}) async {
    final wid = await _resolveWorkspaceId(workspaceId);
    await _http.delete(RoleNodeEndpoints.workspaceCollectionFolder(wid, collectionId, folderId));
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
