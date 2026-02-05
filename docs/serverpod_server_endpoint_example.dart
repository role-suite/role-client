// Copy this file into your Serverpod project, e.g. lib/src/endpoints/workspace_endpoint.dart
// Then run: serverpod generate

import 'package:serverpod/serverpod.dart';

/// Workspace endpoint for Röle. getWorkspace returns JSON string (WorkspaceBundle);
/// saveWorkspace accepts JSON string. Implement DB persistence as needed.
class WorkspaceEndpoint extends Endpoint {
  Future<String> getWorkspace(Session session) async {
    // TODO: load from DB (e.g. by session.auth?.userId or team id)
    return _emptyWorkspaceJson();
  }

  Future<void> saveWorkspace(Session session, String workspaceJson) async {
    // TODO: validate and persist to DB
  }

  String _emptyWorkspaceJson() {
    final now = DateTime.now().toUtc().toIso8601String();
    return '''
{
  "version": 1,
  "exportedAt": "$now",
  "source": "serverpod",
  "collections": [
    {
      "collection": {
        "id": "default",
        "name": "Default",
        "description": "",
        "createdAt": "$now",
        "updatedAt": "$now"
      },
      "requests": []
    }
  ],
  "environments": []
}
''';
  }
}
