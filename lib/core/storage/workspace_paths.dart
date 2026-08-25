abstract class WorkspacePaths {
  static const String root = 'workspace';
  static const String collections = 'collections';
  static const String environments = 'environments';
  static const String history = 'history';
  static const String historyBodies = 'history/bodies';
  static const String runs = 'runs';
  static const String flows = 'flows';
  static const String settingsFile = 'settings.json';
  static const String syncCursors = 'sync/cursors';
  static const String syncOutbox = 'sync/outbox';

  static String collectionFile(String id) => '$collections/$id.json';
  static String environmentFile(String id) => '$environments/$id.json';
  static String historyFile(String requestId) => '$history/$requestId.json';
  static String historyBodyFile(String snapshotId) => '$historyBodies/$snapshotId.json';
  static String runFile(String runId) => '$runs/$runId.json';
  static String flowFile(String id) => '$flows/$id.json';
  static String syncCursorFile(int workspaceId) => '$syncCursors/$workspaceId.json';
  static String outboxFile(int workspaceId) => '$syncOutbox/$workspaceId.json';

  /// The remote cache for one signed-in workspace lives under its own
  /// subtree, never mixed into `collections/`/`environments/` — see §7 of
  /// docs/08-ONLINE-MODE-INTEGRATION.md. Deleting `remote/<id>/` (sign-out,
  /// leaving a workspace) is a pure local operation with no risk to local data.
  static String remoteRoot(int workspaceId) => 'remote/$workspaceId';
  static String remoteCollections(int workspaceId) => '${remoteRoot(workspaceId)}/collections';
  static String remoteEnvironments(int workspaceId) => '${remoteRoot(workspaceId)}/environments';
  static String remoteCollectionFile(int workspaceId, String id) => '${remoteCollections(workspaceId)}/$id.json';
  static String remoteEnvironmentFile(int workspaceId, String id) => '${remoteEnvironments(workspaceId)}/$id.json';
}
