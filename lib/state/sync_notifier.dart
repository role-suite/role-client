import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/sync_cursor.dart';
import '../core/remote/api_client.dart';
import '../core/remote/auth/auth_state.dart';
import '../core/remote/remote_api_exception.dart';
import '../core/remote/sync/outbox_flusher.dart';
import '../core/remote/sync/workspace_push_service.dart';
import '../core/remote/sync/workspace_sync_service.dart';
import '../core/storage/json_store.dart';
import '../core/storage/workspace_paths.dart';
import '../core/utils/logger.dart';
import 'auth_notifier.dart';
import 'environments_notifier.dart';
import 'workspace_notifier.dart';

/// `idle | syncing | synced(lastSyncedAt) | offline(lastSyncedAt?) |
/// error(message)` per §5/§11 of docs/08-ONLINE-MODE-INTEGRATION.md.
sealed class SyncState {
  const SyncState();
}

class SyncIdle extends SyncState {
  const SyncIdle();
}

class SyncSyncing extends SyncState {
  const SyncSyncing();
}

class SyncSynced extends SyncState {
  const SyncSynced(this.lastSyncedAt);
  final DateTime lastSyncedAt;
}

class SyncOffline extends SyncState {
  const SyncOffline(this.lastSyncedAt);
  final DateTime? lastSyncedAt;
}

class SyncError extends SyncState {
  const SyncError(this.message);
  final String message;
}

/// Baseline poll interval while a remote workspace is active — within the
/// 5-10s range the doc suggests. Overridable in tests so the loop doesn't
/// have to wait on a real `Duration` between ticks.
final syncPollIntervalProvider = Provider<Duration>((ref) => const Duration(seconds: 7));

/// Whether `build()` should spawn its own continuous background poll loop.
/// Always true in production; tests override this to false and drive
/// individual ticks deterministically via [SyncNotifier.debugBootstrap] /
/// [SyncNotifier.debugTick] instead of racing a real background loop.
final syncAutoStartProvider = Provider<bool>((ref) => true);

const _collectionEntities = {'collection', 'collection_endpoint'};
const _environmentEntities = {'environment', 'environment_variable'};

/// A completed import (§8) publishes this entity so other clients see its
/// new collections/environments via the normal pull — the event alone
/// doesn't say which of the two it touched, so both families are refetched
/// unconditionally whenever it appears.
const _importExportEntities = {'import_export_job'};

class _TickResult {
  const _TickResult(this.cursor, this.wait, this.stop);
  final SyncCursor cursor;
  final Duration wait;
  final bool stop;
}

/// Polls role-node's `GET /workspaces/:id/updates` cursor feed for the one
/// workspace the current token pair is scoped to and caches its data under
/// `workspace/remote/<id>/...` for `WorkspaceNotifier`/`EnvironmentsNotifier`
/// to merge in read-only (§7). role-node scopes one token pair to exactly one
/// workspace at a time (§4), so — unlike the doc's "one instance per active
/// remote workspace" phrasing, written with multiple simultaneously-open
/// workspaces in mind — a single (non-family) notifier tracking "the
/// currently active workspace's sync state" is the right-sized
/// implementation: there is never more than one to track.
class SyncNotifier extends Notifier<SyncState> {
  int _generation = 0;
  DateTime? _lastSyncedAt;
  int? _activeWorkspaceId;

  @override
  SyncState build() {
    final auth = ref.watch(authNotifierProvider);
    _generation++;
    final generation = _generation;
    final previousWorkspaceId = _activeWorkspaceId;

    if (auth is! AuthSignedIn) {
      // Signed out (or never signed in): a stale cache from a previously
      // active workspace is a pure local cleanup, no risk to local data —
      // see clearCache()/§7. AuthNotifier never has to know SyncNotifier
      // exists for this — it just reacts to the state it already watches.
      if (previousWorkspaceId != null) {
        _activeWorkspaceId = null;
        Future.microtask(() => clearCache(previousWorkspaceId));
      }
      return const SyncIdle();
    }

    _activeWorkspaceId = auth.activeWorkspaceId;
    if (ref.read(syncAutoStartProvider)) {
      Future.microtask(() => _run(auth.activeWorkspaceId, generation));
    }
    return const SyncSyncing();
  }

  bool _stale(int generation) => generation != _generation;

