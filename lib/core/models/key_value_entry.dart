/// A single header/query-param/form-field row: matches role-node's
/// `keyValueSchema` — unlike a `Map<String, String>`, a list of these can
/// hold a duplicate key, a guaranteed order, and a disabled-without-deleted
/// entry.
class KeyValueEntry {
  final String key;
  final String value;
  final bool enabled;

  const KeyValueEntry({required this.key, this.value = '', this.enabled = true});

  KeyValueEntry copyWith({String? key, String? value, bool? enabled}) {
    return KeyValueEntry(key: key ?? this.key, value: value ?? this.value, enabled: enabled ?? this.enabled);
  }

  @override
  bool operator ==(Object other) => other is KeyValueEntry && other.key == key && other.value == value && other.enabled == enabled;

  @override
  int get hashCode => Object.hash(key, value, enabled);

  Map<String, dynamic> toJson() => {'key': key, 'value': value, 'enabled': enabled};

  factory KeyValueEntry.fromJson(Map<String, dynamic> json) {
    return KeyValueEntry(key: json['key'] as String? ?? '', value: json['value'] as String? ?? '', enabled: json['enabled'] as bool? ?? true);
  }

  /// Parses either the current List shape or a pre-existing `Map<String,
  /// String>` (in Dart's map iteration order, all entries enabled).
  static List<KeyValueEntry> listFrom(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((e) => KeyValueEntry.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    if (value is Map) {
      return value.entries.map((e) => KeyValueEntry(key: e.key.toString(), value: e.value?.toString() ?? '')).toList();
    }
    return const [];
  }

  /// The enabled, non-empty-key entries as a plain map — the shape the wire
  /// request/template resolver actually consumes.
  static Map<String, String> enabledMap(List<KeyValueEntry> entries) {
    final map = <String, String>{};
    for (final entry in entries) {
      if (entry.enabled && entry.key.isNotEmpty) map[entry.key] = entry.value;
    }
    return map;
  }
}
