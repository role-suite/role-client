import 'package:relay/core/model/api_request_model.dart';
import 'package:relay/features/home/domain/repositories/request_repository.dart';

/// Use case for updating an existing API request
class UpdateRequestUseCase {
  final RequestRepository _repository;

  UpdateRequestUseCase(this._repository);

  Future<void> call(ApiRequestModel request) async {
    await _repository.saveRequest(request);
  }
}

