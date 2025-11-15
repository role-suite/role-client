import 'package:relay/features/home/domain/repositories/environment_repository.dart';

/// Use case for setting the active environment
class SetActiveEnvironmentUseCase {
  final EnvironmentRepository _repository;

  SetActiveEnvironmentUseCase(this._repository);

  Future<void> call(String? environmentName) async {
    await _repository.setActiveEnvironment(environmentName);
  }
}

