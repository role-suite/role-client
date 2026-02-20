import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:relay/core/constants/app_paths.dart';
import 'package:relay/core/services/file_storage_service.dart';
import 'package:relay/core/services/workspace_service.dart';
import 'package:relay/core/utils/logger.dart';
import 'package:relay/features/request_chain/domain/models/saved_request_chain.dart';

/// Data source for local file-based storage of saved request chains
class SavedChainLocalDataSource {
  final FileStorageService _fileStorageService;
  final WorkspaceService _workspaceService;

  SavedChainLocalDataSource(this._fileStorageService, this._workspaceService);

  /// Get all saved chains
  Future<List<SavedRequestChain>> getAllSavedChains() async {
    final chainsDir = await _workspaceService.resolvePath([AppPaths.savedChains]);
    final dir = Directory(chainsDir);

    if (!await dir.exists()) {
      await dir.create(recursive: true);
      return [];
    }

    final entities = await dir.list(recursive: false, followLinks: false).toList();
    final chains = <SavedRequestChain>[];

    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final fileName = p.basename(entity.path);
          final id = fileName.replaceAll('.json', '');
          final relativePath = AppPaths.savedChainFile(id);
          final json = await _fileStorageService.readJson(relativePath);
          final chain = SavedRequestChain.fromJson(json);
          chains.add(chain);
        } catch (e) {
          AppLogger.error('Error loading saved chain file ${entity.path}: $e');
        }
      }
    }

    // Sort by updatedAt descending (most recent first)
    chains.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return chains;
  }

  /// Get a saved chain by ID
  Future<SavedRequestChain?> getSavedChainById(String id) async {
    try {
      final relativePath = AppPaths.savedChainFile(id);
      final json = await _fileStorageService.readJson(relativePath);
      return SavedRequestChain.fromJson(json);
    } catch (e) {
      AppLogger.error('Error loading saved chain $id: $e');
      return null;
    }
  }

  /// Save a chain (create or update)
  Future<void> saveChain(SavedRequestChain chain) async {
    if (chain.id.isEmpty) {
      throw ArgumentError('Chain ID cannot be empty');
    }
    if (chain.name.isEmpty) {
      throw ArgumentError('Chain name cannot be empty');
    }

    final relativePath = AppPaths.savedChainFile(chain.id);
    final jsonData = chain.toJson();
    await _fileStorageService.writeJson(relativePath, jsonData);
  }

  /// Delete a saved chain by ID
  Future<void> deleteChain(String id) async {
    try {
      final relativePath = AppPaths.savedChainFile(id);
      final fullPath = await _workspaceService.resolvePath(relativePath.split('/'));
      final file = File(fullPath);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      AppLogger.error('Error deleting saved chain $id: $e');
      rethrow;
    }
  }
}
