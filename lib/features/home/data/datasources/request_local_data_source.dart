import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:relay/core/constants/app_paths.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/services/file_storage_service.dart';
import 'package:relay/core/services/workspace_service.dart';
import 'package:relay/core/utils/logger.dart';

import 'request_data_source.dart';

/// Data source for local file-based storage of API requests
class RequestLocalDataSource implements RequestDataSource {
  final FileStorageService _fileStorageService;
  final WorkspaceService _workspaceService;

  RequestLocalDataSource(this._fileStorageService, this._workspaceService);

  @override
  Future<List<ApiRequestModel>> getAllRequests() async {
    final collectionsDir = await _workspaceService.resolvePath([AppPaths.collections]);
    final dir = Directory(collectionsDir);

    if (!await dir.exists()) {
      await dir.create(recursive: true);
      return [];
    }

    final entities = await dir.list(recursive: false, followLinks: false).toList();
    final allRequests = <ApiRequestModel>[];

    for (final entity in entities) {
      if (entity is Directory) {
        // Use path package to reliably extract directory name
        final collectionName = p.basename(entity.path);

        // Skip if collectionName is empty or invalid
        if (collectionName.isEmpty) {
          continue;
        }

        // Skip hidden directories and metadata files
        if (collectionName.startsWith('.') || collectionName == '_metadata.json') {
          continue;
        }

        try {
          final collectionRequests = await getRequestsByCollection(collectionName);
          allRequests.addAll(collectionRequests);
        } catch (e) {
          // Skip collections that can't be read, but log the error
          AppLogger.error('Error loading requests from collection $collectionName: $e');
        }
      }
    }

    return allRequests;
  }

  @override
  Future<List<ApiRequestModel>> getRequestsByCollection(String collection) async {
    final dirPath = await _workspaceService.resolvePath([AppPaths.collections, collection]);
    final dir = Directory(dirPath);

    if (!await dir.exists()) {
      await dir.create(recursive: true);
      return [];
    }

    final entities = await dir.list(recursive: false, followLinks: false).toList();
    final requests = <ApiRequestModel>[];

    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          // Use path package to reliably extract file name
          final fileName = p.basename(entity.path);

          // Skip metadata files
          if (fileName == '_metadata.json') {
            continue;
          }

          // Remove .json extension to get the ID
          final id = fileName.replaceAll('.json', '');
          final relativePath = AppPaths.collectionFile(collection, id);
          final json = await _fileStorageService.readJson(relativePath);
          final request = ApiRequestModel.fromJson(json);
          // Ensure the request has the correct collectionId
          requests.add(request.copyWith(collectionId: collection));
        } catch (e) {
          // Skip invalid files, but log the error
          AppLogger.error('Error loading request file ${entity.path}: $e');
        }
      }
    }

    return requests;
  }

  @override
  Future<ApiRequestModel?> getRequestById(String id) async {
    // Search in all collections
    final collectionsDir = await _workspaceService.resolvePath([AppPaths.collections]);
    final dir = Directory(collectionsDir);

    if (!await dir.exists()) {
      return null;
    }

    final entities = await dir.list(recursive: false, followLinks: false).toList();

    for (final entity in entities) {
      if (entity is Directory) {
        // Use path package to reliably extract directory name
        final collectionName = p.basename(entity.path);

        // Skip if collectionName is empty or invalid
        if (collectionName.isEmpty || collectionName.startsWith('.')) {
          continue;
        }

        final relativePath = AppPaths.collectionFile(collectionName, id);
        try {
          final json = await _fileStorageService.readJson(relativePath);
          return ApiRequestModel.fromJson(json);
        } catch (_) {
          // Continue searching in other collections
        }
      }
    }

    return null;
  }

  @override
  Future<void> saveRequest(ApiRequestModel request) async {
    // Validate request before saving
    if (request.id.isEmpty) {
      throw ArgumentError('Request ID cannot be empty');
    }
    if (request.collectionId.isEmpty) {
      throw ArgumentError('Request collectionId cannot be empty');
    }

    // Check if request already exists and if collection has changed
    final existingRequest = await getRequestById(request.id);

    // If request exists in a different collection, delete the old file
    if (existingRequest != null && existingRequest.collectionId != request.collectionId) {
      final oldCollection = existingRequest.collectionId;
      final oldRelativePath = AppPaths.collectionFile(oldCollection, request.id);
      final oldPathSegments = oldRelativePath.split('/');
      final oldFullPath = await _workspaceService.resolvePath(oldPathSegments);
      final oldFile = File(oldFullPath);

      if (await oldFile.exists()) {
        await oldFile.delete();
      }
    }

    // Save to the new/current collection
    final collection = request.collectionId;
    // Pass just the ID - collectionFile will add .json extension
    final relativePath = AppPaths.collectionFile(collection, request.id);

    // Ensure the JSON includes collectionId
    final jsonData = request.toJson();
    if (jsonData['collectionId'] == null || (jsonData['collectionId'] as String).isEmpty) {
      throw StateError('Request collectionId is missing in JSON data for request ${request.id}');
    }

    await _fileStorageService.writeJson(relativePath, jsonData);

    // Verify the file was written correctly
    final writtenJson = await _fileStorageService.readJson(relativePath);
    if (writtenJson['collectionId'] == null || (writtenJson['collectionId'] as String).isEmpty) {
      throw StateError('Failed to save request collectionId for request ${request.id}');
    }
  }

  @override
  Future<void> deleteRequest(String id) async {
    // Find the request first to know which collection it's in
    final request = await getRequestById(id);
    if (request == null) {
      return;
    }

    final collection = request.collectionId;
    final relativePath = AppPaths.collectionFile(collection, id);
    final pathSegments = relativePath.split('/');
    final fullPath = await _workspaceService.resolvePath(pathSegments);
    final file = File(fullPath);

    if (await file.exists()) {
      await file.delete();
    }
  }
}
