import '../utils/json_utils.dart';
import 'workspace_origin.dart';

class Collection {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final WorkspaceOrigin origin;
  final int? remoteWorkspaceId;
  final int? remoteId;
  final DateTime? syncedAt;

  const Collection({
    required this.id,
    required this.name,
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
    this.origin = WorkspaceOrigin.local,
    this.remoteWorkspaceId,
    this.remoteId,
    this.syncedAt,
  });

  Collection copyWith({
    String? name,
    String? description,
    DateTime? updatedAt,
    WorkspaceOrigin? origin,
    int? remoteWorkspaceId,
    int? remoteId,
    DateTime? syncedAt,
  }) {
    return Collection(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      origin: origin ?? this.origin,
      remoteWorkspaceId: remoteWorkspaceId ?? this.remoteWorkspaceId,
      remoteId: remoteId ?? this.remoteId,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'origin': origin.toJson(),
    if (remoteWorkspaceId != null) 'remoteWorkspaceId': remoteWorkspaceId,
    if (remoteId != null) 'remoteId': remoteId,
    if (syncedAt != null) 'syncedAt': syncedAt!.toIso8601String(),
  };

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Untitled Collection',
      description: json['description'] as String? ?? '',
      createdAt: dateTimeFrom(json['createdAt']),
      updatedAt: dateTimeFrom(json['updatedAt']),
      origin: WorkspaceOrigin.fromJson(json['origin']),
      remoteWorkspaceId: json['remoteWorkspaceId'] as int?,
      remoteId: json['remoteId'] as int?,
      syncedAt: json['syncedAt'] != null ? DateTime.tryParse(json['syncedAt'] as String) : null,
    );
  }
}
