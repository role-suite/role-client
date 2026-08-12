import '../utils/json_utils.dart';

class Environment {
  final String id;
  final String name;
  final Map<String, String> variables;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Environment({
    required this.id,
    required this.name,
    this.variables = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  Environment copyWith({String? name, Map<String, String>? variables, DateTime? updatedAt}) {
    return Environment(
      id: id,
      name: name ?? this.name,
      variables: variables ?? this.variables,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'variables': variables,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Environment.fromJson(Map<String, dynamic> json) {
    return Environment(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Untitled Environment',
      variables: stringMapFrom(json['variables']),
      createdAt: dateTimeFrom(json['createdAt']),
      updatedAt: dateTimeFrom(json['updatedAt']),
    );
  }
}
