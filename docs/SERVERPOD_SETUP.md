# Serverpod RPC setup for Röle

To use **Serverpod RPC** instead of REST for the workspace API:

1. Add the workspace endpoint to your Serverpod server.
2. Generate the client and point the app to it (or use the stub until you do).

---

## 1. Add the endpoint to your Serverpod server

In your Serverpod project, create an endpoint that returns and accepts the workspace as JSON strings.

Create a file under your server's `lib/src/endpoints/` (or wherever your endpoints live), e.g. `workspace_endpoint.dart`:

```dart
import 'package:serverpod/serverpod.dart';

/// Workspace endpoint for Röle app. getWorkspace returns JSON string;
/// saveWorkspace accepts JSON string (same format as Röle's Export Workspace).
class WorkspaceEndpoint extends Endpoint {
  /// Returns the full workspace as a JSON string (Relay WorkspaceBundle format).
  Future<String> getWorkspace(Session session) async {
    // TODO: Load from your database (e.g. per-user or per-team).
    // For now return minimal valid bundle:
    return '''
    {
      "version": 1,
      "exportedAt": "${DateTime.now().toUtc().toIso8601String()}",
      "source": "serverpod",
      "collections": [
        {
          "collection": {
            "id": "default",
            "name": "Default",
            "description": "",
            "createdAt": "${DateTime.now().toIso8601String()}",
            "updatedAt": "${DateTime.now().toIso8601String()}"
          },
          "requests": []
        }
      ],
      "environments": []
    }
    ''';
  }

  /// Saves the full workspace (JSON string in WorkspaceBundle format).
  Future<void> saveWorkspace(Session session, String workspaceJson) async {
    // TODO: Validate, persist to DB (e.g. per user/team).
    // For now no-op.
  }
}
```

Implement `getWorkspace` and `saveWorkspace` to read/write from your database (e.g. keyed by `session.auth?.userId` or a team id).

Then run in your Serverpod project root:

```bash
serverpod generate
```

This generates the client package (e.g. `packages/your_project_client`) with `client.workspace.getWorkspace()` and `client.workspace.saveWorkspace(String)`.

---

## 2. Use the generated client in Röle

- In `role-client/pubspec.yaml`, point `relay_server_client` to your generated client:

```yaml
dependencies:
  relay_server_client:
    path: ../your_serverpod_project/packages/your_project_client
```

- If your client package has a **different name** (e.g. `myapp_client`), either:
  - Rename it to `relay_server_client`, or
  - Change the dependency name in `pubspec.yaml` to match (e.g. `myapp_client`) and update the import in `lib/core/services/workspace_api/serverpod_workspace_client.dart` from `package:relay_server_client/relay_server_client.dart` to `package:myapp_client/myapp_client.dart`.

- In the Röle app: choose **Data source → API**, open **Configure API**, select **Serverpod RPC**, set **Server URL** (e.g. `http://localhost:8080`), and save.

---

## 3. Stub package (default)

The repo includes a **stub** package at `packages/relay_server_client` so the app compiles without a Serverpod project. It throws when you call the workspace methods. Replace it with your generated client (step 2) when you have a Serverpod backend.

---

## Teams / multi-user

You can implement per-user or per-team workspaces in `getWorkspace` and `saveWorkspace` using `session.auth?.userId` (or a custom claim) and your own DB schema. The client does not send auth by default; use Serverpod authentication (e.g. email sign-in) and the session will carry the user id for the endpoint.
