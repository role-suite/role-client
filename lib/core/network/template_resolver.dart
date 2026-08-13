final _variablePattern = RegExp(r'\{\{\s*([a-zA-Z0-9_.-]+)\s*\}\}');

/// Resolves `{{variableName}}` placeholders against an environment's
/// variable map. Unresolved variables are left untouched so the caller can
/// still see what's missing.
class TemplateResolver {
  const TemplateResolver(this.variables);

  final Map<String, String> variables;

  String resolve(String? input) {
    if (input == null || input.isEmpty) return input ?? '';
    return input.replaceAllMapped(_variablePattern, (match) {
      final name = match.group(1)!;
      return variables[name] ?? match.group(0)!;
    });
  }

  Map<String, String> resolveMap(Map<String, String> input) {
    return input.map((key, value) => MapEntry(resolve(key), resolve(value)));
  }

  /// Every `{{name}}` reference found in [input] that has no matching variable.
  static Set<String> unresolvedIn(String? input, Map<String, String> variables) {
    if (input == null) return const {};
    return _variablePattern.allMatches(input).map((m) => m.group(1)!).where((name) => !variables.containsKey(name)).toSet();
  }
}
