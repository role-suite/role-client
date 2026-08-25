import '../utils/json_utils.dart';

/// A `role-node` import/export job (§8 of docs/08-ONLINE-MODE-INTEGRATION.md,
/// role-node/docs/modules/import-export.md): `{id, workspaceId, type, status,
/// format, summary, artifact, createdAt, completedAt}`. Jobs complete
/// synchronously today (`status` is always `"completed"`), so the `POST`
/// response already carries everything — `artifact` is the full exported
/// tree for an export job, or an echo of the sent payload for an import job.
/// Server-driven only, no `toJson`/local persistence.
class ImportExportJob {
  const ImportExportJob({
    required this.id,
    required this.workspaceId,
    required this.type,
    required this.status,
    required this.format,
    required this.summary,
    required this.artifact,
    required this.createdAt,
    required this.completedAt,
  });

  final int id;
  final int workspaceId;

  /// `export` | `import`.
  final String type;

  /// Always `completed` today — role-node's own docs note the create routes
  /// complete synchronously.
  final String status;

  /// Always `json`.
  final String format;
  final Map<String, dynamic> summary;
  final Map<String, dynamic> artifact;
  final DateTime createdAt;
  final DateTime completedAt;

  factory ImportExportJob.fromJson(Map<String, dynamic> json) {
    return ImportExportJob(
      id: json['id'] as int,
      workspaceId: json['workspaceId'] as int,
      type: json['type'] as String,
      status: json['status'] as String,
      format: json['format'] as String,
      summary: Map<String, dynamic>.from(json['summary'] as Map? ?? const {}),
      artifact: Map<String, dynamic>.from(json['artifact'] as Map? ?? const {}),
      createdAt: dateTimeFrom(json['createdAt']),
      completedAt: dateTimeFrom(json['completedAt']),
    );
  }
}
