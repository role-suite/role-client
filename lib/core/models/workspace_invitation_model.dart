class WorkspaceInvitationModel {
  final String id;
  final String email;
  final String role;
  final String token;
  final DateTime? expiresAt;

  WorkspaceInvitationModel({required this.id, required this.email, required this.role, required this.token, this.expiresAt});

  factory WorkspaceInvitationModel.fromJson(Map<String, dynamic> json) {
    final token = (json['token'] ?? json['code'] ?? json['inviteToken'] ?? '').toString();
    final expiresAtRaw = json['expiresAt'] ?? json['expires_at'];
    DateTime? expiresAt;
    if (expiresAtRaw != null) {
      try {
        expiresAt = DateTime.parse(expiresAtRaw.toString());
      } catch (_) {
        expiresAt = null;
      }
    }
    return WorkspaceInvitationModel(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? 'member').toString(),
      token: token,
      expiresAt: expiresAt,
    );
  }
}
