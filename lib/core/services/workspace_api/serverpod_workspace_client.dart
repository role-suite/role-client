import 'dart:convert';

import 'package:relay/core/models/workspace_bundle.dart' as app_models;
import 'package:relay/core/utils/logger.dart';
import 'package:relay/core/services/workspace_api/workspace_api_client.dart';
import 'package:relay_server_client/relay_server_client.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

/// Serverpod RPC implementation: uses generated client's workspace endpoint.
/// Expects getWorkspace() → String (JSON) and saveWorkspace(String) → void.
/// Uses dynamic for endpoint calls so generated method names can vary.
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
      AppLogger.debug('Serverpod RPC: getWorkspace');
      final result = await (_client.workspace as dynamic).getWorkspace();
      final jsonString = result is String ? result : jsonEncode(result);
      if (jsonString.isEmpty) {
        throw const FormatException('Empty workspace response from Serverpod');
      }
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      return app_models.WorkspaceBundle.fromJson(data);
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
      AppLogger.debug('Serverpod RPC: saveWorkspace');
      final jsonString = jsonEncode(bundle.toJson());
      await (_client.workspace as dynamic).saveWorkspace(jsonString);
    } catch (e, st) {
      AppLogger.error('ServerpodWorkspaceClient.putWorkspace failed: $e');
      AppLogger.error('  $st');
      rethrow;
    }
  }
}
