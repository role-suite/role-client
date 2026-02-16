import 'package:relay/core/models/collection_model.dart';

/// Abstraction for collection storage (local or remote).
abstract class CollectionDataSource {
  Future<List<CollectionModel>> getAllCollections();
  Future<CollectionModel?> getCollectionById(String id);
  Future<CollectionModel?> getCollectionByName(String name);
  Future<void> saveCollection(CollectionModel collection);
  Future<void> deleteCollection(String id);
  Future<bool> collectionExists(String name);
}
