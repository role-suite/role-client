import 'package:relay/features/home/domain/repositories/environment_repository.dart';

/// Use case for deleting an environment
class DeleteEnvironmentUseCase {
  final EnvironmentRepository _repository;

  DeleteEnvironmentUseCase(this._repository);

  Future<void> call(String name) async {
    await _repository.deleteEnvironment(name);
  }
}
