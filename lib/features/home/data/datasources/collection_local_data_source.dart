import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:relay/core/constants/app_paths.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/services/file_storage_service.dart';
import 'package:relay/core/services/workspace_service.dart';
import 'package:relay/core/utils/logger.dart';

/// Data source for local file-based storage of collections
class CollectionLocalDataSource {
  final FileStorageService _fileStorageService;
  final WorkspaceService _workspaceService;

  CollectionLocalDataSource(this._fileStorageService, this._workspaceService);

  /// Get all collections
  Future<List<CollectionModel>> getAllCollections() async {
    final collectionsDir = await _workspaceService.resolvePath([AppPaths.collections]);
    final dir = Directory(collectionsDir);

    if (!await dir.exists()) {
      await dir.create(recursive: true);
      // Create default collection
      await _ensureDefaultCollection();
      return await _loadCollectionsFromDirectory(dir);
    }

    final collections = await _loadCollectionsFromDirectory(dir);

    // Ensure default collection exists
    if (!collections.any((c) => c.id == 'default')) {
      await _ensureDefaultCollection();
      return await _loadCollectionsFromDirectory(dir);
    }

    return collections;
  }

  Future<void> _ensureDefaultCollection() async {
    final defaultCollection = CollectionModel(
      id: 'default',
      name: 'Default',
      description: 'Default collection for API requests',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await saveCollection(defaultCollection);
  }

  Future<List<CollectionModel>> _loadCollectionsFromDirectory(Directory dir) async {
    final entities = await dir.list(recursive: false, followLinks: false).toList();
    final collections = <CollectionModel>[];

    for (final entity in entities) {
      if (entity is Directory) {
        try {
          // Use path package to reliably extract directory name
          final collectionId = p.basename(entity.path);

          // Skip if collectionId is empty or invalid
          if (collectionId.isEmpty) {
            AppLogger.warn('Warning: Found directory with empty name, skipping: ${entity.path}');
            continue;
          }

          // Skip hidden directories
          if (collectionId.startsWith('.')) {
            continue;
          }

          final metadataPath = await _workspaceService.resolvePath([AppPaths.collections, collectionId, '_metadata.json']);
          final metadataFile = File(metadataPath);

          if (await metadataFile.exists()) {
            try {
              final json = await _fileStorageService.readJson('${AppPaths.collections}/$collectionId/_metadata.json');

              // Force to find name - require it to be present and non-empty
              final nameValue = json['name'];
              if (nameValue == null) {
                AppLogger.warn('Error: Collection "$collectionId" has missing name field in JSON. JSON content: $json');
                continue;
              }

              final nameString = nameValue as String?;
              if (nameString == null || nameString.isEmpty) {
                AppLogger.warn('Error: Collection "$collectionId" has empty name. JSON content: $json');
                continue;
              }

              // Name exists and is valid - parse normally
              final collection = CollectionModel.fromJson(json);
              collections.add(collection);
            } catch (e) {
              // If reading metadata fails completely, skip this collection
              AppLogger.error('Error reading metadata for collection $collectionId: $e');
              // Don't create a fallback - skip corrupted collections
              continue;
            }
          } else {
            // Legacy collection without metadata - skip it (don't auto-create)
            AppLogger.error('Warning: Collection $collectionId has no metadata file. Skipping.');
            continue;
          }
        } catch (e) {
          // Log error but continue with other collections
          AppLogger.error('Error loading collection: $e');
        }
      }
    }

    // Sort collections by name for consistent display
    collections.sort((a, b) => a.name.compareTo(b.name));

    return collections;
  }

  /// Get a collection by ID
  Future<CollectionModel?> getCollectionById(String id) async {
    final allCollections = await getAllCollections();
    try {
      return allCollections.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get a collection by name
  Future<CollectionModel?> getCollectionByName(String name) async {
    final allCollections = await getAllCollections();
    try {
      return allCollections.firstWhere((c) => c.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Save a collection (create or update)
  Future<void> saveCollection(CollectionModel collection) async {
    // Validate collection before saving
    if (collection.id.isEmpty) {
      throw ArgumentError('Collection ID cannot be empty');
    }
    if (collection.name.isEmpty) {
      throw ArgumentError('Collection name cannot be empty');
    }

    // Create collection directory
    final collectionDir = await _workspaceService.resolvePath([AppPaths.collections, collection.id]);
    final dir = Directory(collectionDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Save metadata - ensure toJson includes name
    final jsonData = collection.toJson();
    if (jsonData['name'] == null || (jsonData['name'] as String).isEmpty) {
      throw StateError('Collection name is missing in JSON data for collection ${collection.id}');
    }

    final metadataPath = '${AppPaths.collections}/${collection.id}/_metadata.json';
    await _fileStorageService.writeJson(metadataPath, jsonData);

    // Verify the file was written correctly
    final writtenJson = await _fileStorageService.readJson(metadataPath);
    if (writtenJson['name'] == null || (writtenJson['name'] as String).isEmpty) {
      throw StateError('Failed to save collection name for collection ${collection.id}');
    }
  }

  /// Delete a collection by ID
  /// This will also delete all requests in the collection since they're stored in the collection directory
  Future<void> deleteCollection(String id) async {
    // Prevent deleting the default collection
    if (id == 'default') {
      throw ArgumentError('Cannot delete the default collection');
    }

    final collectionDir = await _workspaceService.resolvePath([AppPaths.collections, id]);
    final dir = Directory(collectionDir);

    if (await dir.exists()) {
      // Delete the entire directory recursively, which includes all requests
      await dir.delete(recursive: true);
    }
  }

  /// Check if a collection exists by name
  Future<bool> collectionExists(String name) async {
    final collection = await getCollectionByName(name);
    return collection != null;
  }
}
