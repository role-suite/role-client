import 'package:flutter/foundation.dart';

class AppLogger {
  static bool enabled = true;

  static void _log(String level, String message, [Object? error, StackTrace? stackTrace]) {
    if (!enabled) return;

    final buffer = StringBuffer()
      ..write('[$level] ')
      ..write(message);

    if (error != null) {
      buffer.write(' | error: $error');
    }
    if (stackTrace != null && kDebugMode) {
      buffer.write('\n$stackTrace');
    }
    AppLogger.info(buffer.toString());
  }

  static void debug(String message) => _log('DEBUG', message);
  static void info(String message) => _log('INFO', message);
  static void warn(String message) => _log('WARN', message);
  static void error(String message, [Object? error, StackTrace? stackTrace]) => _log('ERROR', message, error, stackTrace);
}
