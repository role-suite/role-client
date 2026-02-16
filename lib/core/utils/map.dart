class MapUtils {
  static Map<String, String> filterEmpty(Map<String, String> map) {
    final result = <String, String>{};
    map.forEach((key, value) {
      if (value.trim().isNotEmpty) {
        result[key] = value;
      }
    });
    return result;
  }

  static Map<String, String> toStringMap(Map<String, dynamic>? map) {
    if (map == null) return {};
    final result = <String, String>{};
    map.forEach((key, value) {
      result[key] = value?.toString() ?? '';
    });
    return result;
  }

  static Map<String, String> mergeStringMaps(
      Map<String, String> base,
      Map<String, String> override,
      ) {
    final result = <String, String>{}..addAll(base)..addAll(override);
    return result;
  }

  static Map<String, dynamic> cloneDynamicMap(Map<String, dynamic> map) {
    return Map<String, dynamic>.from(map);
  }
}
