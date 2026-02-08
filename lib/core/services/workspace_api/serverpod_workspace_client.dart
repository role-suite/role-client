import 'package:relay/core/models/workspace_bundle.dart' as app_models;
import 'package:relay/core/utils/logger.dart';
import 'package:relay/core/services/workspace_api/workspace_api_client.dart';
import 'package:relay_server_client/relay_server_client.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

/// Serverpod RPC implementation: uses generated client's workspace endpoint.
/// role_server exposes pullWorkspace() → WorkspaceBundle? and pushWorkspace(WorkspaceBundle).
class ServerpodWorkspaceClient implements WorkspaceApiClient {
  ServerpodWorkspaceClient({required String serverUrl}) {
    final url = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    _serverUrl = url.isEmpty ? '' : url;
    _client = Client(_serverUrl)
      ..connectivityMonitor = FlutterConnectivityMonitor();
  }

  late final String _serverUrl;
  late final Client _client;

  @override
  Future<app_models.WorkspaceBundle> getWorkspace() async {
    if (_serverUrl.isEmpty) {
      throw ArgumentError('Serverpod server URL is not set');
    }
    try {
      AppLogger.debug('Serverpod RPC: pullWorkspace');
      final result = await _client.workspace.pullWorkspace();
      if (result == null) {
        return app_models.WorkspaceBundle(
          version: app_models.WorkspaceBundle.currentVersion,
          exportedAt: DateTime.now(),
          collections: const [],
          environments: const [],
        );
      }
      return _serverBundleToApp(result);
    } catch (e, st) {
      AppLogger.error('ServerpodWorkspaceClient.getWorkspace failed: $e');
      AppLogger.error('  $st');
      rethrow;
    }
  }

  @override
  Future<void> putWorkspace(app_models.WorkspaceBundle bundle) async {
    if (_serverUrl.isEmpty) {
      throw ArgumentError('Serverpod server URL is not set');
    }
    try {
      AppLogger.debug('Serverpod RPC: pushWorkspace');
      final serverBundle = _appBundleToServer(bundle);
      await _client.workspace.pushWorkspace(serverBundle);
    } catch (e, st) {
      AppLogger.error('ServerpodWorkspaceClient.putWorkspace failed: $e');
      AppLogger.error('  $st');
      rethrow;
    }
  }

  /// Converts server [WorkspaceBundle] to app [WorkspaceBundle].
  static app_models.WorkspaceBundle _serverBundleToApp(WorkspaceBundle server) {
    final collectionsJson = server.collections
        .map((c) => <String, dynamic>{
              'collection': c.collection.toJson(),
              'requests': c.requests.map((r) => r.toJson()).toList(),
            })
        .toList();
    final environmentsJson =
        server.environments.map((e) => e.toJson()).toList();
    return app_models.WorkspaceBundle.fromJson({
      'version': server.version,
      'exportedAt': server.exportedAt.toIso8601String(),
      'source': server.source,
      'collections': collectionsJson,
      'environments': environmentsJson,
    });
  }

  /// Converts app [WorkspaceBundle] to server [WorkspaceBundle] (Serverpod serialization format).
  static WorkspaceBundle _appBundleToServer(app_models.WorkspaceBundle app) {
    final appJson = app.toJson();
    final serverMap = <String, dynamic>{
      '__className__': 'WorkspaceBundle',
      'version': appJson['version'],
      'exportedAt': appJson['exportedAt'],
      'source': appJson['source'],
      'collections': _appCollectionsToServerFormat(
        appJson['collections'] as List<dynamic>? ?? [],
      ),
      'environments': _appEnvironmentsToServerFormat(
        appJson['environments'] as List<dynamic>? ?? [],
      ),
    };
    return WorkspaceBundle.fromJson(serverMap);
  }

  static List<Map<String, dynamic>> _appCollectionsToServerFormat(
    List<dynamic> list,
  ) {
    return list
        .whereType<Map<String, dynamic>>()
        .map((m) {
          final collection = m['collection'] as Map<String, dynamic>? ?? {};
          final requests = m['requests'] as List<dynamic>? ?? [];
          return <String, dynamic>{
            '__className__': 'CollectionBundle',
            'collection': _withClassName(collection, 'CollectionModel'),
            'requests': requests
                .whereType<Map<String, dynamic>>()
                .map((r) => _withClassName(r, 'ApiRequestModel'))
                .toList(),
          };
        })
        .toList();
  }

  static List<Map<String, dynamic>> _appEnvironmentsToServerFormat(
    List<dynamic> list,
  ) {
    return list
        .whereType<Map<String, dynamic>>()
        .map((m) => _withClassName(Map<String, dynamic>.from(m), 'EnvironmentModel'))
        .toList();
  }

  static Map<String, dynamic> _withClassName(
    Map<String, dynamic> map,
    String className,
  ) {
    return Map<String, dynamic>.from(map)..['__className__'] = className;
  }
}
