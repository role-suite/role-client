import 'package:relay/core/model/environment_model.dart';
import 'package:relay/features/home/domain/repositories/environment_repository.dart';

/// Use case for getting the active environment
class GetActiveEnvironmentUseCase {
  final EnvironmentRepository _repository;

  GetActiveEnvironmentUseCase(this._repository);

  Future<EnvironmentModel?> call() async {
    return await _repository.getActiveEnvironment();
  }
}

