import 'package:flutter/foundation.dart';

class Log {
  const Log._();

  static void d(String message, {String tag = 'role'}) {
    if (kDebugMode) debugPrint('[$tag] $message');
  }

  static void e(String message, {Object? error, StackTrace? stackTrace, String tag = 'role'}) {
    if (kDebugMode) {
      debugPrint('[$tag] ERROR: $message${error != null ? ' — $error' : ''}');
      if (stackTrace != null) debugPrint(stackTrace.toString());
    }
  }
}
