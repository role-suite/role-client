import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/models/request_enums.dart';
import 'package:relay/core/services/relay_api/relay_api_client.dart';
import 'package:relay/core/utils/logger.dart';
import 'package:relay_server_client/relay_server_client.dart' as relay_client;
import 'package:serverpod_flutter/serverpod_flutter.dart';

import '../../utils/extension.dart';

/// Relay API client using Serverpod RPC (collections, environments, requests endpoints).
class ServerpodRelayApiClient implements RelayApiClient {
  ServerpodRelayApiClient({required String serverUrl}) {
    final url = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    _serverUrl = url.isEmpty ? '' : url;
    _client = relay_client.Client(_serverUrl)
      ..connectivityMonitor = FlutterConnectivityMonitor();
  }

  late final String _serverUrl;
  late final relay_client.Client _client;

  void _requireUrl() {
    if (_serverUrl.isEmpty) {
      throw ArgumentError('Serverpod server URL is not set');
    }
  }

  @override
  Future<List<CollectionModel>> listCollections() async {
    _requireUrl();
    try {
      final list = await _client.collections.list();
      return list.map(_collectionFromServer).toList();
    } catch (e, st) {
      AppLogger.error('ServerpodRelayApiClient.listCollections: $e');
      AppLogger.error('  $st');
      rethrow;
    }
  }

  @override
  Future<CollectionModel?> getCollection(String id) async {
    _requireUrl();
    try {
      final c = await _client.collections.get(id);
      return c == null ? null : _collectionFromServer(c);
    } catch (e, st) {
      AppLogger.error('ServerpodRelayApiClient.getCollection: $e');
      AppLogger.error('  $st');
      rethrow;
    }
  }

  @override
  Future<void> createCollection(CollectionModel collection) async {
    _requireUrl();
    try {
      await _client.collections.create(_collectionToServer(collection));
    } catch (e, st) {
      AppLogger.error('ServerpodRelayApiClient.createCollection: $e');
      AppLogger.error('  $st');
      rethrow;
    }
  }

  @override
  Future<void> updateCollection(CollectionModel collection) async {
    _requireUrl();
    try {
      await _client.collections.update(_collectionToServer(collection));
    } catch (e, st) {
      AppLogger.error('ServerpodRelayApiClient.updateCollection: $e');
      AppLogger.error('  $st');
      rethrow;
    }
  }

  @override
  Future<void> deleteCollection(String id) async {
    _requireUrl();
    try {
      await _client.collections.delete(id);
    } catch (e, st) {
      AppLogger.error('ServerpodRelayApiClient.deleteCollection: $e');
      AppLogger.error('  $st');
      rethrow;
    }
  }

  @override
  Future<List<EnvironmentModel>> listEnvironments() async {
    _requireUrl();
    try {
      final list = await _client.environments.list();
      return list.map(_environmentFromServer).toList();
    } catch (e, st) {
      AppLogger.error('ServerpodRelayApiClient.listEnvironments: $e');
      AppLogger.error('  $st');
      rethrow;
    }
  }

  @override
  Future<EnvironmentModel?> getEnvironment(String name) async {
    _requireUrl();
    try {
      final e = await _client.environments.get(name);
      return e == null ? null : _environmentFromServer(e);
    } catch (e, st) {
      AppLogger.error('ServerpodRelayApiClient.getEnvironment: $e');
      AppLogger.error('  $st');
      rethrow;
    }
  }

  @override
  Future<void> createEnvironment(EnvironmentModel environment) async {
    _requireUrl();
    try {
      await _client.environments.create(_environmentToServer(environment));
    } catch (e, st) {
      AppLogger.error('ServerpodRelayApiClient.createEnvironment: $e');
      AppLogger.error('  $st');
      rethrow;
    }
  }

  @override
  Future<void> updateEnvironment(EnvironmentModel environment) async {
    _requireUrl();
    try {
      await _client.environments.update(_environmentToServer(environment));
    } catch (e, st) {
      AppLogger.error('ServerpodRelayApiClient.updateEnvironment: $e');
      AppLogger.error('  $st');
      rethrow;
    }
  }

  @override
  Future<void> deleteEnvironment(String name) async {
    _requireUrl();
    try {
      await _client.environments.delete(name);
    } catch (e, st) {
      AppLogger.error('ServerpodRelayApiClient.deleteEnvironment: $e');
      AppLogger.error('  $st');
      rethrow;
    }
  }

