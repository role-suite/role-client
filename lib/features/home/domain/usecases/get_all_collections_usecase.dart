import 'package:relay/core/models/collection_model.dart';
import 'package:relay/features/home/domain/repositories/collection_repository.dart';

/// Use case for getting all collections
class GetAllCollectionsUseCase {
  final CollectionRepository _repository;

  GetAllCollectionsUseCase(this._repository);

  Future<List<CollectionModel>> call() async {
    return await _repository.getAllCollections();
  }
}

