/// One row from `GET /api/v1/auth/sessions` (role-node/docs/guides/client-integration.md):
/// `{ id, workspaceId, workspaceName, workspaceSlug, createdAt, expiresAt, current }`.
/// `current` marks the session backing the access token used for the request
/// — i.e. this device, right now.
class AuthSession {
  const AuthSession({
    required this.id,
    required this.workspaceId,
    required this.workspaceName,
    required this.workspaceSlug,
    required this.createdAt,
    required this.expiresAt,
    required this.current,
  });

  final int id;
  final int workspaceId;
  final String workspaceName;
  final String workspaceSlug;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool current;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      id: json['id'] as int,
      workspaceId: json['workspaceId'] as int,
      workspaceName: json['workspaceName'] as String,
      workspaceSlug: json['workspaceSlug'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      current: json['current'] as bool? ?? false,
    );
  }
}
