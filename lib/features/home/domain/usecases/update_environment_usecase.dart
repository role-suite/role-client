import 'package:relay/core/models/environment_model.dart';
import 'package:relay/features/home/domain/repositories/environment_repository.dart';

/// Use case for updating an existing environment
class UpdateEnvironmentUseCase {
  final EnvironmentRepository _repository;

  UpdateEnvironmentUseCase(this._repository);

  Future<void> call(EnvironmentModel environment) async {
    // Check if environment exists
    final exists = await _repository.getEnvironmentByName(environment.name);
    if (exists == null) {
      throw Exception('Environment "${environment.name}" does not exist');
    }
    await _repository.saveEnvironment(environment);
  }
}
