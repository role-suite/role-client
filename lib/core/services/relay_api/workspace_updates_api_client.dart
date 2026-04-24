import 'package:role_sdk/role_sdk_endpoints.dart';
import 'package:relay/core/services/relay_api/relay_api_http.dart';

abstract class WorkspaceUpdatesApi {
  Future<String> resolveWorkspaceId();
  Future<Map<String, dynamic>> getUpdates({required String workspaceId, required int since, required int limit});
}

class WorkspaceUpdatesApiClient implements WorkspaceUpdatesApi {
  WorkspaceUpdatesApiClient({required String baseUrl, required String accessToken, String? workspaceId})
    : _http = RelayApiHttp(baseUrl: baseUrl, accessToken: accessToken, workspaceId: workspaceId);

  final RelayApiHttp _http;

  @override
  Future<String> resolveWorkspaceId() => _http.resolveWorkspaceId();

  @override
  Future<Map<String, dynamic>> getUpdates({required String workspaceId, required int since, required int limit}) async {
    final data = await _http.get(RoleSdkEndpoints.workspaceUpdates(workspaceId), queryParameters: {'since': since, 'limit': limit});
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }
}
