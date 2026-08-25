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
