import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/services/environment_service.dart';
import 'package:relay/core/services/relay_api/relay_api_client.dart';
import 'package:relay/features/home/domain/repositories/environment_repository.dart';

/// Environment repository that reads/writes environments via the Relay API (REST or Serverpod).
/// Active environment state is kept in EnvironmentService (local preference).
class EnvironmentRepositoryRemoteImpl implements EnvironmentRepository {
  EnvironmentRepositoryRemoteImpl(this._api, this._environmentService);

  final RelayApiClient _api;
  final EnvironmentService _environmentService;

  @override
  Future<List<EnvironmentModel>> getAllEnvironments() async {
    return _api.listEnvironments();
  }

  @override
  Future<EnvironmentModel?> getEnvironmentByName(String name) async {
    return _api.getEnvironment(name);
  }

  @override
  Future<void> saveEnvironment(EnvironmentModel environment) async {
    final existing = await getEnvironmentByName(environment.name);
    if (existing == null) {
      await _api.createEnvironment(environment);
    } else {
      await _api.updateEnvironment(environment);
    }
  }

  @override
  Future<void> deleteEnvironment(String name) async {
    await _api.deleteEnvironment(name);
  }

  @override
  Future<void> setActiveEnvironment(String? name) async {
    await _environmentService.setActiveEnvironment(name);
  }

  @override
  Future<EnvironmentModel?> getActiveEnvironment() async {
    return _environmentService.getActiveEnvironment();
  }

  @override
  String resolveTemplate(String input, EnvironmentModel? environment) {
    return _environmentService.resolveTemplate(input, environment);
  }
}
