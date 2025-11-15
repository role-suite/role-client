import 'package:relay/core/model/environment_model.dart';
import 'package:relay/features/home/domain/repositories/environment_repository.dart';

/// Use case for getting all environments
class GetAllEnvironmentsUseCase {
  final EnvironmentRepository _repository;

  GetAllEnvironmentsUseCase(this._repository);

  Future<List<EnvironmentModel>> call() async {
    return await _repository.getAllEnvironments();
  }
}

