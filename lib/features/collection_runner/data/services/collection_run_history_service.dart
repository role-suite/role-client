import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:relay/core/constants/app_paths.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/services/file_storage_service.dart';
import 'package:relay/core/services/workspace_service.dart';
import 'package:relay/core/utils/uuid.dart';
import 'package:relay/features/collection_runner/domain/models/collection_run_history.dart';
import 'package:relay/features/collection_runner/domain/models/collection_run_result.dart';

class CollectionRunHistoryService {
  CollectionRunHistoryService._internal(
    this._fileStorageService,
    this._workspaceService,
  );

  static CollectionRunHistoryService? _instance;
  factory CollectionRunHistoryService() {
    _instance ??= CollectionRunHistoryService._internal(
      FileStorageService.instance,
      WorkspaceService.instance,
    );
    return _instance!;
  }

  static CollectionRunHistoryService get instance => CollectionRunHistoryService();

  final FileStorageService _fileStorageService;
  final WorkspaceService _workspaceService;

  /// Save a collection run history
  Future<String> saveHistory({
    required CollectionModel collection,
    EnvironmentModel? environment,
    required DateTime completedAt,
    required List<CollectionRunResult> results,
  }) async {
    final id = UuidUtils.generate();
    final history = CollectionRunHistory(
      id: id,
      collection: collection,
      environment: environment,
      completedAt: completedAt,
      results: results,
    );

    final fileName = '${id}.json';
    final historyPath = p.join(AppPaths.history, fileName);
    await _fileStorageService.writeJson(historyPath, history.toJson());

    return id;
  }

  /// Get all collection run histories
  Future<List<CollectionRunHistory>> getAllHistories() async {
    final historyDir = await _workspaceService.resolvePath([AppPaths.history]);
    final dir = Directory(historyDir);

    if (!await dir.exists()) {
      return [];
    }

    final entities = await dir.list(recursive: false, followLinks: false).toList();
    final histories = <CollectionRunHistory>[];

    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final json = await _fileStorageService.readJson(
            p.join(AppPaths.history, p.basename(entity.path)),
          );
          final history = _fromJson(json);
          histories.add(history);
        } catch (e) {
          // Skip corrupted files
          print('Error loading history file ${entity.path}: $e');
        }
      }
    }

    // Sort by completedAt descending (most recent first)
    histories.sort((a, b) => b.completedAt.compareTo(a.completedAt));

    return histories;
  }

  /// Get a specific history by ID
  Future<CollectionRunHistory?> getHistoryById(String id) async {
    try {
      final fileName = '${id}.json';
      final historyPath = p.join(AppPaths.history, fileName);
      final json = await _fileStorageService.readJson(historyPath);
      return _fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// Delete a history by ID
  Future<void> deleteHistory(String id) async {
    final fileName = '${id}.json';
    final historyPath = await _workspaceService.resolvePath([AppPaths.history, fileName]);
    final file = File(historyPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  CollectionRunHistory _fromJson(Map<String, dynamic> json) {
    final collectionJson = json['collection'] as Map<String, dynamic>;
    final collection = CollectionModel.fromJson(collectionJson);

    final environmentJson = json['environment'] as Map<String, dynamic>?;
    final environment = environmentJson != null
        ? EnvironmentModel.fromJson(environmentJson)
        : null;

    final completedAt = DateTime.parse(json['completedAt'] as String);

    final resultsJson = json['results'] as List<dynamic>;
    final results = resultsJson.map((resultJson) {
      final requestJson = resultJson['request'] as Map<String, dynamic>;
      final request = ApiRequestModel.fromJson(requestJson);

      final statusStr = resultJson['status'] as String;
      final status = CollectionRunStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => CollectionRunStatus.failed,
      );

      final durationMs = resultJson['duration'] as int?;
      final duration = durationMs != null ? Duration(milliseconds: durationMs) : null;

      return CollectionRunResult(
        request: request,
        status: status,
        statusCode: resultJson['statusCode'] as int?,
        statusMessage: resultJson['statusMessage'] as String?,
        duration: duration,
        errorMessage: resultJson['errorMessage'] as String?,
      );
    }).toList();

    return CollectionRunHistory(
      id: json['id'] as String,
      collection: collection,
      environment: environment,
      completedAt: completedAt,
      results: results,
    );
  }
}
