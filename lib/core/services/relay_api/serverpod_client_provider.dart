import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay_server_client/relay_server_client.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

/// Provides a shared Serverpod [Client] with auth (FlutterAuthSessionManager) when
/// data source is API + Serverpod RPC and baseUrl is set. The client is created
/// once per baseUrl and auth is initialized (restore/validate session).
final serverpodClientProvider = FutureProvider.autoDispose.family<Client?, String>((ref, baseUrl) async {
  if (baseUrl.trim().isEmpty) return null;
  final url = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  if (url.isEmpty) return null;
  final client = Client(url)
    ..connectivityMonitor = FlutterConnectivityMonitor()
    ..authSessionManager = FlutterAuthSessionManager();
  await client.auth.initialize();
  return client;
});
