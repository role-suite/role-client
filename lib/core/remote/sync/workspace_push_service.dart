import '../../models/api_request.dart';
import '../../models/collection.dart';
import '../../models/environment.dart';
import '../../models/environment_variable.dart';
import '../api_client.dart';
import 'remote_mappers.dart';

/// Pushes local edits to already-synced (i.e. already carrying a `remoteId`)
/// remote-origin entities upstream — the write side of §5 of
/// docs/08-ONLINE-MODE-INTEGRATION.md. Mirrors [WorkspaceSyncService]'s
/// shape/scope: creating a brand-new entity inside a remote workspace is out
/// of scope for this phase (see the phase-4 plan's scope note), so every
/// method here targets a row that already exists server-side.
class WorkspacePushService {
  const WorkspacePushService(this._client);

  final RemoteApiClient _client;

  Future<Collection> createCollection(int workspaceId, {required String name, String description = ''}) async {
    final data = Map<String, dynamic>.from(
      await _client.post('/workspaces/$workspaceId/collections', data: {'name': name, if (description.isNotEmpty) 'description': description}) as Map,
    );
    return collectionFromRemote(data, workspaceId: workspaceId);
  }

  Future<ApiRequest> createEndpoint(int workspaceId, int remoteCollectionId, {required String collectionLocalId, required ApiRequest request}) async {
    final data = Map<String, dynamic>.from(
      await _client.post(
            '/workspaces/$workspaceId/collections/$remoteCollectionId/endpoints',
            data: {
              'name': request.name,
              'method': request.method.name.toUpperCase(),
              // role-node requires a non-empty URL even for a draft endpoint.
              'url': request.url.isEmpty ? '/' : request.url,
              'headers': request.headers.map((e) => e.toJson()).toList(),
              'queryParams': request.queryParams.map((e) => e.toJson()).toList(),
              'body': requestBodyToWire(request.requestBody),
              'auth': authToWire(request.authType, request.authConfig),
            },
          )
          as Map,
    );
    return apiRequestFromRemoteEndpoint(data, workspaceId: workspaceId, collectionId: collectionLocalId);
  }

  Future<Environment> createEnvironment(int workspaceId, {required String name}) async {
    final data = Map<String, dynamic>.from(await _client.post('/workspaces/$workspaceId/environments', data: {'name': name}) as Map);
    return environmentFromRemote(data, workspaceId: workspaceId);
  }

  Future<EnvironmentVariable> createEnvironmentVariable(int workspaceId, int remoteEnvironmentId, EnvironmentVariable variable) async {
    final data = Map<String, dynamic>.from(
      await _client.post(
            '/workspaces/$workspaceId/environments/$remoteEnvironmentId/variables',
            data: {
              'key': variable.key,
              'value': variable.value,
              'enabled': variable.enabled,
              'isSecret': variable.isSecret,
              'position': variable.position,
            },
          )
          as Map,
    );
    return environmentVariableFromRemote(data);
  }

  Future<void> updateCollection(int workspaceId, int remoteId, Collection collection) {
    return _client.patch('/workspaces/$workspaceId/collections/$remoteId', data: {'name': collection.name, 'description': collection.description});
  }

  Future<void> deleteCollection(int workspaceId, int remoteId) {
    return _client.delete('/workspaces/$workspaceId/collections/$remoteId');
  }

  Future<void> updateEndpoint(int workspaceId, int remoteCollectionId, int remoteId, ApiRequest request) {
    return _client.patch(
      '/workspaces/$workspaceId/collections/$remoteCollectionId/endpoints/$remoteId',
      data: {
        'name': request.name,
        'method': request.method.name.toUpperCase(),
        'url': request.url,
        'headers': request.headers.map((e) => e.toJson()).toList(),
        'queryParams': request.queryParams.map((e) => e.toJson()).toList(),
        'body': requestBodyToWire(request.requestBody),
        'auth': authToWire(request.authType, request.authConfig),
      },
    );
  }

  Future<void> deleteEndpoint(int workspaceId, int remoteCollectionId, int remoteId) {
    return _client.delete('/workspaces/$workspaceId/collections/$remoteCollectionId/endpoints/$remoteId');
  }

  Future<void> updateEnvironment(int workspaceId, int remoteId, Environment environment) {
    return _client.patch('/workspaces/$workspaceId/environments/$remoteId', data: {'name': environment.name});
  }

  Future<void> deleteEnvironment(int workspaceId, int remoteId) {
    return _client.delete('/workspaces/$workspaceId/environments/$remoteId');
  }

  /// Reconciles an environment's variable rows against [desired]: a row
  /// carrying a [EnvironmentVariable.remoteId] is matched (and updated
  /// in-place, even across a key rename) by that id; a row with no
  /// `remoteId` (never synced — added in the editor) falls back to matching
  /// by `key` (role-node's uniqueness boundary —
  /// `environment_variables.key_name` is unique per environment). Anything
  /// remaining unmatched by either is created; any existing remote row
  /// matched by nothing is deleted.
  Future<void> reconcileVariables(int workspaceId, int remoteEnvironmentId, List<EnvironmentVariable> desired) async {
    final path = '/workspaces/$workspaceId/environments/$remoteEnvironmentId/variables';
    final data = Map<String, dynamic>.from(await _client.get(path) as Map);
    final existing = (data['items'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final existingById = {for (final row in existing) row['id'] as int: row};
    final existingByKey = {for (final row in existing) row['key'] as String: row};

    final matchedIds = <int>{};
    for (final variable in desired) {
      final variablePayload = {
        'key': variable.key,
        'value': variable.value,
        'enabled': variable.enabled,
        'isSecret': variable.isSecret,
        'position': variable.position,
      };
      final match = variable.remoteId != null ? existingById[variable.remoteId] : existingByKey[variable.key];
      if (match == null) {
        await _client.post(path, data: variablePayload);
      } else {
        matchedIds.add(match['id'] as int);
        await _client.patch('$path/${match['id']}', data: variablePayload);
      }
    }

    for (final row in existing) {
      if (!matchedIds.contains(row['id'] as int)) {
        await _client.delete('$path/${row['id']}');
      }
    }
  }
}
