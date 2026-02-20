import 'dart:async';

import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/models/workspace_bundle.dart';
import 'package:relay/core/services/relay_api/relay_api_client.dart';
import 'package:relay/core/services/workspace_api/workspace_api_client.dart';

/// Relay API client backed by workspace GET/PUT (REST). Fetches full workspace
/// and performs list/get/create/update/delete in memory, then PUTs back.
class RestRelayApiClient implements RelayApiClient {
  RestRelayApiClient(this._workspace);

  final WorkspaceApiClient _workspace;
  Future<void> _writeQueue = Future.value();

  Future<WorkspaceBundle> _getBundle() => _workspace.getWorkspace();

  Future<void> _putBundle(WorkspaceBundle bundle) => _workspace.putWorkspace(bundle);

  Future<T> _runWriteLocked<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  @override
  Future<List<CollectionModel>> listCollections() async {
    final bundle = await _getBundle();
    final list = bundle.collections.map((b) => b.collection).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Future<CollectionModel?> getCollection(String id) async {
    final list = await listCollections();
    for (final collection in list) {
      if (collection.id == id) {
        return collection;
      }
    }
    return null;
  }

  @override
  Future<void> createCollection(CollectionModel collection) async {
    return _runWriteLocked(() async {
      final bundle = await _getBundle();
      final newCollections = List<CollectionBundle>.from(bundle.collections)..add(CollectionBundle(collection: collection, requests: []));
      await _putBundle(
        WorkspaceBundle(
          version: bundle.version,
          exportedAt: bundle.exportedAt,
          source: bundle.source,
          collections: newCollections,
          environments: bundle.environments,
        ),
      );
    });
  }

  @override
  Future<void> updateCollection(CollectionModel collection) async {
    return _runWriteLocked(() async {
      final bundle = await _getBundle();
      final newCollections = <CollectionBundle>[];
      for (final cb in bundle.collections) {
        if (cb.collection.id == collection.id) {
          newCollections.add(CollectionBundle(collection: collection, requests: cb.requests));
        } else {
          newCollections.add(cb);
        }
      }
      await _putBundle(
        WorkspaceBundle(
          version: bundle.version,
          exportedAt: bundle.exportedAt,
          source: bundle.source,
          collections: newCollections,
          environments: bundle.environments,
        ),
      );
    });
  }

  @override
  Future<void> deleteCollection(String id) async {
    return _runWriteLocked(() async {
      final bundle = await _getBundle();
      final newCollections = bundle.collections.where((cb) => cb.collection.id != id).toList();
      await _putBundle(
        WorkspaceBundle(
          version: bundle.version,
          exportedAt: bundle.exportedAt,
          source: bundle.source,
          collections: newCollections,
          environments: bundle.environments,
        ),
      );
    });
  }

  @override
  Future<List<EnvironmentModel>> listEnvironments() async {
    final bundle = await _getBundle();
    return List.from(bundle.environments);
  }

  @override
  Future<EnvironmentModel?> getEnvironment(String name) async {
    final list = await listEnvironments();
    for (final environment in list) {
      if (environment.name == name) {
        return environment;
      }
    }
    return null;
  }

  @override
  Future<void> createEnvironment(EnvironmentModel environment) async {
    return _runWriteLocked(() async {
      final bundle = await _getBundle();
      final newEnvs = List<EnvironmentModel>.from(bundle.environments)..add(environment);
      await _putBundle(
        WorkspaceBundle(
          version: bundle.version,
          exportedAt: bundle.exportedAt,
          source: bundle.source,
          collections: bundle.collections,
          environments: newEnvs,
        ),
      );
    });
  }

  @override
  Future<void> updateEnvironment(EnvironmentModel environment) async {
    return _runWriteLocked(() async {
      final bundle = await _getBundle();
      final newEnvs = bundle.environments.map((e) => e.name == environment.name ? environment : e).toList();
      await _putBundle(
        WorkspaceBundle(
          version: bundle.version,
          exportedAt: bundle.exportedAt,
          source: bundle.source,
          collections: bundle.collections,
          environments: newEnvs,
        ),
      );
    });
  }

  @override
  Future<void> deleteEnvironment(String name) async {
    return _runWriteLocked(() async {
      final bundle = await _getBundle();
      final newEnvs = bundle.environments.where((e) => e.name != name).toList();
      await _putBundle(
        WorkspaceBundle(
          version: bundle.version,
          exportedAt: bundle.exportedAt,
          source: bundle.source,
          collections: bundle.collections,
          environments: newEnvs,
        ),
      );
    });
  }

  @override
  Future<List<ApiRequestModel>> listRequests(String collectionId) async {
    final bundle = await _getBundle();
    final cb = bundle.collections.where((b) => b.collection.id == collectionId).toList();
    if (cb.isEmpty) return [];
    return cb.first.requests.map((r) => r.collectionId == collectionId ? r : r.copyWith(collectionId: collectionId)).toList();
  }

  @override
  Future<ApiRequestModel?> getRequest(String requestId) async {
    final bundle = await _getBundle();
    for (final cb in bundle.collections) {
      for (final r in cb.requests) {
        if (r.id == requestId) {
          return r.collectionId == cb.collection.id ? r : r.copyWith(collectionId: cb.collection.id);
        }
      }
    }
    return null;
  }

  @override
  Future<void> createRequest(ApiRequestModel request) async {
    return _runWriteLocked(() async {
      final bundle = await _getBundle();
      final newCollections = <CollectionBundle>[];
      var added = false;
      for (final cb in bundle.collections) {
        if (cb.collection.id != request.collectionId) {
          newCollections.add(cb);
          continue;
        }
        final newRequests = List<ApiRequestModel>.from(cb.requests)..add(request);
        newCollections.add(CollectionBundle(collection: cb.collection, requests: newRequests));
        added = true;
      }
      if (!added) {
        final now = DateTime.now();
        final placeholder = CollectionModel(
          id: request.collectionId,
          name: 'Collection ${request.collectionId}',
          description: '',
          createdAt: now,
          updatedAt: now,
        );
        newCollections.add(CollectionBundle(collection: placeholder, requests: [request]));
      }
      await _putBundle(
        WorkspaceBundle(
          version: bundle.version,
          exportedAt: bundle.exportedAt,
          source: bundle.source,
          collections: newCollections,
          environments: bundle.environments,
        ),
      );
    });
  }

  @override
  Future<void> updateRequest(ApiRequestModel request) async {
    return _runWriteLocked(() async {
      final bundle = await _getBundle();
      final newCollections = <CollectionBundle>[];
      for (final cb in bundle.collections) {
        final requests = cb.requests.where((r) => r.id != request.id).toList();
        if (cb.collection.id == request.collectionId) {
          requests.add(request);
        }
        newCollections.add(CollectionBundle(collection: cb.collection, requests: requests));
      }
      if (!newCollections.any((c) => c.collection.id == request.collectionId)) {
        final now = DateTime.now();
        newCollections.add(
          CollectionBundle(
            collection: CollectionModel(
              id: request.collectionId,
              name: 'Collection ${request.collectionId}',
              description: '',
              createdAt: now,
              updatedAt: now,
            ),
            requests: [request],
          ),
        );
      }
      await _putBundle(
        WorkspaceBundle(
          version: bundle.version,
          exportedAt: bundle.exportedAt,
          source: bundle.source,
          collections: newCollections,
          environments: bundle.environments,
        ),
      );
    });
  }

  @override
  Future<void> deleteRequest(String requestId) async {
    return _runWriteLocked(() async {
      final request = await getRequest(requestId);
      if (request == null) return;
      final bundle = await _getBundle();
      final newCollections = <CollectionBundle>[];
      for (final cb in bundle.collections) {
        if (cb.collection.id != request.collectionId) {
          newCollections.add(cb);
          continue;
        }
        final newRequests = cb.requests.where((r) => r.id != requestId).toList();
        newCollections.add(CollectionBundle(collection: cb.collection, requests: newRequests));
      }
      await _putBundle(
        WorkspaceBundle(
          version: bundle.version,
          exportedAt: bundle.exportedAt,
          source: bundle.source,
          collections: newCollections,
          environments: bundle.environments,
        ),
      );
    });
  }
}
