import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/services/relay_api/relay_api_client.dart';

import 'collection_data_source.dart';

/// Data source that reads/writes collections via the Relay API (REST or Serverpod).
class CollectionRemoteDataSource implements CollectionDataSource {
  CollectionRemoteDataSource(this._api);

  final RelayApiClient _api;

  @override
  Future<List<CollectionModel>> getAllCollections() async {
    return _api.listCollections();
  }

  @override
  Future<CollectionModel?> getCollectionById(String id) async {
    return _api.getCollection(id);
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
    final existing = await getCollectionById(collection.id);
    if (existing == null) {
      await _api.createCollection(collection);
    } else {
      await _api.updateCollection(collection);
    }
  }

  @override
  Future<void> deleteCollection(String id) async {
    if (id == 'default') {
      throw ArgumentError('Cannot delete the default collection');
    }
    await _api.deleteCollection(id);
  }

  @override
  Future<bool> collectionExists(String name) async {
    final c = await getCollectionByName(name);
    return c != null;
  }
}
