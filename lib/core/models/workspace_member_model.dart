class WorkspaceMemberModel {
  final String userId;
  final String name;
  final String email;
  final String role;
  final String status;

  WorkspaceMemberModel({required this.userId, required this.name, required this.email, required this.role, required this.status});

  factory WorkspaceMemberModel.fromJson(Map<String, dynamic> json) {
    final userId = (json['userId'] ?? json['memberUserId'] ?? json['id'] ?? '').toString();
    return WorkspaceMemberModel(
      userId: userId,
      name: (json['name'] ?? json['fullName'] ?? json['displayName'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
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
