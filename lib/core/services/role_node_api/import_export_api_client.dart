import 'package:relay/core/services/role_node_api/role_node_http.dart';

class ImportExportApiClient {
  ImportExportApiClient({required String baseUrl, required String accessToken}) : _http = RoleNodeHttp(baseUrl: baseUrl, accessToken: accessToken);

  final RoleNodeHttp _http;

  Future<List<Map<String, dynamic>>> listJobs({String? workspaceId}) async {
    final wid = workspaceId ?? await _http.resolveWorkspaceId();
    final data = await _http.get('/api/workspaces/$wid/import-export/jobs');
    return _asList(data);
  }

  Future<Map<String, dynamic>> getJob(String jobId, {String? workspaceId}) async {
    final wid = workspaceId ?? await _http.resolveWorkspaceId();
    final data = await _http.get('/api/workspaces/$wid/import-export/jobs/$jobId');
    return _asMap(data);
  }

  Future<Map<String, dynamic>> createExport({
    String? workspaceId,
    String format = 'json',
    bool includeCollections = true,
    bool includeEnvironments = true,
    bool includeRuns = false,
  }) async {
    final wid = workspaceId ?? await _http.resolveWorkspaceId();
    final data = await _http.post(
      '/api/workspaces/$wid/import-export/exports',
      data: {'format': format, 'includeCollections': includeCollections, 'includeEnvironments': includeEnvironments, 'includeRuns': includeRuns},
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> createImport({String? workspaceId, String format = 'json', required Map<String, dynamic> payload}) async {
    final wid = workspaceId ?? await _http.resolveWorkspaceId();
    final data = await _http.post('/api/workspaces/$wid/import-export/imports', data: {'format': format, 'payload': payload});
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
