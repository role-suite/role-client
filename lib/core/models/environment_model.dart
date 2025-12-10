class EnvironmentModel {
  final String name;
  final Map<String, String> variables;

  EnvironmentModel({required this.name, required this.variables});

  EnvironmentModel copyWith({String? name, Map<String, String>? variables}) {
    return EnvironmentModel(name: name ?? this.name, variables: variables ?? this.variables);
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'variables': variables};
  }

  factory EnvironmentModel.fromJson(Map<String, dynamic> json) {
    return EnvironmentModel(name: json['name'] as String, variables: Map<String, String>.from(json['variables'] ?? const {}));
  }
}
