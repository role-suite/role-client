class RoleNodeEndpoints {
  const RoleNodeEndpoints._();

  static const String health = '/health';

  static const String authRegister = '/api/auth/register';
  static const String authLogin = '/api/auth/login';
  static const String authRefresh = '/api/auth/refresh';
  static const String authLogout = '/api/auth/logout';
  static const String authMe = '/api/auth/me';

  static const String workspaces = '/api/workspaces';
  static String workspace(String workspaceId) => '/api/workspaces/$workspaceId';
  static String workspaceMembers(String workspaceId) => '/api/workspaces/$workspaceId/members';
  static String workspaceMember(String workspaceId, String memberUserId) => '/api/workspaces/$workspaceId/members/$memberUserId';
  static String workspaceInvitations(String workspaceId) => '/api/workspaces/$workspaceId/invitations';
  static const String workspaceJoin = '/api/workspaces/join';
  static String workspaceLeave(String workspaceId) => '/api/workspaces/$workspaceId/leave';
  static String workspaceConvertToTeam(String workspaceId) => '/api/workspaces/$workspaceId/convert-to-team';
  static String workspaceUpdates(String workspaceId) => '/api/workspaces/$workspaceId/updates';

  static String workspaceCollections(String workspaceId) => '/api/workspaces/$workspaceId/collections';
  static String workspaceCollection(String workspaceId, String collectionId) => '/api/workspaces/$workspaceId/collections/$collectionId';
  static String workspaceCollectionEndpoints(String workspaceId, String collectionId) =>
      '/api/workspaces/$workspaceId/collections/$collectionId/endpoints';
  static String workspaceCollectionEndpoint(String workspaceId, String collectionId, String endpointId) =>
      '/api/workspaces/$workspaceId/collections/$collectionId/endpoints/$endpointId';
  static String workspaceEndpointExamples(String workspaceId, String collectionId, String endpointId) =>
      '/api/workspaces/$workspaceId/collections/$collectionId/endpoints/$endpointId/examples';
  static String workspaceEndpointExample(String workspaceId, String collectionId, String endpointId, String exampleId) =>
      '/api/workspaces/$workspaceId/collections/$collectionId/endpoints/$endpointId/examples/$exampleId';
  static String workspaceCollectionFolders(String workspaceId, String collectionId) =>
      '/api/workspaces/$workspaceId/collections/$collectionId/folders';
  static String workspaceCollectionFolder(String workspaceId, String collectionId, String folderId) =>
      '/api/workspaces/$workspaceId/collections/$collectionId/folders/$folderId';

  static String workspaceEnvironments(String workspaceId) => '/api/workspaces/$workspaceId/environments';
  static String workspaceEnvironment(String workspaceId, String environmentId) => '/api/workspaces/$workspaceId/environments/$environmentId';
  static String workspaceEnvironmentVariables(String workspaceId, String environmentId) =>
      '/api/workspaces/$workspaceId/environments/$environmentId/variables';
  static String workspaceEnvironmentVariable(String workspaceId, String environmentId, String variableId) =>
      '/api/workspaces/$workspaceId/environments/$environmentId/variables/$variableId';

  static String workspaceRuns(String workspaceId) => '/api/workspaces/$workspaceId/runs';
  static String workspaceRun(String workspaceId, String runId) => '/api/workspaces/$workspaceId/runs/$runId';
  static String workspaceRunCancel(String workspaceId, String runId) => '/api/workspaces/$workspaceId/runs/$runId/cancel';

  static String workspaceImportExportJobs(String workspaceId) => '/api/workspaces/$workspaceId/import-export/jobs';
  static String workspaceImportExportJob(String workspaceId, String jobId) => '/api/workspaces/$workspaceId/import-export/jobs/$jobId';
  static String workspaceImportExportExports(String workspaceId) => '/api/workspaces/$workspaceId/import-export/exports';
  static String workspaceImportExportImports(String workspaceId) => '/api/workspaces/$workspaceId/import-export/imports';
}
