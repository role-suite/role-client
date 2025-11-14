class AppConstants {
  static const String appName = 'Relay App';
  static const String defaultRequestName = 'Untitled Request';
  static const String defaultEnvironment = 'local';

  static const String variableStart = '{{';
  static const String variableEnd = '}}';

  static const Duration defaultConnectTimeout = Duration(seconds: 15);
  static const Duration defaultReceiveTimeout = Duration(seconds: 30);

  static const int maxHistoryEntriesPerRequest = 20;

  static const List<String> httpMethods = [
    'GET',
    'POST',
    'PUT',
    'DELETE',
    'PATCH',
    'HEAD',
    'OPTIONS',
  ];
}
