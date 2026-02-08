import 'package:relay/core/constants/api_style.dart';
import 'package:relay/core/models/data_source_config.dart';
import 'package:relay/core/services/relay_api/relay_api_client.dart';
import 'package:relay/core/services/relay_api/rest_relay_api_client.dart';
import 'package:relay/core/services/relay_api/serverpod_relay_api_client.dart';
import 'package:relay/core/services/workspace_api/rest_workspace_client.dart';
import 'package:relay/features/home/domain/repositories/collection_repository.dart';
import 'package:relay/features/home/domain/repositories/environment_repository.dart';
import 'package:relay/features/home/domain/repositories/request_repository.dart';

/// Pushes local collections, requests, and environments to a remote API.
/// Use when the app is in local mode to sync data to the configured remote.
class SyncToRemoteService {
  SyncToRemoteService._();

  static RelayApiClient _createClient(DataSourceConfig config) {
    switch (config.apiStyle) {
      case ApiStyle.serverpod:
        return ServerpodRelayApiClient(serverUrl: config.baseUrl);
      case ApiStyle.rest:
        return RestRelayApiClient(
          RestWorkspaceClient(baseUrl: config.baseUrl, apiKey: config.apiKey),
        );
    }
  }

  /// Syncs all local collections, their requests, and environments to the remote.
  /// [config] must be valid (baseUrl non-empty). Use [DataSourcePreferencesService.loadConfig]
  /// or from user input.
  static Future<void> sync({
    required DataSourceConfig config,
    required CollectionRepository collectionRepository,
    required EnvironmentRepository environmentRepository,
    required RequestRepository requestRepository,
  }) async {
    if (!config.isValid) {
      throw ArgumentError('Sync requires a valid remote config (baseUrl)');
    }
    final api = _createClient(config);

    // 1. Sync collections (create or update)
    final collections = await collectionRepository.getAllCollections();
    for (final collection in collections) {
      final existing = await api.getCollection(collection.id);
      if (existing != null) {
        await api.updateCollection(collection);
      } else {
        await api.createCollection(collection);
      }
    }

    // 2. Sync requests per collection
    for (final collection in collections) {
      final requests = await requestRepository.getRequestsByCollection(collection.id);
      for (final request in requests) {
        final existing = await api.getRequest(request.id);
        if (existing != null) {
          await api.updateRequest(request);
        } else {
          await api.createRequest(request);
        }
      }
    }

    // 3. Sync environments (create or update by name)
    final environments = await environmentRepository.getAllEnvironments();
    for (final environment in environments) {
      final existing = await api.getEnvironment(environment.name);
      if (existing != null) {
        await api.updateEnvironment(environment);
      } else {
        await api.createEnvironment(environment);
      }
    }
  }
}
