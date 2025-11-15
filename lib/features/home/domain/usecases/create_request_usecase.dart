import 'package:relay/core/model/api_request_model.dart';
import 'package:relay/features/home/domain/repositories/request_repository.dart';

/// Use case for creating a new API request
class CreateRequestUseCase {
  final RequestRepository _repository;

  CreateRequestUseCase(this._repository);

  Future<void> call(ApiRequestModel request) async {
    await _repository.saveRequest(request);
  }
}

