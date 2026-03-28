import 'package:relay/core/models/workspace_bundle.dart';

/// Abstract client for loading/saving workspace.
abstract class WorkspaceApiClient {
  Future<WorkspaceBundle> getWorkspace();
  Future<void> putWorkspace(WorkspaceBundle bundle);
}