  Future<void> _run(int workspaceId, int generation) async {
    final client = ref.read(remoteApiClientProvider);
    if (client == null || _stale(generation)) return;
    final service = WorkspaceSyncService(client);
    final push = WorkspacePushService(client);

    final bootstrapped = await _bootstrapIfNeeded(workspaceId, service, generation);
    if (bootstrapped == null || _stale(generation)) return;
    var cursor = bootstrapped;

    while (!_stale(generation)) {
      final result = await _tick(workspaceId, service, push, cursor, generation);
      cursor = result.cursor;
      if (result.stop || _stale(generation)) return;
      if (result.wait > Duration.zero) await Future.delayed(result.wait);
    }
  }

  /// Loads the persisted cursor, or — on first activation for this workspace
  /// — fetches full collections+environments once (rather than waiting for
  /// the user's own historical events to replay one by one) and seeds the
  /// cursor from that same call's `next`.
  Future<SyncCursor?> _bootstrapIfNeeded(int workspaceId, WorkspaceSyncService service, int generation) async {
    final cursorJson = await JsonStore.instance.read(WorkspacePaths.syncCursorFile(workspaceId));
    if (_stale(generation)) return null;
    if (cursorJson != null) return SyncCursor.fromJson(cursorJson);

    try {
      await _fetchAndCacheAll(workspaceId, service, generation);
      if (_stale(generation)) return null;
      final page = await service.fetchUpdates(workspaceId, since: 0);
      final cursor = SyncCursor(workspaceId: workspaceId, since: page.nextCursor);
      await JsonStore.instance.write(WorkspacePaths.syncCursorFile(workspaceId), cursor.toJson());
      _markSynced(generation);
      return cursor;
    } on RemoteApiException catch (error) {
      _handleError(error, generation);
      return null;
    }
  }

  /// One poll-and-apply cycle: flush any pending local pushes (§5 — offline
  /// edits retry on the same cadence as pulls), `GET /updates`, refetch+cache
  /// whichever entity families changed, then persist the advanced cursor.
  /// Split out from the loop so tests can drive it deterministically instead
  /// of racing a real background loop — see [debugBootstrap]/[debugTick].
  Future<_TickResult> _tick(int workspaceId, WorkspaceSyncService service, WorkspacePushService push, SyncCursor cursor, int generation) async {
    final baseWait = ref.read(syncPollIntervalProvider);
    await flushOutbox(push, workspaceId);
    if (_stale(generation)) return _TickResult(cursor, baseWait, true);
    try {
      final page = await service.fetchUpdates(workspaceId, since: cursor.since);
      if (_stale(generation)) return _TickResult(cursor, baseWait, true);

      if (page.entities.isNotEmpty) {
        await _applyChangedEntities(workspaceId, service, page.entities, generation);
        if (_stale(generation)) return _TickResult(cursor, baseWait, true);
      }

      final next = SyncCursor(workspaceId: workspaceId, since: page.nextCursor);
      await JsonStore.instance.write(WorkspacePaths.syncCursorFile(workspaceId), next.toJson());
      _markSynced(generation);

      return _TickResult(next, page.hasMore ? Duration.zero : baseWait, false);
    } on RemoteApiException catch (error) {
      if (_stale(generation)) return _TickResult(cursor, baseWait, true);
      final stop = _handleError(error, generation);
      final wait = (error.code == 'RATE_LIMIT_EXCEEDED' && error.retryAfterSeconds != null) ? Duration(seconds: error.retryAfterSeconds!) : baseWait;
      return _TickResult(cursor, wait, stop);
    }
  }

  /// Runs the first-activation bootstrap for [workspaceId] without starting
  /// the continuous loop. Test-only entry point (`syncAutoStartProvider`
  /// should be overridden to false alongside this) — production code reaches
  /// the same logic through `build()` -> `_run()`.
  @visibleForTesting
  Future<SyncCursor?> debugBootstrap(int workspaceId) async {
    final client = ref.read(remoteApiClientProvider)!;
    return _bootstrapIfNeeded(workspaceId, WorkspaceSyncService(client), _generation);
  }

  /// Runs exactly one poll-and-apply tick for [workspaceId] starting from
  /// [cursor] and returns the advanced cursor. Test-only — see
  /// [debugBootstrap].
  @visibleForTesting
  Future<SyncCursor> debugTick(int workspaceId, SyncCursor cursor) async {
    final client = ref.read(remoteApiClientProvider)!;
    final result = await _tick(workspaceId, WorkspaceSyncService(client), WorkspacePushService(client), cursor, _generation);
    return result.cursor;
  }

