import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:relay/core/models/auth_user.dart';
import 'package:relay/core/models/collection.dart';
import 'package:relay/core/models/outbox_entry.dart';
import 'package:relay/core/models/remote_workspace.dart';
import 'package:relay/core/models/sync_cursor.dart';
import 'package:relay/core/models/workspace_bundle.dart';
import 'package:relay/core/models/workspace_origin.dart';
import 'package:relay/core/remote/api_client.dart';
import 'package:relay/core/remote/auth/auth_state.dart';
import 'package:relay/core/remote/sync/outbox_store.dart';
import 'package:relay/core/storage/json_store.dart';
import 'package:relay/core/storage/workspace_paths.dart';
import 'package:relay/state/auth_notifier.dart';
import 'package:relay/state/environments_notifier.dart';
import 'package:relay/state/sync_notifier.dart';
import 'package:relay/state/workspace_notifier.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this._path);
  final String _path;

  @override
  Future<String?> getApplicationSupportPath() async => _path;
}

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);
  final ResponseBody Function(RequestOptions options) _respond;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async => _respond(options);
}

ResponseBody _jsonBody(Object body, int statusCode, {Map<String, List<String>>? headers}) => ResponseBody.fromString(
  jsonEncode(body),
  statusCode,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    ...?headers,
  },
);

class _FixedAuthNotifier extends AuthNotifier {
  _FixedAuthNotifier(this._fixed);
  final AuthState _fixed;

  @override
  AuthState build() => _fixed;
}

AuthState _signedIn(int workspaceId) =>
    AuthSignedIn(user: const AuthUserStub(), workspaces: [RemoteWorkspaceStub(workspaceId)], activeWorkspaceId: workspaceId);

/// Minimal stand-ins so this test doesn't need a full AuthResponse fixture —
/// SyncNotifier only ever reads `activeWorkspaceId` off [AuthSignedIn].
class AuthUserStub extends AuthUser {
  const AuthUserStub() : super(id: 1, name: 'Test', email: 'test@example.com');
}

class RemoteWorkspaceStub extends RemoteWorkspace {
  const RemoteWorkspaceStub(int id) : super(id: id, name: 'Test Workspace', slug: 'test-workspace', type: 'team', role: 'owner');
}

ProviderContainer _container(int workspaceId, ResponseBody Function(RequestOptions options) respond) {
  final dio = Dio(BaseOptions(baseUrl: 'https://role.example.com/api/v1'))..httpClientAdapter = _ScriptedAdapter(respond);
  final client = RemoteApiClient(baseUrl: 'https://role.example.com', dio: dio);
  return ProviderContainer(
    overrides: [
      remoteApiClientProvider.overrideWithValue(client),
      authNotifierProvider.overrideWith(() => _FixedAuthNotifier(_signedIn(workspaceId))),
      syncAutoStartProvider.overrideWithValue(false),
    ],
  );
}

Map<String, dynamic> _collectionsResponse(List<Map<String, dynamic>> items) => {
  'success': true,
  'data': {'items': items},
};

