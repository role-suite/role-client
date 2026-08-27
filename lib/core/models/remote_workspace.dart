/// Mirrors role-node's `workspace`/`memberships` shape from `AuthResponse`
/// (role-node/docs/modules/auth.md): `{ id, name, slug, type, role }` for the
/// active workspace, `{ workspaceId, name, slug, type, role }` per membership
/// row. Cached locally so the workspace switcher works offline.
class RemoteWorkspace {
  const RemoteWorkspace({required this.id, required this.name, required this.slug, required this.type, required this.role});

  final int id;
  final String name;
  final String slug;
  final String type;
  final String role;

  factory RemoteWorkspace.fromJson(Map<String, dynamic> json) {
    return RemoteWorkspace(
      id: (json['id'] ?? json['workspaceId']) as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      type: json['type'] as String,
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'slug': slug, 'type': type, 'role': role};
}