  /// Flushes the outbox for [workspaceId] without running a full tick.
  /// Test-only — production code reaches the same call from inside `_tick`.
  @visibleForTesting
  Future<void> debugFlushOutbox(int workspaceId) async {
    final client = ref.read(remoteApiClientProvider)!;
    await flushOutbox(WorkspacePushService(client), workspaceId);
  }

  Future<void> _applyChangedEntities(int workspaceId, WorkspaceSyncService service, Set<String> entities, int generation) async {
    final touchesImportExport = entities.intersection(_importExportEntities).isNotEmpty;

    if (touchesImportExport || entities.intersection(_collectionEntities).isNotEmpty) {
      await _fetchAndCacheCollections(workspaceId, service);
      if (_stale(generation)) return;
      ref.invalidate(workspaceProvider);
    }
    if (touchesImportExport || entities.intersection(_environmentEntities).isNotEmpty) {
      await _fetchAndCacheEnvironments(workspaceId, service);
      if (_stale(generation)) return;
      ref.invalidate(environmentsProvider);
    }
  }

  Future<void> _fetchAndCacheAll(int workspaceId, WorkspaceSyncService service, int generation) async {
    await _fetchAndCacheCollections(workspaceId, service);
    if (_stale(generation)) return;
    await _fetchAndCacheEnvironments(workspaceId, service);
    if (_stale(generation)) return;
    ref.invalidate(workspaceProvider);
    ref.invalidate(environmentsProvider);
  }

  Future<void> _fetchAndCacheCollections(int workspaceId, WorkspaceSyncService service) async {
    final bundles = await service.fetchCollections(workspaceId);
    final freshIds = bundles.map((b) => b.collection.id).toSet();
    final staleIds = (await JsonStore.instance.listIds(WorkspacePaths.remoteCollections(workspaceId))).difference(freshIds);

    for (final bundle in bundles) {
      await JsonStore.instance.write(WorkspacePaths.remoteCollectionFile(workspaceId, bundle.collection.id), bundle.toJson());
    }
    for (final staleId in staleIds) {
      await JsonStore.instance.delete(WorkspacePaths.remoteCollectionFile(workspaceId, staleId));
    }
  }

  Future<void> _fetchAndCacheEnvironments(int workspaceId, WorkspaceSyncService service) async {
    final environments = await service.fetchEnvironments(workspaceId);
    final freshIds = environments.map((e) => e.id).toSet();
    final staleIds = (await JsonStore.instance.listIds(WorkspacePaths.remoteEnvironments(workspaceId))).difference(freshIds);

    for (final environment in environments) {
      await JsonStore.instance.write(WorkspacePaths.remoteEnvironmentFile(workspaceId, environment.id), environment.toJson());
    }
    for (final staleId in staleIds) {
      await JsonStore.instance.delete(WorkspacePaths.remoteEnvironmentFile(workspaceId, staleId));
    }
  }

  void _markSynced(int generation) {
    if (_stale(generation)) return;
    _lastSyncedAt = DateTime.now();
    state = SyncSynced(_lastSyncedAt!);
  }

  /// Returns true if the poll loop for this workspace should stop entirely
  /// (access revoked / workspace gone) rather than keep retrying.
  bool _handleError(RemoteApiException error, int generation) {
    if (_stale(generation)) return true;
    switch (error.code) {
      case 'NETWORK_ERROR':
        state = SyncOffline(_lastSyncedAt);
        return false;
      case 'WORKSPACE_ACCESS_DENIED':
      case 'WORKSPACE_NOT_FOUND':
        state = SyncError(error.message);
        return true;
      case 'RATE_LIMIT_EXCEEDED':
        // Not an error state — the loop just waits longer before its next tick.
        return false;
      default:
        Log.e('Sync tick failed', error: error);
        state = SyncError(error.message);
        return false;
    }
  }

  /// Deletes a signed-out (or left) workspace's local remote cache. Pure
  /// local operation, no risk to `collections/`/`environments/` (§7). Called
  /// from `AuthNotifier.logout()`.
  Future<void> clearCache(int workspaceId) async {
    await JsonStore.instance.deleteDirectory(WorkspacePaths.remoteRoot(workspaceId));
  }
}

final syncNotifierProvider = NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);
