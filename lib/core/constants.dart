abstract class AppConstants {
  static const appName = 'Röle';
  static const maxHistoryEntriesPerRequest = 20;
  static const maxHistoryEntriesGlobal = 300;
  static const historyPageSize = 30;
  static const maxRunHistoryEntries = 200;
  static const runHistoryPageSize = 20;
  static const defaultConnectTimeout = Duration(seconds: 15);
  static const defaultReceiveTimeout = Duration(seconds: 30);
  static const defaultCollectionId = 'default';

  /// role-node's fixed API prefix. Bump only for a documented `/api/v2`
  /// breaking change per role-node/docs/compatibility.md.
  static const apiPrefix = '/api/v1';
}
