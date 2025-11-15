import 'package:relay/core/model/collection_model.dart';
import 'package:relay/features/home/data/datasources/collection_local_data_source.dart';
import 'package:relay/features/home/domain/repositories/collection_repository.dart';

/// Implementation of CollectionRepository using local file storage
class CollectionRepositoryImpl implements CollectionRepository {
  final CollectionLocalDataSource _dataSource;

  CollectionRepositoryImpl(this._dataSource);

  @override
  Future<List<CollectionModel>> getAllCollections() async {
    return await _dataSource.getAllCollections();
  }

  @override
  Future<CollectionModel?> getCollectionById(String id) async {
    return await _dataSource.getCollectionById(id);
  }

  @override
  Future<CollectionModel?> getCollectionByName(String name) async {
    return await _dataSource.getCollectionByName(name);
  }

  @override
  Future<void> saveCollection(CollectionModel collection) async {
    await _dataSource.saveCollection(collection);
  }

  @override
  Future<void> deleteCollection(String id) async {
    await _dataSource.deleteCollection(id);
  }

  @override
  Future<bool> collectionExists(String name) async {
    return await _dataSource.collectionExists(name);
  }
}

