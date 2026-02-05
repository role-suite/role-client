import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/models/workspace_bundle.dart';
import 'package:relay/core/services/environment_service.dart';
import 'package:relay/core/services/workspace_api/workspace_api_client.dart';
import 'package:relay/features/home/domain/repositories/environment_repository.dart';

/// Environment repository that reads/writes environments via the workspace API (REST or Serverpod RPC).
/// Active environment state is kept in EnvironmentService (local preference).
class EnvironmentRepositoryRemoteImpl implements EnvironmentRepository {
  EnvironmentRepositoryRemoteImpl(this._client, this._environmentService);

  final WorkspaceApiClient _client;
  final EnvironmentService _environmentService;

  @override
  Future<List<EnvironmentModel>> getAllEnvironments() async {
    final bundle = await _client.getWorkspace();
    return List.from(bundle.environments);
  }

  @override
  Future<EnvironmentModel?> getEnvironmentByName(String name) async {
    final list = await getAllEnvironments();
    try {
      return list.firstWhere((e) => e.name == name);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveEnvironment(EnvironmentModel environment) async {
    final bundle = await _client.getWorkspace();
    final newEnvs = <EnvironmentModel>[];
    var found = false;
    for (final e in bundle.environments) {
      if (e.name == environment.name) {
        newEnvs.add(environment);
        found = true;
      } else {
        newEnvs.add(e);
      }
    }
    if (!found) {
      newEnvs.add(environment);
    }
    final newBundle = WorkspaceBundle(
      version: bundle.version,
      exportedAt: bundle.exportedAt,
      source: bundle.source,
      collections: bundle.collections,
      environments: newEnvs,
    );
    await _client.putWorkspace(newBundle);
  }

  @override
  Future<void> deleteEnvironment(String name) async {
    final bundle = await _client.getWorkspace();
    final newEnvs = bundle.environments.where((e) => e.name != name).toList();
    final newBundle = WorkspaceBundle(
      version: bundle.version,
      exportedAt: bundle.exportedAt,
      source: bundle.source,
      collections: bundle.collections,
      environments: newEnvs,
    );
    await _client.putWorkspace(newBundle);
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
