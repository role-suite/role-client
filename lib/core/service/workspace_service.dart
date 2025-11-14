import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:relay/core/constant/app_paths.dart';

class WorkspaceService {
  WorkspaceService._internal();
  static final WorkspaceService _instance = WorkspaceService._internal();
  factory WorkspaceService() => _instance;
  static WorkspaceService get instance => _instance;

  Future<Directory> getWorkspaceDirectory() async {
    final baseDir = await getApplicationSupportDirectory();
    final workspacePath = p.join(baseDir.path, AppPaths.workspaceRoot);

    final workspaceDir = Directory(workspacePath);
    if (!await workspaceDir.exists()) {
      await workspaceDir.create(recursive: true);
    }
    return workspaceDir;
  }

  Future<String> resolvePath(List<String> segments) async {
    final workspaceDir = await getWorkspaceDirectory();
    return p.joinAll([workspaceDir.path, ...segments]);
  }
}
