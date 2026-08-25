import '../utils/json_utils.dart';

/// The response from `POST /workspaces/:id/invitations`
/// (role-node/docs/modules/workspaces.md): `{id, workspaceId, email, role,
/// token, expiresAt}`. `token` is the raw invitation secret — role-node only
/// ever stores its hash, so this is the client's one chance to see it and
/// hand it to the invitee out-of-band. Server-driven only, no `toJson`.
class WorkspaceInvitation {
  const WorkspaceInvitation({
    required this.id,
    required this.workspaceId,
    required this.email,
    required this.role,
    required this.token,
    required this.expiresAt,
  });

  final int id;
  final int workspaceId;
  final String email;

  /// `admin` | `member` (an invitation can never grant `owner`).
  final String role;
  final String token;
  final DateTime expiresAt;

  factory WorkspaceInvitation.fromJson(Map<String, dynamic> json) {
    return WorkspaceInvitation(
      id: json['id'] as int,
      workspaceId: json['workspaceId'] as int,
      email: json['email'] as String,
      role: json['role'] as String,
      token: json['token'] as String,
      expiresAt: dateTimeFrom(json['expiresAt']),
    );
  }
}
