class WorkspaceMemberModel {
  final String userId;
  final String name;
  final String email;
  final String role;
  final String status;

  WorkspaceMemberModel({required this.userId, required this.name, required this.email, required this.role, required this.status});

  factory WorkspaceMemberModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final userMap = user is Map<String, dynamic> ? user : null;
    final userId = (json['userId'] ?? json['memberUserId'] ?? userMap?['id'] ?? json['id'] ?? '').toString();
    return WorkspaceMemberModel(
      userId: userId,
      name: (json['name'] ?? json['fullName'] ?? json['displayName'] ?? userMap?['name'] ?? userMap?['displayName'] ?? '').toString(),
      email: (json['email'] ?? userMap?['email'] ?? '').toString(),
      role: (json['role'] ?? 'member').toString(),
      status: (json['status'] ?? json['state'] ?? 'active').toString(),
    );
  }

  String get displayName {
    if (name.trim().isNotEmpty) return name;
    if (email.trim().isNotEmpty) return email;
    return userId;
  }
}
