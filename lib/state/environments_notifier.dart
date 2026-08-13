import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/environment.dart';
import '../core/storage/json_store.dart';
import '../core/storage/workspace_paths.dart';
import '../core/utils/id.dart';
import '../core/utils/logger.dart';
import 'settings_providers.dart';

class EnvironmentsNotifier extends AsyncNotifier<List<Environment>> {
  @override
  Future<List<Environment>> build() async {
    final raw = await JsonStore.instance.readAll(WorkspacePaths.environments);
    final envs = <Environment>[];
    for (final entry in raw) {
      try {
        envs.add(Environment.fromJson(entry));
      } catch (error) {
        Log.d('Skipping unparseable environment entry: $error');
      }
    }
    envs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return envs;
  }

  Future<Environment> create({required String name, Map<String, String> variables = const {}}) async {
    final now = DateTime.now();
    final env = Environment(id: generateId('env'), name: name, variables: variables, createdAt: now, updatedAt: now);
    await JsonStore.instance.write(WorkspacePaths.environmentFile(env.id), env.toJson());
    state = AsyncData([...state.value ?? const [], env]);
    return env;
  }

  Future<void> updateEnvironment(Environment updated) async {
    await JsonStore.instance.write(WorkspacePaths.environmentFile(updated.id), updated.toJson());
    final envs = (state.value ?? const []).map((e) => e.id == updated.id ? updated : e).toList();
    state = AsyncData(envs);
  }

  Future<void> delete(String id) async {
    await JsonStore.instance.delete(WorkspacePaths.environmentFile(id));
    state = AsyncData((state.value ?? const []).where((e) => e.id != id).toList());
    final activeNotifier = ref.read(activeEnvironmentIdProvider.notifier);
    if (ref.read(activeEnvironmentIdProvider) == id) {
      await activeNotifier.setActiveEnvironment(null);
    }
  }

  /// Imports environments, e.g. from a workspace/Postman bundle.
  /// [resolveId] decides the final id: return an existing environment's id to
  /// overwrite it, a new id to keep both, or null to skip it entirely.
  Future<void> importAll(List<Environment> incoming, {String? Function(Environment incoming, bool nameTaken)? resolveId}) async {
    List<Environment> envs = [...state.value ?? const []];
    for (final env in incoming) {
      final nameTaken = envs.any((e) => e.name == env.name);
      final targetId = resolveId?.call(env, nameTaken) ?? generateId('env');
      final imported = Environment(id: targetId, name: env.name, variables: env.variables, createdAt: env.createdAt, updatedAt: DateTime.now());
      await JsonStore.instance.write(WorkspacePaths.environmentFile(targetId), imported.toJson());
      envs = [...envs.where((e) => e.id != targetId), imported];
    }
    state = AsyncData(envs);
  }
}

final environmentsProvider = AsyncNotifierProvider<EnvironmentsNotifier, List<Environment>>(EnvironmentsNotifier.new);

/// The active environment's resolved variable map, or empty if none is active.
final activeVariablesProvider = Provider<Map<String, String>>((ref) {
  final activeId = ref.watch(activeEnvironmentIdProvider);
  final envs = ref.watch(environmentsProvider).value ?? const [];
  if (activeId == null) return const {};
  for (final env in envs) {
    if (env.id == activeId) return env.variables;
  }
  return const {};
});
