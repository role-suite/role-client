import 'package:relay/features/home/domain/repositories/request_repository.dart';

/// Use case for deleting an API request
class DeleteRequestUseCase {
  final RequestRepository _repository;

  DeleteRequestUseCase(this._repository);

  Future<void> call(String requestId) async {
    await _repository.deleteRequest(requestId);
  }
}
