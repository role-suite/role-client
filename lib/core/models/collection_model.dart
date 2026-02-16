class CollectionModel {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  CollectionModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
  });

  CollectionModel copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CollectionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CollectionModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    // Force to find name - require it to be present and non-empty
    final nameValue = json['name'];
    if (nameValue == null) {
      throw FormatException('Collection name is missing for collection with id: $id');
    }
    final name = nameValue as String;
    if (name.isEmpty) {
      throw FormatException('Collection name is empty for collection with id: $id');
    }
    return CollectionModel(
      id: id,
      name: name,
      description: json['description'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

