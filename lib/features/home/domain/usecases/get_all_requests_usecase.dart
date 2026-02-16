import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/features/home/domain/repositories/request_repository.dart';

/// Use case for getting all API requests
class GetAllRequestsUseCase {
  final RequestRepository _repository;

  GetAllRequestsUseCase(this._repository);

  Future<List<ApiRequestModel>> call() async {
    return await _repository.getAllRequests();
  }
}
