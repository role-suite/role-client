class RoleSdkEndpoints {
  RoleSdkEndpoints._();

  static const String _api = '/api';

  static const String authMe = '$_api/auth/me';
  static const String authLogin = '$_api/auth/login';
  static const String authLogout = '$_api/auth/logout';
  static const String authRefresh = '$_api/auth/refresh';
  static const String authRegister = '$_api/auth/register';

  static const String workspaces = '$_api/workspaces';
  static const String workspaceJoin = '$_api/workspaces/join';

  static String workspace(String workspaceId) => _workspaceBase(workspaceId);
  static String workspaceMembers(String workspaceId) => '${_workspaceBase(workspaceId)}/members';
  static String workspaceMember(String workspaceId, String memberUserId) =>
      '${workspaceMembers(workspaceId)}/${_encode(memberUserId)}';
  static String workspaceInvitations(String workspaceId) => '${_workspaceBase(workspaceId)}/invitations';
  static String workspaceLeave(String workspaceId) => '${_workspaceBase(workspaceId)}/leave';
  static String workspaceConvertToTeam(String workspaceId) => '${_workspaceBase(workspaceId)}/convert-to-team';
  static String workspaceUpdates(String workspaceId) => '${_workspaceBase(workspaceId)}/updates';

  static String workspaceCollections(String workspaceId) => '${_workspaceBase(workspaceId)}/collections';
  static String workspaceCollection(String workspaceId, String collectionId) =>
      '${workspaceCollections(workspaceId)}/${_encode(collectionId)}';
  static String workspaceCollectionEndpoints(String workspaceId, String collectionId) =>
      '${workspaceCollection(workspaceId, collectionId)}/endpoints';
  static String workspaceCollectionEndpoint(String workspaceId, String collectionId, String endpointId) =>
      '${workspaceCollectionEndpoints(workspaceId, collectionId)}/${_encode(endpointId)}';
  static String workspaceEndpointExamples(String workspaceId, String collectionId, String endpointId) =>
      '${workspaceCollectionEndpoint(workspaceId, collectionId, endpointId)}/examples';
  static String workspaceEndpointExample(String workspaceId, String collectionId, String endpointId, String exampleId) =>
      '${workspaceEndpointExamples(workspaceId, collectionId, endpointId)}/${_encode(exampleId)}';
  static String workspaceCollectionFolders(String workspaceId, String collectionId) =>
      '${workspaceCollection(workspaceId, collectionId)}/folders';
  static String workspaceCollectionFolder(String workspaceId, String collectionId, String folderId) =>
      '${workspaceCollectionFolders(workspaceId, collectionId)}/${_encode(folderId)}';

  static String workspaceEnvironments(String workspaceId) => '${_workspaceBase(workspaceId)}/environments';
  static String workspaceEnvironment(String workspaceId, String environmentId) =>
      '${workspaceEnvironments(workspaceId)}/${_encode(environmentId)}';
  static String workspaceEnvironmentVariables(String workspaceId, String environmentId) =>
      '${workspaceEnvironment(workspaceId, environmentId)}/variables';
  static String workspaceEnvironmentVariable(String workspaceId, String environmentId, String variableId) =>
      '${workspaceEnvironmentVariables(workspaceId, environmentId)}/${_encode(variableId)}';

  static String workspaceImportExportJobs(String workspaceId) => '${_workspaceBase(workspaceId)}/import-export/jobs';
  static String workspaceImportExportJob(String workspaceId, String jobId) =>
      '${workspaceImportExportJobs(workspaceId)}/${_encode(jobId)}';
  static String workspaceImportExportExports(String workspaceId) => '${_workspaceBase(workspaceId)}/import-export/exports';
  static String workspaceImportExportImports(String workspaceId) => '${_workspaceBase(workspaceId)}/import-export/imports';

  static String workspaceRuns(String workspaceId) => '${_workspaceBase(workspaceId)}/runs';
  static String workspaceRun(String workspaceId, String runId) => '${workspaceRuns(workspaceId)}/${_encode(runId)}';
  static String workspaceRunCancel(String workspaceId, String runId) => '${workspaceRun(workspaceId, runId)}/cancel';

  static String workspaceSharedRequests(String workspaceId) => '${_workspaceBase(workspaceId)}/shared-requests';
  static String workspaceShareRequest(String workspaceId) => '${_workspaceBase(workspaceId)}/share-request';
  static String workspaceImportSharedRequest(String workspaceId, String sharedRequestId) =>
      '${workspaceSharedRequests(workspaceId)}/${_encode(sharedRequestId)}/import';

  static String _workspaceBase(String workspaceId) => '$_api/workspaces/${_encode(workspaceId)}';

  static String _encode(String value) => Uri.encodeComponent(value.trim());
}
