import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'workspace_service.dart';

class FileStorageService {
  FileStorageService._internal(this._workspaceService);

  static final FileStorageService _instance = FileStorageService._internal(WorkspaceService.instance);
  factory FileStorageService() => _instance;
  static FileStorageService get instance => _instance;
  final WorkspaceService _workspaceService;

  Future<Map<String, dynamic>> readJson(String relativePath) async {
    final fullPath = await _workspaceService.resolvePath(p.split(relativePath));
    final file = File(fullPath);

    if (!await file.exists()) {
      throw FileSystemException('File not found', fullPath);
    }

    final content = await file.readAsString();
    final data = jsonDecode(content);

    if (data is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object at root');
    }

    return data;
  }

  Future<void> writeJson(String relativePath, Map<String, dynamic> data) async {
    final fullPath = await _workspaceService.resolvePath(p.split(relativePath));
    final file = File(fullPath);
    await file.parent.create(recursive: true);
    final content = const JsonEncoder.withIndent('  ').convert(data);
    await file.writeAsString(content);
  }

  Future<List<FileSystemEntity>> listDir(String relativeDir) async {
    final fullPath = await _workspaceService.resolvePath(p.split(relativeDir));
    final dir = Directory(fullPath);

    if (!await dir.exists()) {
      return [];
    }

    return dir.list(recursive: false, followLinks: false).toList();
  }
}
