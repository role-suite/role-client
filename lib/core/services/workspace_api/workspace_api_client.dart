import 'package:relay/core/models/workspace_bundle.dart';

/// Abstract client for loading/saving workspace (REST or Serverpod RPC).
abstract class WorkspaceApiClient {
  Future<WorkspaceBundle> getWorkspace();
  Future<void> putWorkspace(WorkspaceBundle bundle);
}
