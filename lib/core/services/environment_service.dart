import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:relay/core/constants/app_constants.dart';
import 'package:relay/core/constants/app_paths.dart';
import 'package:relay/core/utils/logger.dart';

import '../models/environment_model.dart';
import 'file_storage_service.dart';
import 'workspace_service.dart';

class EnvironmentService {
  EnvironmentService._internal(this._fileStorageService, this._workspaceService);

  static final EnvironmentService _instance = EnvironmentService._internal(FileStorageService.instance, WorkspaceService.instance);

  factory EnvironmentService() => _instance;

  static EnvironmentService get instance => _instance;

  final FileStorageService _fileStorageService;
  final WorkspaceService _workspaceService;

  String? _activeEnvironmentName = AppConstants.defaultEnvironment;

  Future<List<EnvironmentModel>> loadAllEnvironments() async {
    final dirPath = await _workspaceService.resolvePath([AppPaths.environments]);
    final dir = Directory(dirPath);

    if (!await dir.exists()) {
      await dir.create(recursive: true);
      return [];
    }

    final entities = await dir.list(recursive: false, followLinks: false).toList();

    final envs = <EnvironmentModel>[];

    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        // Use path package to reliably extract file name
        final fileName = p.basename(entity.path);
        final name = fileName.replaceAll('.json', '');

        // Skip if name is empty
        if (name.isEmpty) {
          continue;
        }

        final relativePath = AppPaths.environmentFile(name);
        try {
          final json = await _fileStorageService.readJson(relativePath);
          envs.add(EnvironmentModel.fromJson(json));
        } catch (e) {
          // Log error but continue with other environments
          AppLogger.error('Error loading environment $name: $e');
        }
      }
    }

    return envs;
  }

  Future<EnvironmentModel?> loadEnvironmentByName(String name) async {
    final relativePath = AppPaths.environmentFile(name);

    try {
      final json = await _fileStorageService.readJson(relativePath);
      return EnvironmentModel.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveEnvironment(EnvironmentModel env) async {
    final relativePath = AppPaths.environmentFile(env.name);
    await _fileStorageService.writeJson(relativePath, env.toJson());
  }

  Future<void> deleteEnvironment(String name) async {
    final fullPath = await _workspaceService.resolvePath([AppPaths.environments, '$name.json']);
    final file = File(fullPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> setActiveEnvironment(String? name) async {
    _activeEnvironmentName = name;
  }

  Future<EnvironmentModel?> getActiveEnvironment() async {
    final name = _activeEnvironmentName;
    if (name == null || name.isEmpty) {
      return null;
    }
    return loadEnvironmentByName(name);
  }

  String resolveTemplate(String input, EnvironmentModel? env) {
    if (env == null || env.variables.isEmpty) return input;

    var result = input;

    env.variables.forEach((key, value) {
      final placeholder = '{{$key}}';
      result = result.replaceAll(placeholder, value);
    });

    return result;
  }
}
