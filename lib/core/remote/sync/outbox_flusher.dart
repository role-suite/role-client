import '../../models/environment.dart';
import '../../models/outbox_entry.dart';
import '../../models/workspace_bundle.dart';
import '../../storage/json_store.dart';
import '../../storage/workspace_paths.dart';
import '../../utils/iterable_ext.dart';
import '../../utils/logger.dart';
import '../remote_api_exception.dart';
import 'outbox_store.dart';
import 'workspace_push_service.dart';

/// Error codes role-node returns for a write that cannot succeed no matter
/// how many times it's retried (permission denied, the row is gone, a unique
/// constraint conflict) — checked against
/// `role-node/src/shared/errors/error-codes.ts`. Dropping the outbox entry
/// on one of these is a deliberate v1 simplicity choice (§5/§11): the next
/// successful pull silently reconciles local state back to server truth
/// rather than surfacing a merge UI.
const _permanentErrorCodes = {
  'VALIDATION_FAILED',
  'COLLECTIONS_MODIFY_FORBIDDEN',
  'ENVIRONMENTS_MODIFY_FORBIDDEN',
  'COLLECTION_NOT_FOUND',
  'COLLECTION_ENDPOINT_NOT_FOUND',
  'ENVIRONMENT_NOT_FOUND',
  'ENVIRONMENT_VARIABLE_NOT_FOUND',
  'ENVIRONMENT_NAME_ALREADY_EXISTS',
  'ENVIRONMENT_VARIABLE_KEY_ALREADY_EXISTS',
  'WORKSPACE_ACCESS_DENIED',
  'WORKSPACE_NOT_FOUND',
};

/// Attempts one outbox entry. Always re-reads the current local remote-cache
/// file for an `upsert` (so a queued entry never sends a stale snapshot —
/// it sends whatever the user's latest edit left on disk), removes the entry
/// from the outbox on success or permanent failure, and leaves it queued
/// (returns false) on a retryable failure (network/rate-limit).
Future<bool> flushOutboxEntry(WorkspacePushService push, OutboxEntry entry) async {
  try {
    switch (entry.operation) {
      case OutboxOperation.upsert:
        await _pushUpsert(push, entry);
      case OutboxOperation.delete:
        await _pushDelete(push, entry);
    }
    await OutboxStore.remove(entry.workspaceId, entry.key);
    return true;
  } on RemoteApiException catch (error) {
    if (_permanentErrorCodes.contains(error.code)) {
      Log.e('Dropping unrecoverable outbox entry ${entry.key}: ${error.code}');
      await OutboxStore.remove(entry.workspaceId, entry.key);
      return true;
    }
    return false;
  }
}

Future<void> flushOutbox(WorkspacePushService push, int workspaceId) async {
  for (final entry in await OutboxStore.load(workspaceId)) {
    await flushOutboxEntry(push, entry);
  }
}

Future<void> _pushUpsert(WorkspacePushService push, OutboxEntry entry) async {
  switch (entry.kind) {
    case OutboxKind.collection:
      final bundle = await _readCollectionBundle(entry.workspaceId, entry.localId);
      if (bundle == null) return; // already gone locally — nothing to push
      await push.updateCollection(entry.workspaceId, bundle.collection.remoteId!, bundle.collection);
    case OutboxKind.request:
      final collectionLocalId = entry.collectionLocalId;
      if (collectionLocalId == null) return;
      final bundle = await _readCollectionBundle(entry.workspaceId, collectionLocalId);
      if (bundle == null) return;
      final request = bundle.requests.where((r) => r.id == entry.localId).firstOrNull;
      if (request == null) return; // already gone locally — nothing to push
      await push.updateEndpoint(entry.workspaceId, bundle.collection.remoteId!, request.remoteId!, request);
    case OutboxKind.environment:
      final environment = await _readEnvironment(entry.workspaceId, entry.localId);
      if (environment == null) return;
      await push.updateEnvironment(entry.workspaceId, environment.remoteId!, environment);
      await push.reconcileVariables(entry.workspaceId, environment.remoteId!, environment.variables);
  }
}

Future<void> _pushDelete(WorkspacePushService push, OutboxEntry entry) async {
  switch (entry.kind) {
    case OutboxKind.collection:
      await push.deleteCollection(entry.workspaceId, entry.deletedRemoteId!);
    case OutboxKind.request:
      await push.deleteEndpoint(entry.workspaceId, entry.deletedParentRemoteId!, entry.deletedRemoteId!);
    case OutboxKind.environment:
      await push.deleteEnvironment(entry.workspaceId, entry.deletedRemoteId!);
  }
}

Future<CollectionBundle?> _readCollectionBundle(int workspaceId, String localId) async {
  final json = await JsonStore.instance.read(WorkspacePaths.remoteCollectionFile(workspaceId, localId));
  return json == null ? null : CollectionBundle.fromJson(json);
}

Future<Environment?> _readEnvironment(int workspaceId, String localId) async {
  final json = await JsonStore.instance.read(WorkspacePaths.remoteEnvironmentFile(workspaceId, localId));
  return json == null ? null : Environment.fromJson(json);
}
