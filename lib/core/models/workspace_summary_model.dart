class WorkspaceSummaryModel {
  WorkspaceSummaryModel({required this.id, required this.name, required this.type});

  final String id;
  final String name;
  final String type;

  factory WorkspaceSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawName = (json['name'] ?? json['workspaceName'] ?? 'Workspace').toString();
    return WorkspaceSummaryModel(
      id: (json['id'] ?? json['workspaceId'] ?? '').toString(),
      name: _sanitizeWorkspaceName(rawName),
      type: (json['type'] ?? json['workspaceType'] ?? '').toString(),
    );
  }

  static String _sanitizeWorkspaceName(String value) {
    final withoutPortal = value.replaceAll(RegExp(r'\bportal\b', caseSensitive: false), ' ');
    final normalized = withoutPortal.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? 'Workspace' : normalized;
  }
}
