import '../utils/json_utils.dart';
import 'environment_variable.dart';
import 'workspace_origin.dart';

class Environment {
  final String id;
  final String name;
  final List<EnvironmentVariable> variables;
  final DateTime createdAt;
  final DateTime updatedAt;
  final WorkspaceOrigin origin;
  final int? remoteWorkspaceId;
  final int? remoteId;
  final DateTime? syncedAt;

  const Environment({
    required this.id,
    required this.name,
    this.variables = const [],
    required this.createdAt,
    required this.updatedAt,
    this.origin = WorkspaceOrigin.local,
    this.remoteWorkspaceId,
    this.remoteId,
    this.syncedAt,
  });

  Environment copyWith({
    String? name,
    List<EnvironmentVariable>? variables,
    DateTime? updatedAt,
    WorkspaceOrigin? origin,
    int? remoteWorkspaceId,
    int? remoteId,
    DateTime? syncedAt,
  }) {
    return Environment(
      id: id,
      name: name ?? this.name,
      variables: variables ?? this.variables,
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
    'variables': variables.map((v) => v.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'origin': origin.toJson(),
    if (remoteWorkspaceId != null) 'remoteWorkspaceId': remoteWorkspaceId,
    if (remoteId != null) 'remoteId': remoteId,
    if (syncedAt != null) 'syncedAt': syncedAt!.toIso8601String(),
  };

  factory Environment.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    if (rawId is! String || rawId.isEmpty) {
      throw FormatException('Environment is missing a valid id');
    }
    return Environment(
      id: rawId,
      name: json['name'] as String? ?? 'Untitled Environment',
      variables: EnvironmentVariable.listFrom(json['variables']),
      createdAt: dateTimeFrom(json['createdAt']),
      updatedAt: dateTimeFrom(json['updatedAt']),
      origin: WorkspaceOrigin.fromJson(json['origin']),
      remoteWorkspaceId: json['remoteWorkspaceId'] as int?,
      remoteId: json['remoteId'] as int?,
      syncedAt: json['syncedAt'] != null ? DateTime.tryParse(json['syncedAt'] as String) : null,
    );
  }
}
