class WorkspaceSummaryModel {
  WorkspaceSummaryModel({required this.id, required this.name, required this.type});

  final String id;
  final String name;
  final String type;

  factory WorkspaceSummaryModel.fromJson(Map<String, dynamic> json) {
    return WorkspaceSummaryModel(
      id: (json['id'] ?? json['workspaceId'] ?? '').toString(),
      name: (json['name'] ?? json['workspaceName'] ?? 'Workspace').toString(),
      type: (json['type'] ?? json['workspaceType'] ?? '').toString(),
    );
  }
}
