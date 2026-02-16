class TemplateResolver {
  static final RegExp _placeholderRegex =
  RegExp(r'{{\s*([a-zA-Z0-9_]+)\s*}}');
  
  /// Public access to the placeholder regex for text highlighting
  static RegExp get placeholderRegex => _placeholderRegex;

  static String resolve(String input, Map<String, String> variables) {
    if (variables.isEmpty) return input;

    return input.replaceAllMapped(_placeholderRegex, (match) {
      final key = match.group(1);
      if (key == null) return match.group(0) ?? '';
      return variables[key] ?? match.group(0) ?? '';
    });
  }

  static String resolveAll(String input, List<Map<String, String>> maps) {
    var result = input;
    for (final map in maps) {
      result = resolve(result, map);
    }
    return result;
  }

  static List<String> extractVariables(String input) {
    final matches = _placeholderRegex.allMatches(input);
    final result = <String>{};
    for (final m in matches) {
      final key = m.group(1);
      if (key != null && key.isNotEmpty) {
        result.add(key);
      }
    }
    return result.toList();
  }
}
