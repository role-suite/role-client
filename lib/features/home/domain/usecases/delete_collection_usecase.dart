import 'package:relay/features/home/domain/repositories/collection_repository.dart';

/// Use case for deleting a collection
class DeleteCollectionUseCase {
  final CollectionRepository _repository;

  DeleteCollectionUseCase(this._repository);

  Future<void> call(String collectionId) async {
    await _repository.deleteCollection(collectionId);
  }
}

