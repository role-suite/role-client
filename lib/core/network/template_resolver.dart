import '../models/key_value_entry.dart';

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

  /// Resolves a list of [KeyValueEntry] (headers, query params, form fields)
  /// into a plain map, skipping disabled and empty-key entries — the shape
  /// the wire request actually needs.
  Map<String, String> resolveEntries(List<KeyValueEntry> entries) {
    final map = <String, String>{};
    for (final entry in entries) {
      if (!entry.enabled) continue;
      final key = resolve(entry.key);
      if (key.isEmpty) continue;
      map[key] = resolve(entry.value);
    }
    return map;
  }

  /// Every `{{name}}` reference found in [input] that has no matching variable.
  static Set<String> unresolvedIn(String? input, Map<String, String> variables) {
    if (input == null) return const {};
    return _variablePattern.allMatches(input).map((m) => m.group(1)!).where((name) => !variables.containsKey(name)).toSet();
  }
}
