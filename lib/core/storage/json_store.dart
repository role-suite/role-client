import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/logger.dart';
import 'workspace_paths.dart';

/// Local JSON-file persistence for the workspace. Everything lives under the
/// app's support directory — no database, no network, no accounts.
class JsonStore {
  JsonStore._();
  static final JsonStore instance = JsonStore._();

  Directory? _workspaceDir;

  Future<Directory> _workspaceDirectory() async {
    if (_workspaceDir != null) return _workspaceDir!;
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, WorkspacePaths.root));
    if (!await dir.exists()) await dir.create(recursive: true);
    _workspaceDir = dir;
    return dir;
  }

  Future<String> _resolve(String relativePath) async {
    final dir = await _workspaceDirectory();
    return p.join(dir.path, relativePath);
  }

  Future<Map<String, dynamic>?> read(String relativePath) async {
    final fullPath = await _resolve(relativePath);
    final file = File(fullPath);
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      final data = jsonDecode(content);
      return data is Map<String, dynamic> ? data : null;
    } catch (error, stackTrace) {
      Log.e('Failed to read $relativePath', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> write(String relativePath, Map<String, dynamic> data) async {
    final fullPath = await _resolve(relativePath);
    final file = File(fullPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  Future<void> delete(String relativePath) async {
    final fullPath = await _resolve(relativePath);
    final file = File(fullPath);
    if (await file.exists()) await file.delete();
  }

  /// Reads every `*.json` file directly inside [relativeDir].
  Future<List<Map<String, dynamic>>> readAll(String relativeDir) async {
    final fullPath = await _resolve(relativeDir);
    final dir = Directory(fullPath);
    if (!await dir.exists()) return [];

    final entries = await dir.list(followLinks: false).toList();
    final results = <Map<String, dynamic>>[];
    for (final entity in entries) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final data = jsonDecode(await entity.readAsString());
        if (data is Map<String, dynamic>) results.add(data);
      } catch (error, stackTrace) {
        Log.e('Failed to read ${entity.path}', error: error, stackTrace: stackTrace);
      }
    }
    return results;
  }
}
