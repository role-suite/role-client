import 'package:relay/core/model/environment_model.dart';
import 'package:relay/core/service/environment_service.dart';
import 'package:relay/features/home/domain/repositories/environment_repository.dart';

/// Implementation of EnvironmentRepository using EnvironmentService
class EnvironmentRepositoryImpl implements EnvironmentRepository {
  final EnvironmentService _environmentService;

  EnvironmentRepositoryImpl(this._environmentService);

  @override
  Future<List<EnvironmentModel>> getAllEnvironments() async {
    return await _environmentService.loadAllEnvironments();
  }

  @override
  Future<EnvironmentModel?> getEnvironmentByName(String name) async {
    return await _environmentService.loadEnvironmentByName(name);
  }

  @override
  Future<void> saveEnvironment(EnvironmentModel environment) async {
    await _environmentService.saveEnvironment(environment);
  }

  @override
  Future<void> deleteEnvironment(String name) async {
    await _environmentService.deleteEnvironment(name);
  }

  @override
  Future<void> setActiveEnvironment(String? name) async {
    if (name != null) {
      await _environmentService.setActiveEnvironment(name);
    }
  }

  @override
  Future<EnvironmentModel?> getActiveEnvironment() async {
    return await _environmentService.getActiveEnvironment();
  }

  @override
  String resolveTemplate(String input, EnvironmentModel? environment) {
    return _environmentService.resolveTemplate(input, environment);
  }
}

