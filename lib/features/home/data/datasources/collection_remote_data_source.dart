import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/workspace_bundle.dart';
import 'package:relay/core/services/workspace_api/workspace_api_client.dart';

import 'collection_data_source.dart';

/// Data source that reads/writes collections via the workspace API (REST or Serverpod RPC).
class CollectionRemoteDataSource implements CollectionDataSource {
  CollectionRemoteDataSource(this._client);

  final WorkspaceApiClient _client;

  @override
  Future<List<CollectionModel>> getAllCollections() async {
    final bundle = await _client.getWorkspace();
    final list = bundle.collections.map((b) => b.collection).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Future<CollectionModel?> getCollectionById(String id) async {
    final list = await getAllCollections();
    try {
      return list.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<CollectionModel?> getCollectionByName(String name) async {
    final list = await getAllCollections();
    try {
      return list.firstWhere((c) => c.name == name);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveCollection(CollectionModel collection) async {
    final bundle = await _client.getWorkspace();
    final newCollections = <CollectionBundle>[];
    var found = false;
    for (final cb in bundle.collections) {
      if (cb.collection.id == collection.id) {
        newCollections.add(CollectionBundle(collection: collection, requests: cb.requests));
        found = true;
      } else {
        newCollections.add(cb);
      }
    }
    if (!found) {
      newCollections.add(CollectionBundle(collection: collection, requests: const []));
    }
    final newBundle = WorkspaceBundle(
      version: bundle.version,
      exportedAt: bundle.exportedAt,
      source: bundle.source,
      collections: newCollections,
      environments: bundle.environments,
    );
    await _client.putWorkspace(newBundle);
  }

  @override
  Future<void> deleteCollection(String id) async {
    if (id == 'default') {
      throw ArgumentError('Cannot delete the default collection');
    }
    final bundle = await _client.getWorkspace();
    final newCollections = bundle.collections.where((cb) => cb.collection.id != id).toList();
    final newBundle = WorkspaceBundle(
      version: bundle.version,
      exportedAt: bundle.exportedAt,
      source: bundle.source,
      collections: newCollections,
      environments: bundle.environments,
    );
    await _client.putWorkspace(newBundle);
  }

  @override
  Future<bool> collectionExists(String name) async {
    final c = await getCollectionByName(name);
    return c != null;
  }
}
