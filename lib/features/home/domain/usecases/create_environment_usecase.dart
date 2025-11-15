import 'package:relay/core/model/environment_model.dart';
import 'package:relay/features/home/domain/repositories/environment_repository.dart';

/// Use case for creating a new environment
class CreateEnvironmentUseCase {
  final EnvironmentRepository _repository;

  CreateEnvironmentUseCase(this._repository);

  Future<void> call(EnvironmentModel environment) async {
    // Check if environment with same name already exists
    final exists = await _repository.getEnvironmentByName(environment.name);
    if (exists != null) {
      throw Exception('An environment with the name "${environment.name}" already exists');
    }
    await _repository.saveEnvironment(environment);
  }
}

