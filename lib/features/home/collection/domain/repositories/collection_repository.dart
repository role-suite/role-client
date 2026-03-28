import 'package:relay/core/models/collection_model.dart';

/// Repository interface for managing collections
/// This is part of the domain layer and defines the contract
abstract class CollectionRepository {
  /// Get all collections
  Future<List<CollectionModel>> getAllCollections();

  /// Get a collection by ID
  Future<CollectionModel?> getCollectionById(String id);

  /// Get a collection by name
  Future<CollectionModel?> getCollectionByName(String name);

  /// Save a collection (create or update)
  Future<void> saveCollection(CollectionModel collection);

  /// Delete a collection by ID
  Future<void> deleteCollection(String id);

  /// Check if a collection exists
  Future<bool> collectionExists(String name);
}
