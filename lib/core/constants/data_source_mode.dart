/// Whether workspace data is loaded from local files or from a remote API.
enum DataSourceMode {
  /// Use local file storage (default, offline).
  local,

  /// Use remote API to fetch and optionally sync workspace.
  api,
}

extension DataSourceModeX on DataSourceMode {
  String get displayName => switch (this) {
        DataSourceMode.local => 'Local',
        DataSourceMode.api => 'API',
      };
}
