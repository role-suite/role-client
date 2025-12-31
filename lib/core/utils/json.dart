import 'dart:convert';

import 'package:relay/core/utils/logger.dart';

class JsonUtils {
  static String pretty(dynamic data) {
    try {
      if (data is String) {
        final decoded = jsonDecode(data);
        return const JsonEncoder.withIndent('  ').convert(decoded);
      } else if (data is Map || data is List) {
        return const JsonEncoder.withIndent('  ').convert(data);
      }
    } catch (e) {
      AppLogger.error(e.toString());
    }
    return data?.toString() ?? '';
  }

  static bool isValidJson(String input) {
    try {
      jsonDecode(input);
      return true;
    } catch (e) {
      AppLogger.error(e.toString());
      return false;
    }
  }

  static dynamic tryDecode(String input) {
    try {
      return jsonDecode(input);
    } catch (_) {
      return null;
    }
  }

  static bool isJsonObject(String input) {
    final decoded = tryDecode(input);
    return decoded is Map<String, dynamic>;
  }

  static bool isJsonArray(String input) {
    final decoded = tryDecode(input);
    return decoded is List;
  }
}
