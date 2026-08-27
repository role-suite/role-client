/// A row from `GET /workspaces/:id/members` (role-node/docs/modules/workspaces.md):
/// `{userId, name, email, role}`. Server-driven only — never persisted or
/// round-tripped locally, so there's no `toJson`.
class WorkspaceMember {
  const WorkspaceMember({required this.userId, required this.name, required this.email, required this.role});

  final int userId;
  final String name;
  final String email;

  /// `owner` | `admin` | `member`.
  final String role;

  factory WorkspaceMember.fromJson(Map<String, dynamic> json) {
    return WorkspaceMember(userId: json['userId'] as int, name: json['name'] as String, email: json['email'] as String, role: json['role'] as String);
  }
}
