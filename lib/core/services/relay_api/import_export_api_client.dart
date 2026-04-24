import 'package:relay/core/services/relay_api/role_sdk_endpoints.dart';
import 'package:relay/core/services/relay_api/relay_api_http.dart';

class ImportExportApiClient {
  ImportExportApiClient({required String baseUrl, required String accessToken}) : _http = RelayApiHttp(baseUrl: baseUrl, accessToken: accessToken);

  final RelayApiHttp _http;

  Future<List<Map<String, dynamic>>> listJobs({String? workspaceId}) async {
    final wid = workspaceId ?? await _http.resolveWorkspaceId();
    final data = await _http.get(RoleSdkEndpoints.workspaceImportExportJobs(wid));
    return _asList(data);
  }

  Future<Map<String, dynamic>> getJob(String jobId, {String? workspaceId}) async {
    final wid = workspaceId ?? await _http.resolveWorkspaceId();
    final data = await _http.get(RoleSdkEndpoints.workspaceImportExportJob(wid, jobId));
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
      RoleSdkEndpoints.workspaceImportExportExports(wid),
      data: {'format': format, 'includeCollections': includeCollections, 'includeEnvironments': includeEnvironments, 'includeRuns': includeRuns},
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> createImport({String? workspaceId, String format = 'json', required Map<String, dynamic> payload}) async {
    final wid = workspaceId ?? await _http.resolveWorkspaceId();
    final data = await _http.post(RoleSdkEndpoints.workspaceImportExportImports(wid), data: {'format': format, 'payload': payload});
    return _asMap(data);
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