  @override
  Future<List<ApiRequestModel>> listRequests(String collectionId) async {
    _requireUrl();
    try {
      final list = await _client.requests.list(collectionId);
      return list.map(_requestFromServer).toList();
    } catch (e, st) {
      AppLogger.error('ServerpodRelayApiClient.listRequests: $e');
      AppLogger.error('  $st');
      rethrow;
    }
  }

  @override
  Future<ApiRequestModel?> getRequest(String requestId) async {
    _requireUrl();
    try {
      final r = await _client.requests.get(requestId);
      return r == null ? null : _requestFromServer(r);
    } catch (e, st) {
      AppLogger.error('ServerpodRelayApiClient.getRequest: $e');
      AppLogger.error('  $st');
      rethrow;
    }
  }

  @override
  Future<void> createRequest(ApiRequestModel request) async {
    _requireUrl();
    try {
      await _client.requests.create(_requestToServer(request));
    } catch (e, st) {
      AppLogger.error('ServerpodRelayApiClient.createRequest: $e');
      AppLogger.error('  $st');
      rethrow;
    }
  }

  @override
  Future<void> updateRequest(ApiRequestModel request) async {
    _requireUrl();
    try {
      await _client.requests.update(_requestToServer(request));
    } catch (e, st) {
      AppLogger.error('ServerpodRelayApiClient.updateRequest: $e');
      AppLogger.error('  $st');
      rethrow;
    }
  }

  @override
  Future<void> deleteRequest(String requestId) async {
    _requireUrl();
    try {
      await _client.requests.delete(requestId);
    } catch (e, st) {
      AppLogger.error('ServerpodRelayApiClient.deleteRequest: $e');
      AppLogger.error('  $st');
      rethrow;
    }
  }

  static CollectionModel _collectionFromServer(relay_client.CollectionModel server) {
    return CollectionModel(
      id: server.id,
      name: server.name,
      description: server.description,
      createdAt: server.createdAt,
      updatedAt: server.updatedAt,
    );
  }

  static relay_client.CollectionModel _collectionToServer(CollectionModel app) {
    return relay_client.CollectionModel(
      id: app.id,
      name: app.name,
      description: app.description,
      createdAt: app.createdAt,
      updatedAt: app.updatedAt,
    );
  }

  static EnvironmentModel _environmentFromServer(relay_client.EnvironmentModel server) {
    return EnvironmentModel(
      name: server.name,
      variables: Map<String, String>.from(server.variables),
    );
  }

  static relay_client.EnvironmentModel _environmentToServer(EnvironmentModel app) {
    return relay_client.EnvironmentModel(
      name: app.name,
      variables: Map<String, String>.from(app.variables),
    );
  }

  static ApiRequestModel _requestFromServer(relay_client.ApiRequestModel server) {
    return ApiRequestModel(
      id: server.id,
      name: server.name,
      method: HttpMethodX.fromString(server.method),
      urlTemplate: server.urlTemplate,
      headers: Map<String, String>.from(server.headers),
      queryParams: Map<String, String>.from(server.queryParams),
      body: server.body,
      bodyType: BodyTypeX.fromString(server.bodyType),
      formDataFields: Map<String, String>.from(server.formDataFields),
      authType: AuthTypeX.fromString(server.authType),
      authConfig: Map<String, String>.from(server.authConfig),
      description: server.description,
      filePath: server.filePath,
      collectionId: server.collectionId,
      environmentName: server.environmentName,
      createdAt: server.createdAt,
      updatedAt: server.updatedAt,
    );
  }

  static relay_client.ApiRequestModel _requestToServer(ApiRequestModel app) {
    return relay_client.ApiRequestModel(
      id: app.id,
      name: app.name,
      method: app.method.name,
      urlTemplate: app.urlTemplate,
      headers: Map<String, String>.from(app.headers),
      queryParams: Map<String, String>.from(app.queryParams),
      body: app.body,
      bodyType: app.bodyType.name,
      formDataFields: Map<String, String>.from(app.formDataFields),
      authType: app.authType.name,
      authConfig: Map<String, String>.from(app.authConfig),
      description: app.description,
      filePath: app.filePath,
      collectionId: app.collectionId,
      environmentName: app.environmentName,
      createdAt: app.createdAt,
      updatedAt: app.updatedAt,
    );
  }
}
