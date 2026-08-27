/// A single environment variable row: matches role-node's
/// `environment_variables` table — unlike a `Map<String, String>`, a list of
/// these can carry an enabled flag, a secret flag, and an explicit order.
class EnvironmentVariable {
  final String key;
  final String value;
  final bool enabled;
  final bool isSecret;
  final int position;

  /// role-node's row id for this variable, once synced — null for a
  /// local-only or not-yet-pushed row. Lets `WorkspacePushService.
  /// reconcileVariables` match a row across a key rename instead of only by
  /// `key` (which would otherwise look like a delete-then-create).
  final int? remoteId;

  const EnvironmentVariable({required this.key, this.value = '', this.enabled = true, this.isSecret = false, this.position = 0, this.remoteId});

  EnvironmentVariable copyWith({String? key, String? value, bool? enabled, bool? isSecret, int? position, int? remoteId}) {
    return EnvironmentVariable(
      key: key ?? this.key,
      value: value ?? this.value,
      enabled: enabled ?? this.enabled,
      isSecret: isSecret ?? this.isSecret,
      position: position ?? this.position,
      remoteId: remoteId ?? this.remoteId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EnvironmentVariable &&
      other.key == key &&
      other.value == value &&
      other.enabled == enabled &&
      other.isSecret == isSecret &&
      other.position == position &&
      other.remoteId == remoteId;

  @override
  int get hashCode => Object.hash(key, value, enabled, isSecret, position, remoteId);

  Map<String, dynamic> toJson() => {
    'key': key,
    'value': value,
    'enabled': enabled,
    'isSecret': isSecret,
    'position': position,
    if (remoteId != null) 'remoteId': remoteId,
  };

  factory EnvironmentVariable.fromJson(Map<String, dynamic> json) {
    return EnvironmentVariable(
      key: json['key'] as String? ?? '',
      value: json['value'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      isSecret: json['isSecret'] as bool? ?? false,
      position: json['position'] as int? ?? 0,
      remoteId: json['remoteId'] as int?,
    );
  }

  /// Parses either the current List shape or a pre-existing `Map<String,
  /// String>` (in Dart's map iteration order, all entries enabled, not secret).
  static List<EnvironmentVariable> listFrom(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map((e) => EnvironmentVariable.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    if (value is Map) {
      var position = 0;
      return value.entries.map((e) => EnvironmentVariable(key: e.key.toString(), value: e.value?.toString() ?? '', position: position++)).toList();
    }
    return const [];
  }

  /// The enabled, non-empty-key variables as a plain map — the shape
  /// [TemplateResolver] actually consumes.
  static Map<String, String> enabledMap(List<EnvironmentVariable> variables) {
    final map = <String, String>{};
    for (final variable in variables) {
      if (variable.enabled && variable.key.isNotEmpty) map[variable.key] = variable.value;
    }
    return map;
  }
}