Map<String, dynamic> _updatesResponse({required List<Map<String, dynamic>> items, required int next, bool hasMore = false}) => {
  'success': true,
  'data': {
    'items': items,
    'cursor': {'next': next, 'hasMore': hasMore},
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('role_sync_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  group('SyncNotifier.debugBootstrap', () {
    test('fetches collections+environments once, caches them, and seeds the cursor', () async {
      const workspaceId = 101;
      final container = _container(workspaceId, (options) {
        if (options.path.endsWith('/collections')) {
          return _jsonBody(
            _collectionsResponse([
              {'id': 1, 'name': 'Orders API', 'description': '', 'createdAt': '2026-01-01T10:00:00.000Z', 'updatedAt': '2026-01-01T10:00:00.000Z'},
            ]),
            200,
          );
        }
        if (options.path.contains('/collections/1/endpoints')) {
          return _jsonBody(_collectionsResponse([]), 200);
        }
        if (options.path.endsWith('/environments')) {
          return _jsonBody(
            _collectionsResponse([
              {'id': 5, 'name': 'Staging', 'createdAt': '2026-01-01T10:00:00.000Z', 'updatedAt': '2026-01-01T10:00:00.000Z'},
            ]),
            200,
          );
        }
        if (options.path.contains('/environments/5/variables')) {
          return _jsonBody(
            _collectionsResponse([
              {'id': 9, 'key': 'apiUrl', 'value': 'https://api.example.com', 'enabled': true, 'isSecret': false, 'position': 0},
            ]),
            200,
          );
        }
        if (options.path.endsWith('/updates')) {
          return _jsonBody(_updatesResponse(items: const [], next: 3), 200);
        }
        throw StateError('Unexpected path: ${options.path}');
      });
      addTearDown(container.dispose);

      final cursor = await container.read(syncNotifierProvider.notifier).debugBootstrap(workspaceId);

      expect(cursor?.since, 3);

      final cachedCollections = await JsonStore.instance.readAll(WorkspacePaths.remoteCollections(workspaceId));
      expect(cachedCollections, hasLength(1));
      final cachedCollection = Map<String, dynamic>.from(cachedCollections.single['collection'] as Map);
      expect(cachedCollection['name'], 'Orders API');

      final cachedEnvironments = await JsonStore.instance.readAll(WorkspacePaths.remoteEnvironments(workspaceId));
      expect(cachedEnvironments, hasLength(1));
      expect(cachedEnvironments.single['name'], 'Staging');

      final persistedCursor = await JsonStore.instance.read(WorkspacePaths.syncCursorFile(workspaceId));
      expect(SyncCursor.fromJson(persistedCursor!).since, 3);

      // §7 merge: WorkspaceNotifier/EnvironmentsNotifier now see the cached data.
      final workspaceState = await container.read(workspaceProvider.future);
      expect(workspaceState.collections.map((c) => c.name), contains('Orders API'));
      final environments = await container.read(environmentsProvider.future);
      expect(environments.map((e) => e.name), contains('Staging'));
    });
  });

  group('SyncNotifier.debugTick', () {
    test('a page with no events advances the cursor without refetching lists', () async {
      const workspaceId = 102;
      var collectionsFetched = false;
      final container = _container(workspaceId, (options) {
        if (options.path.endsWith('/collections')) {
          collectionsFetched = true;
          return _jsonBody(_collectionsResponse([]), 200);
        }
        if (options.path.endsWith('/updates')) {
          return _jsonBody(_updatesResponse(items: const [], next: 10), 200);
        }
        throw StateError('Unexpected path: ${options.path}');
      });
      addTearDown(container.dispose);

      final next = await container.read(syncNotifierProvider.notifier).debugTick(workspaceId, const SyncCursor(workspaceId: workspaceId, since: 3));

      expect(next.since, 10);
      expect(collectionsFetched, isFalse);
      expect(container.read(syncNotifierProvider), isA<SyncSynced>());
    });

    test('a collection_endpoint event triggers a collections refetch and stale-file cleanup', () async {
      const workspaceId = 103;
      await JsonStore.instance.write(WorkspacePaths.remoteCollectionFile(workspaceId, 'stale-id'), {
        'collection': {
          'id': 'stale-id',
          'name': 'Gone',
          'createdAt': '2026-01-01T10:00:00.000Z',
          'updatedAt': '2026-01-01T10:00:00.000Z',
          'origin': 'remote',
        },
        'requests': [],
      });

      final container = _container(workspaceId, (options) {
        if (options.path.endsWith('/updates')) {
          return _jsonBody(
            _updatesResponse(
              items: [
                {'id': 1, 'entity': 'collection_endpoint', 'action': 'updated', 'entityId': 5},
              ],
              next: 4,
            ),
            200,
          );
        }
        if (options.path.endsWith('/collections')) {
          return _jsonBody(
            _collectionsResponse([
              {'id': 1, 'name': 'Orders API', 'description': '', 'createdAt': '2026-01-01T10:00:00.000Z', 'updatedAt': '2026-01-01T10:00:00.000Z'},
            ]),
            200,
          );
        }
        if (options.path.contains('/endpoints')) {
          return _jsonBody(_collectionsResponse([]), 200);
        }
        throw StateError('Unexpected path: ${options.path}');
      });
      addTearDown(container.dispose);

      await container.read(syncNotifierProvider.notifier).debugTick(workspaceId, const SyncCursor(workspaceId: workspaceId));

      final remaining = await JsonStore.instance.listIds(WorkspacePaths.remoteCollections(workspaceId));
      expect(remaining, isNot(contains('stale-id')));
      expect(remaining, hasLength(1));
    });

    test('an import_export_job event refetches both collections and environments, not knowing which it touched', () async {
      const workspaceId = 110;
      final fetchedPaths = <String>[];
      final container = _container(workspaceId, (options) {
        if (options.path.endsWith('/updates')) {
          return _jsonBody(
            _updatesResponse(
              items: [
                {'id': 1, 'entity': 'import_export_job', 'action': 'completed', 'entityId': 9},
              ],
              next: 5,
            ),
            200,
          );
        }
        if (options.path.endsWith('/collections')) {
          fetchedPaths.add('collections');
          return _jsonBody(_collectionsResponse([]), 200);
        }
        if (options.path.endsWith('/environments')) {
          fetchedPaths.add('environments');
          return _jsonBody(_collectionsResponse([]), 200);
        }
        throw StateError('Unexpected path: ${options.path}');
      });
      addTearDown(container.dispose);

      await container.read(syncNotifierProvider.notifier).debugTick(workspaceId, const SyncCursor(workspaceId: workspaceId));

      expect(fetchedPaths..sort(), ['collections', 'environments']);
    });

    test('RATE_LIMIT_EXCEEDED does not error and is not treated as a stop condition', () async {
      const workspaceId = 104;
      final container = _container(
        workspaceId,
        (options) => _jsonBody(
          {
            'success': false,
            'error': {'code': 'RATE_LIMIT_EXCEEDED', 'message': 'Too many requests'},
          },
          429,
          headers: {
            'retry-after': ['30'],
          },
        ),
      );
      addTearDown(container.dispose);

      final cursor = const SyncCursor(workspaceId: workspaceId, since: 1);
      final result = await container.read(syncNotifierProvider.notifier).debugTick(workspaceId, cursor);

      expect(result.since, 1); // cursor untouched on failure
      expect(container.read(syncNotifierProvider), isA<SyncSyncing>()); // not flipped to error
    });

    test('NETWORK_ERROR flips state to offline without stopping the workspace', () async {
      const workspaceId = 105;
      final dio = Dio(BaseOptions(baseUrl: 'https://role.example.com/api/v1'))..httpClientAdapter = _ThrowingAdapter();
      final client = RemoteApiClient(baseUrl: 'https://role.example.com', dio: dio);
      final container = ProviderContainer(
        overrides: [
          remoteApiClientProvider.overrideWithValue(client),
          authNotifierProvider.overrideWith(() => _FixedAuthNotifier(_signedIn(workspaceId))),
          syncAutoStartProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      await container.read(syncNotifierProvider.notifier).debugTick(workspaceId, const SyncCursor(workspaceId: workspaceId));

      expect(container.read(syncNotifierProvider), isA<SyncOffline>());
    });

    test('WORKSPACE_ACCESS_DENIED sets an error state', () async {
      const workspaceId = 106;
      final container = _container(
        workspaceId,
        (options) => _jsonBody({
          'success': false,
          'error': {'code': 'WORKSPACE_ACCESS_DENIED', 'message': 'You no longer have access'},
        }, 403),
      );
      addTearDown(container.dispose);

      await container.read(syncNotifierProvider.notifier).debugTick(workspaceId, const SyncCursor(workspaceId: workspaceId));

      final state = container.read(syncNotifierProvider);
      expect(state, isA<SyncError>());
      expect((state as SyncError).message, 'You no longer have access');
    });
  });

  group('SyncNotifier.debugFlushOutbox / outbox integration', () {
    test('debugFlushOutbox pushes a queued upsert and clears it on success', () async {
      const workspaceId = 108;
      final collection = Collection(
        id: 'col-a',
        name: 'Orders API',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        origin: WorkspaceOrigin.remote,
        remoteWorkspaceId: workspaceId,
        remoteId: 7,
      );
      await JsonStore.instance.write(
        WorkspacePaths.remoteCollectionFile(workspaceId, 'col-a'),
        CollectionBundle(collection: collection, requests: const []).toJson(),
      );
      await OutboxStore.enqueue(
        workspaceId,
        OutboxEntry(
          kind: OutboxKind.collection,
          operation: OutboxOperation.upsert,
          workspaceId: workspaceId,
          localId: 'col-a',
          enqueuedAt: DateTime(2026),
        ),
      );

      String? patchedPath;
      final container = _container(workspaceId, (options) {
        patchedPath = options.path;
        return _jsonBody({'success': true, 'data': {}}, 200);
      });
      addTearDown(container.dispose);

      await container.read(syncNotifierProvider.notifier).debugFlushOutbox(workspaceId);

      expect(patchedPath, '/workspaces/$workspaceId/collections/7');
      expect(await OutboxStore.load(workspaceId), isEmpty);
    });

    test('debugTick flushes the outbox before polling for updates', () async {
      const workspaceId = 109;
      final collection = Collection(
        id: 'col-a',
        name: 'Orders API',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        origin: WorkspaceOrigin.remote,
        remoteWorkspaceId: workspaceId,
        remoteId: 7,
      );
      await JsonStore.instance.write(
        WorkspacePaths.remoteCollectionFile(workspaceId, 'col-a'),
        CollectionBundle(collection: collection, requests: const []).toJson(),
      );
      await OutboxStore.enqueue(
        workspaceId,
        OutboxEntry(
          kind: OutboxKind.collection,
          operation: OutboxOperation.upsert,
          workspaceId: workspaceId,
          localId: 'col-a',
          enqueuedAt: DateTime(2026),
        ),
      );

      final calls = <String>[];
      final container = _container(workspaceId, (options) {
        calls.add('${options.method} ${options.path}');
        if (options.path.endsWith('/updates')) {
          return _jsonBody(_updatesResponse(items: const [], next: 5), 200);
        }
        return _jsonBody({'success': true, 'data': {}}, 200);
      });
      addTearDown(container.dispose);

      await container.read(syncNotifierProvider.notifier).debugTick(workspaceId, const SyncCursor(workspaceId: workspaceId));

      expect(calls.first, 'PATCH /workspaces/$workspaceId/collections/7');
      expect(await OutboxStore.load(workspaceId), isEmpty);
    });
  });

  group('SyncNotifier.clearCache', () {
    test('deletes the whole remote/<id> subtree', () async {
      const workspaceId = 107;
      await JsonStore.instance.write(WorkspacePaths.remoteCollectionFile(workspaceId, 'a'), {
        'collection': {'id': 'a', 'name': 'A', 'createdAt': '2026-01-01T10:00:00.000Z', 'updatedAt': '2026-01-01T10:00:00.000Z', 'origin': 'remote'},
        'requests': [],
      });

      final container = _container(workspaceId, (options) => throw StateError('no network calls expected'));
      addTearDown(container.dispose);

      await container.read(syncNotifierProvider.notifier).clearCache(workspaceId);

      final remaining = await JsonStore.instance.listIds(WorkspacePaths.remoteCollections(workspaceId));
      expect(remaining, isEmpty);
    });
  });

  group('activeRemoteWorkspaceIdProvider', () {
    test('null when signed out, the active workspace id when signed in', () {
      final signedOutContainer = ProviderContainer(overrides: [authNotifierProvider.overrideWith(() => _FixedAuthNotifier(const AuthSignedOut()))]);
      addTearDown(signedOutContainer.dispose);
      expect(signedOutContainer.read(activeRemoteWorkspaceIdProvider), isNull);

      final signedInContainer = ProviderContainer(overrides: [authNotifierProvider.overrideWith(() => _FixedAuthNotifier(_signedIn(42)))]);
      addTearDown(signedInContainer.dispose);
      expect(signedInContainer.read(activeRemoteWorkspaceIdProvider), 42);
    });
  });
}

class _ThrowingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    throw DioException(requestOptions: options, type: DioExceptionType.connectionError, message: 'Failed host lookup');
  }
}
