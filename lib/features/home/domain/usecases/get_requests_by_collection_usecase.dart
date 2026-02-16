import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/features/home/domain/repositories/request_repository.dart';

/// Use case for getting requests by collection
class GetRequestsByCollectionUseCase {
  final RequestRepository _repository;

  GetRequestsByCollectionUseCase(this._repository);

  Future<List<ApiRequestModel>> call(String collection) async {
    return await _repository.getRequestsByCollection(collection);
  }
}

