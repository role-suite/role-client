import 'package:relay/core/model/collection_model.dart';
import 'package:relay/features/home/domain/repositories/collection_repository.dart';

/// Use case for creating a new collection
class CreateCollectionUseCase {
  final CollectionRepository _repository;

  CreateCollectionUseCase(this._repository);

  Future<void> call(CollectionModel collection) async {
    // Check if collection with same name already exists
    final exists = await _repository.collectionExists(collection.name);
    if (exists) {
      throw Exception('A collection with the name "${collection.name}" already exists');
    }
    await _repository.saveCollection(collection);
  }
}

