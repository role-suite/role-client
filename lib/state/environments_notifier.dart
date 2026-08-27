import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/environment.dart';
import '../core/models/environment_variable.dart';
import '../core/models/outbox_entry.dart';
import '../core/models/workspace_origin.dart';
import '../core/remote/api_client.dart';
import '../core/remote/remote_validation.dart';
import '../core/remote/sync/outbox_flusher.dart';
import '../core/remote/sync/outbox_store.dart';
import '../core/remote/sync/workspace_push_service.dart';
import '../core/storage/json_store.dart';
import '../core/storage/workspace_paths.dart';
import '../core/utils/id.dart';
import '../core/utils/logger.dart';
import 'auth_notifier.dart';
import 'settings_providers.dart';

class EnvironmentsNotifier extends AsyncNotifier<List<Environment>> {
  @override
  Future<List<Environment>> build() async {
    // See WorkspaceNotifier.build() / §7 of docs/08-ONLINE-MODE-INTEGRATION.md
    // — null (and this whole branch a no-op) for every local-only user.
    final remoteWorkspaceId = ref.watch(activeRemoteWorkspaceIdProvider);

    final raw = [
      ...await JsonStore.instance.readAll(WorkspacePaths.environments),
      if (remoteWorkspaceId != null) ...await JsonStore.instance.readAll(WorkspacePaths.remoteEnvironments(remoteWorkspaceId)),
    ];
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

  Future<Environment> create({required String name, List<EnvironmentVariable> variables = const []}) async {
    final remoteWorkspaceId = ref.read(activeRemoteWorkspaceIdProvider);
    if (remoteWorkspaceId != null) {
      validateRemoteEnvironmentInput(name: name, variables: variables);
      final client = ref.read(remoteApiClientProvider);
      if (client == null) throw StateError('No remote base URL configured; online mode is unavailable.');
      final service = WorkspacePushService(client);
      final created = await service.createEnvironment(remoteWorkspaceId, name: name);
      final remoteVariables = <EnvironmentVariable>[];
      for (final variable in variables) {
        remoteVariables.add(await service.createEnvironmentVariable(remoteWorkspaceId, created.remoteId!, variable));
      }
      final env = created.copyWith(variables: remoteVariables);
      await JsonStore.instance.write(WorkspacePaths.remoteEnvironmentFile(remoteWorkspaceId, env.id), env.toJson());
      state = AsyncData([...state.value ?? const [], env]);
      return env;
    }

    final now = DateTime.now();
    final env = Environment(id: generateId('env'), name: name, variables: variables, createdAt: now, updatedAt: now);
    await JsonStore.instance.write(WorkspacePaths.environmentFile(env.id), env.toJson());
    state = AsyncData([...state.value ?? const [], env]);
    return env;
  }

  /// Enqueues [entry] and makes a best-effort immediate push attempt (§5:
  /// "enqueue → send now"), leaving it queued for `SyncNotifier`'s poll loop
  /// to retry on failure.
  Future<void> _pushRemoteEdit(OutboxEntry entry) async {
    await OutboxStore.enqueue(entry.workspaceId, entry);
    final client = ref.read(remoteApiClientProvider);
    if (client == null) return;
    await flushOutboxEntry(WorkspacePushService(client), entry);
  }

  Future<void> updateEnvironment(Environment updated) async {
    // Remote-origin environments write to their workspace's cache subtree
    // instead of the local `environments/` directory — never mixed, per §7.
    if (updated.origin == WorkspaceOrigin.remote) {
      validateRemoteEnvironment(updated);
      await JsonStore.instance.write(WorkspacePaths.remoteEnvironmentFile(updated.remoteWorkspaceId!, updated.id), updated.toJson());
    } else {
      await JsonStore.instance.write(WorkspacePaths.environmentFile(updated.id), updated.toJson());
    }
    final envs = (state.value ?? const []).map((e) => e.id == updated.id ? updated : e).toList();
    state = AsyncData(envs);

    if (updated.origin == WorkspaceOrigin.remote) {
      await _pushRemoteEdit(
        OutboxEntry(
          kind: OutboxKind.environment,
          operation: OutboxOperation.upsert,
          workspaceId: updated.remoteWorkspaceId!,
          localId: updated.id,
          enqueuedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> delete(String id) async {
    final environment = (state.value ?? const []).firstWhere((e) => e.id == id);

    if (environment.origin == WorkspaceOrigin.remote) {
      await JsonStore.instance.delete(WorkspacePaths.remoteEnvironmentFile(environment.remoteWorkspaceId!, id));
    } else {
      await JsonStore.instance.delete(WorkspacePaths.environmentFile(id));
    }
    state = AsyncData((state.value ?? const []).where((e) => e.id != id).toList());
    final activeNotifier = ref.read(activeEnvironmentIdProvider.notifier);
    if (ref.read(activeEnvironmentIdProvider) == id) {
      await activeNotifier.setActiveEnvironment(null);
    }

    if (environment.origin == WorkspaceOrigin.remote) {
      await _pushRemoteEdit(
        OutboxEntry(
          kind: OutboxKind.environment,
          operation: OutboxOperation.delete,
          workspaceId: environment.remoteWorkspaceId!,
          localId: id,
          deletedRemoteId: environment.remoteId,
          enqueuedAt: DateTime.now(),
        ),
      );
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

/// The active environment's resolved (enabled-only) variable map, or empty
/// if none is active.
final activeVariablesProvider = Provider<Map<String, String>>((ref) {
  final activeId = ref.watch(activeEnvironmentIdProvider);
  final envs = ref.watch(environmentsProvider).value ?? const [];
  if (activeId == null) return const {};
  for (final env in envs) {
    if (env.id == activeId) return EnvironmentVariable.enabledMap(env.variables);
  }
  return const {};
});
