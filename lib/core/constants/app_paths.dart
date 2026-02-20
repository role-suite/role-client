class AppPaths {
  static const String workspaceRoot = 'workspace';

  static const String environments = 'environments';
  static const String collections = 'collections';
  static const String history = 'history';
  static const String settings = 'settings';
  static const String savedChains = 'saved_chains';

  static const String appSettingsFile = 'app_settings.json';

  static String environmentFile(String name) {
    return '$environments/$name.json';
  }

  static String collectionFile(String folder, String fileName) {
    return '$collections/$folder/$fileName.json';
  }

  static String historyFolder(String requestId) {
    return '$history/$requestId';
  }

  static String savedChainFile(String chainId) {
    return '$savedChains/$chainId.json';
  }
}
