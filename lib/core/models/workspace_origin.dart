enum WorkspaceOrigin {
  local,
  remote;

  String toJson() => name;

  static WorkspaceOrigin fromJson(dynamic value) {
    return WorkspaceOrigin.values.firstWhere((o) => o.name == value, orElse: () => WorkspaceOrigin.local);
  }
}
