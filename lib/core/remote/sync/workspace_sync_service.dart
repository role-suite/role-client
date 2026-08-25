import '../../models/environment.dart';
import '../../models/environment_variable.dart';
import '../../models/workspace_bundle.dart';
import '../api_client.dart';
import 'remote_mappers.dart';

/// One page of `GET /workspaces/:id/updates`. `items` carry
/// `{entity, action, entityId, payload}` — payloads are partial (a change
/// signal, not a snapshot), so this phase only reads `entity` off each item
/// to decide which full list to refetch (§5 of
/// docs/08-ONLINE-MODE-INTEGRATION.md; verified against
/// `role-node/src/modules/collections/service.ts` and `environments/service.ts`,
/// whose event payloads never carry the full row).
class SyncPage {
  const SyncPage({required this.entities, required this.nextCursor, required this.hasMore});

  final Set<String> entities;
  final int nextCursor;
  final bool hasMore;
}

/// Talks to role-node's collections/environments/updates routes for one
/// workspace. Separate from [RemoteApiClient] (which is transport-only) so
/// the entity-shape knowledge lives in one place — see `remote_mappers.dart`
/// for the wire-to-local translation.
class WorkspaceSyncService {
  const WorkspaceSyncService(this._client);

  final RemoteApiClient _client;

  Future<SyncPage> fetchUpdates(int workspaceId, {required int since, int limit = 50}) async {
    final data = Map<String, dynamic>.from(
      await _client.get('/workspaces/$workspaceId/updates', queryParameters: {'since': since, 'limit': limit}) as Map,
    );
    final items = (data['items'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e));
    final cursor = Map<String, dynamic>.from(data['cursor'] as Map? ?? const {});
    return SyncPage(
      entities: items.map((e) => e['entity'] as String? ?? '').where((e) => e.isNotEmpty).toSet(),
      nextCursor: cursor['next'] as int? ?? since,
      hasMore: cursor['hasMore'] as bool? ?? false,
    );
  }

  /// Fetches every collection in the workspace, plus each collection's
  /// endpoints, per role-node's client-integration guide: these list routes
  /// are unbounded and unpaginated, so "fetch once and cache client-side" is
  /// the recommended pattern rather than anything incremental.
  Future<List<CollectionBundle>> fetchCollections(int workspaceId) async {
    final data = Map<String, dynamic>.from(await _client.get('/workspaces/$workspaceId/collections') as Map);
    final rawCollections = (data['items'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e));

    final bundles = <CollectionBundle>[];
    for (final rawCollection in rawCollections) {
      final collection = collectionFromRemote(rawCollection, workspaceId: workspaceId);
      final remoteCollectionId = rawCollection['id'] as int;
      final endpointsData = Map<String, dynamic>.from(await _client.get('/workspaces/$workspaceId/collections/$remoteCollectionId/endpoints') as Map);
      final requests = (endpointsData['items'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => apiRequestFromRemoteEndpoint(Map<String, dynamic>.from(e), workspaceId: workspaceId, collectionId: collection.id))
          .toList();
      bundles.add(CollectionBundle(collection: collection, requests: requests));
    }
    return bundles;
  }

  /// Fetches every environment in the workspace, plus each environment's
  /// variables — same "fetch the whole unpaginated list" pattern as above.
  Future<List<Environment>> fetchEnvironments(int workspaceId) async {
    final data = Map<String, dynamic>.from(await _client.get('/workspaces/$workspaceId/environments') as Map);
    final rawEnvironments = (data['items'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e));

    final environments = <Environment>[];
    for (final rawEnvironment in rawEnvironments) {
      final remoteEnvironmentId = rawEnvironment['id'] as int;
      final variablesData = Map<String, dynamic>.from(
        await _client.get('/workspaces/$workspaceId/environments/$remoteEnvironmentId/variables') as Map,
      );
      final variables = (variablesData['items'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => environmentVariableFromRemote(Map<String, dynamic>.from(e)))
          .toList()
          .cast<EnvironmentVariable>();
      environments.add(environmentFromRemote(rawEnvironment, workspaceId: workspaceId, variables: variables));
    }
    return environments;
  }
}
