import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:relay/core/models/api_request.dart';
import 'package:relay/core/models/collection.dart';
import 'package:relay/core/models/environment.dart';
import 'package:relay/core/models/outbox_entry.dart';
import 'package:relay/core/models/workspace_bundle.dart';
import 'package:relay/core/models/workspace_origin.dart';
import 'package:relay/core/remote/api_client.dart';
import 'package:relay/core/remote/sync/outbox_flusher.dart';
import 'package:relay/core/remote/sync/outbox_store.dart';
import 'package:relay/core/remote/sync/workspace_push_service.dart';
import 'package:relay/core/storage/json_store.dart';
import 'package:relay/core/storage/workspace_paths.dart';

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

ResponseBody _jsonBody(Object body, int statusCode) => ResponseBody.fromString(
  jsonEncode(body),
  statusCode,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

WorkspacePushService _pushWith(ResponseBody Function(RequestOptions options) respond) {
  final dio = Dio(BaseOptions(baseUrl: 'https://role.example.com/api/v1'))..httpClientAdapter = _ScriptedAdapter(respond);
  return WorkspacePushService(RemoteApiClient(baseUrl: 'https://role.example.com', dio: dio));
}

Collection _collection(String id, int remoteId) => Collection(
  id: id,
  name: 'Orders API',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  origin: WorkspaceOrigin.remote,
  remoteWorkspaceId: 1,
  remoteId: remoteId,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('role_outbox_flusher_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  test('upsert collection reads the current local cache file and pushes it', () async {
    const workspaceId = 301;
    await JsonStore.instance.write(
      WorkspacePaths.remoteCollectionFile(workspaceId, 'col-a'),
      CollectionBundle(collection: _collection('col-a', 7), requests: const []).toJson(),
    );

    String? patchedPath;
    final push = _pushWith((options) {
      patchedPath = options.path;
      return _jsonBody({'success': true, 'data': {}}, 200);
    });

    final ok = await flushOutboxEntry(
      push,
      OutboxEntry(
        kind: OutboxKind.collection,
        operation: OutboxOperation.upsert,
        workspaceId: workspaceId,
        localId: 'col-a',
        enqueuedAt: DateTime(2026),
      ),
    );

    expect(ok, isTrue);
    expect(patchedPath, '/workspaces/$workspaceId/collections/7');
  });

  test('upsert with no local file left (already deleted) is a no-op success', () async {
    const workspaceId = 302;
    var called = false;
    final push = _pushWith((options) {
      called = true;
      return _jsonBody({'success': true, 'data': {}}, 200);
    });

    final ok = await flushOutboxEntry(
      push,
      OutboxEntry(
        kind: OutboxKind.collection,
        operation: OutboxOperation.upsert,
        workspaceId: workspaceId,
        localId: 'gone',
        enqueuedAt: DateTime(2026),
      ),
    );

    expect(ok, isTrue);
    expect(called, isFalse);
  });

  test('upsert request reads it out of its collection bundle file', () async {
    const workspaceId = 303;
    final request = ApiRequest(
      id: 'req-a',
      collectionId: 'col-a',
      name: 'Get Orders',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      origin: WorkspaceOrigin.remote,
      remoteWorkspaceId: workspaceId,
      remoteId: 42,
    );
    await JsonStore.instance.write(
      WorkspacePaths.remoteCollectionFile(workspaceId, 'col-a'),
      CollectionBundle(collection: _collection('col-a', 7), requests: [request]).toJson(),
    );

    String? patchedPath;
    final push = _pushWith((options) {
      patchedPath = options.path;
      return _jsonBody({'success': true, 'data': {}}, 200);
    });

    final ok = await flushOutboxEntry(
      push,
      OutboxEntry(
        kind: OutboxKind.request,
        operation: OutboxOperation.upsert,
        workspaceId: workspaceId,
        localId: 'req-a',
        collectionLocalId: 'col-a',
        enqueuedAt: DateTime(2026),
      ),
    );

    expect(ok, isTrue);
    expect(patchedPath, '/workspaces/$workspaceId/collections/7/endpoints/42');
  });

  test('upsert environment PATCHes the name and reconciles variables', () async {
    const workspaceId = 304;
    final environment = Environment(
      id: 'env-a',
      name: 'Staging',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      origin: WorkspaceOrigin.remote,
      remoteWorkspaceId: workspaceId,
      remoteId: 3,
    );
    await JsonStore.instance.write(WorkspacePaths.remoteEnvironmentFile(workspaceId, 'env-a'), environment.toJson());

    final calls = <String>[];
    final push = _pushWith((options) {
      calls.add('${options.method} ${options.path}');
      if (options.method == 'GET') {
        return _jsonBody({
          'success': true,
          'data': {'items': []},
        }, 200);
      }
      return _jsonBody({'success': true, 'data': {}}, 200);
    });

    final ok = await flushOutboxEntry(
      push,
      OutboxEntry(
        kind: OutboxKind.environment,
        operation: OutboxOperation.upsert,
        workspaceId: workspaceId,
        localId: 'env-a',
        enqueuedAt: DateTime(2026),
      ),
    );

    expect(ok, isTrue);
    expect(calls, ['PATCH /workspaces/$workspaceId/environments/3', 'GET /workspaces/$workspaceId/environments/3/variables']);
  });

  test('delete entries use the captured remote ids, never touching local files', () async {
    const workspaceId = 305;
    final calls = <String>[];
    final push = _pushWith((options) {
      calls.add('${options.method} ${options.path}');
      return _jsonBody({'success': true, 'data': {}}, 200);
    });

    await flushOutboxEntry(
      push,
      OutboxEntry(
        kind: OutboxKind.request,
        operation: OutboxOperation.delete,
        workspaceId: workspaceId,
        localId: 'req-a',
        deletedRemoteId: 42,
        deletedParentRemoteId: 7,
        enqueuedAt: DateTime(2026),
      ),
    );

    expect(calls, ['DELETE /workspaces/$workspaceId/collections/7/endpoints/42']);
  });

  test('a permanent error (COLLECTION_NOT_FOUND) drops the entry and reports success', () async {
    const workspaceId = 306;
    await JsonStore.instance.write(
      WorkspacePaths.remoteCollectionFile(workspaceId, 'col-a'),
      CollectionBundle(collection: _collection('col-a', 7), requests: const []).toJson(),
    );
    final entry = OutboxEntry(
      kind: OutboxKind.collection,
      operation: OutboxOperation.upsert,
      workspaceId: workspaceId,
      localId: 'col-a',
      enqueuedAt: DateTime(2026),
    );
    await OutboxStore.enqueue(workspaceId, entry);

    final push = _pushWith(
      (options) => _jsonBody({
        'success': false,
        'error': {'code': 'COLLECTION_NOT_FOUND', 'message': 'Collection not found'},
      }, 404),
    );

    final ok = await flushOutboxEntry(push, entry);

    expect(ok, isTrue);
    expect(await OutboxStore.load(workspaceId), isEmpty);
  });

  test('a retryable error (NETWORK_ERROR) leaves the entry queued', () async {
    const workspaceId = 307;
    await JsonStore.instance.write(
      WorkspacePaths.remoteCollectionFile(workspaceId, 'col-a'),
      CollectionBundle(collection: _collection('col-a', 7), requests: const []).toJson(),
    );
    final entry = OutboxEntry(
      kind: OutboxKind.collection,
      operation: OutboxOperation.upsert,
      workspaceId: workspaceId,
      localId: 'col-a',
      enqueuedAt: DateTime(2026),
    );
    await OutboxStore.enqueue(workspaceId, entry);

    final dio = Dio(BaseOptions(baseUrl: 'https://role.example.com/api/v1'))..httpClientAdapter = _ThrowingAdapter();
    final push = WorkspacePushService(RemoteApiClient(baseUrl: 'https://role.example.com', dio: dio));

    final ok = await flushOutboxEntry(push, entry);

    expect(ok, isFalse);
    expect(await OutboxStore.load(workspaceId), hasLength(1));
  });

  group('flushOutbox', () {
    test('attempts every queued entry', () async {
      const workspaceId = 308;
      await JsonStore.instance.write(
        WorkspacePaths.remoteCollectionFile(workspaceId, 'col-a'),
        CollectionBundle(collection: _collection('col-a', 7), requests: const []).toJson(),
      );
      await JsonStore.instance.write(
        WorkspacePaths.remoteCollectionFile(workspaceId, 'col-b'),
        CollectionBundle(collection: _collection('col-b', 8), requests: const []).toJson(),
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
      await OutboxStore.enqueue(
        workspaceId,
        OutboxEntry(
          kind: OutboxKind.collection,
          operation: OutboxOperation.upsert,
          workspaceId: workspaceId,
          localId: 'col-b',
          enqueuedAt: DateTime(2026),
        ),
      );

      final calls = <String>[];
      final push = _pushWith((options) {
        calls.add(options.path);
        return _jsonBody({'success': true, 'data': {}}, 200);
      });

      await flushOutbox(push, workspaceId);

      expect(calls..sort(), ['/workspaces/$workspaceId/collections/7', '/workspaces/$workspaceId/collections/8']);
      expect(await OutboxStore.load(workspaceId), isEmpty);
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
