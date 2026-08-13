abstract class WorkspacePaths {
  static const String root = 'workspace';
  static const String collections = 'collections';
  static const String environments = 'environments';
  static const String history = 'history';
  static const String historyBodies = 'history/bodies';
  static const String runs = 'runs';
  static const String flows = 'flows';
  static const String settingsFile = 'settings.json';

  static String collectionFile(String id) => '$collections/$id.json';
  static String environmentFile(String id) => '$environments/$id.json';
  static String historyFile(String requestId) => '$history/$requestId.json';
  static String historyBodyFile(String snapshotId) => '$historyBodies/$snapshotId.json';
  static String runFile(String runId) => '$runs/$runId.json';
  static String flowFile(String id) => '$flows/$id.json';
}
