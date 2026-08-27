/// role-node's `AuthResponse.user` shape (role-node/docs/modules/auth.md): `{ id, name, email }`.
class AuthUser {
  const AuthUser({required this.id, required this.name, required this.email});

  final int id;
  final String name;
  final String email;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(id: json['id'] as int, name: json['name'] as String, email: json['email'] as String);
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};
}
