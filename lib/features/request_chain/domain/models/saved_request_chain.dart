import 'package:relay/features/request_chain/domain/models/request_chain_item.dart';

/// Represents a saved request chain that can be reused later
class SavedRequestChain {
  final String id;
  final String name;
  final String? description;
  final List<RequestChainItem> chainItems;
  final DateTime createdAt;
  final DateTime updatedAt;

  SavedRequestChain({
    required this.id,
    required this.name,
    this.description,
    required this.chainItems,
    required this.createdAt,
    required this.updatedAt,
  });

  SavedRequestChain copyWith({
    String? id,
    String? name,
    String? description,
    List<RequestChainItem>? chainItems,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedRequestChain(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      chainItems: chainItems ?? this.chainItems,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'chainItems': chainItems.map((item) => item.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SavedRequestChain.fromJson(Map<String, dynamic> json) {
    return SavedRequestChain(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      chainItems: (json['chainItems'] as List)
          .map((item) => RequestChainItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
