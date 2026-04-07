class UserProfileModel {
  final String id;
  final String name;
  final String email;
  final String accountType;
  final String teamName;
  final DateTime? createdAt;

  UserProfileModel({
    required this.id,
    required this.name,
    required this.email,
    required this.accountType,
    required this.teamName,
    required this.createdAt,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'] ?? json['created_at'] ?? json['joinedAt'] ?? json['joined_at'];
    DateTime? createdAt;
    if (createdAtRaw != null) {
      try {
        createdAt = DateTime.parse(createdAtRaw.toString());
      } catch (_) {
        createdAt = null;
      }
    }
    return UserProfileModel(
      id: (json['id'] ?? json['userId'] ?? json['uid'] ?? '').toString(),
      name: (json['name'] ?? json['fullName'] ?? json['displayName'] ?? json['username'] ?? '').toString(),
      email: (json['email'] ?? json['emailAddress'] ?? '').toString(),
      accountType: (json['accountType'] ?? json['account_type'] ?? json['type'] ?? '').toString(),
      teamName: (json['teamName'] ?? json['team'] ?? json['team_name'] ?? '').toString(),
      createdAt: createdAt,
    );
  }

  String get displayName {
    if (name.trim().isNotEmpty) return name;
    if (email.trim().isNotEmpty) return email;
    return id;
  }
}
