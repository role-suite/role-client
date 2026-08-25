import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:relay/core/models/api_request.dart';
import 'package:relay/core/models/auth_user.dart';
import 'package:relay/core/models/enums.dart';
import 'package:relay/core/models/environment_variable.dart';
import 'package:relay/core/models/key_value_entry.dart';
import 'package:relay/core/models/remote_workspace.dart';
import 'package:relay/core/models/request_body.dart';
import 'package:relay/core/models/workspace_origin.dart';
import 'package:relay/core/remote/api_client.dart';
import 'package:relay/core/remote/auth/auth_state.dart';
import 'package:relay/core/remote/remote_api_exception.dart';
import 'package:relay/core/storage/json_store.dart';
import 'package:relay/core/storage/workspace_paths.dart';
import 'package:relay/state/auth_notifier.dart';
import 'package:relay/state/environments_notifier.dart';
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

class _FixedAuthNotifier extends AuthNotifier {
  _FixedAuthNotifier(this._fixed);
  final AuthState _fixed;

  @override
  AuthState build() => _fixed;
}

ResponseBody _jsonBody(Object body, int statusCode) => ResponseBody.fromString(
  jsonEncode(body),
  statusCode,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

ProviderContainer _container(int workspaceId, ResponseBody Function(RequestOptions options) respond) {
  final dio = Dio(BaseOptions(baseUrl: 'https://role.example.com/api/v1'))..httpClientAdapter = _ScriptedAdapter(respond);
  final client = RemoteApiClient(baseUrl: 'https://role.example.com', dio: dio);
  final auth = AuthSignedIn(
    user: const AuthUser(id: 1, name: 'Altay', email: 'altay@example.com'),
    workspaces: [RemoteWorkspace(id: workspaceId, name: 'Team', slug: 'team', type: 'team', role: 'owner')],
    activeWorkspaceId: workspaceId,
  );
  return ProviderContainer(
    overrides: [remoteApiClientProvider.overrideWithValue(client), authNotifierProvider.overrideWith(() => _FixedAuthNotifier(auth))],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('role_remote_create_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  test('WorkspaceNotifier creates signed-in top-level collections remotely and caches them as remote-origin', () async {
    const workspaceId = 701;
    await JsonStore.instance.deleteDirectory(WorkspacePaths.remoteRoot(workspaceId));
    Map<String, dynamic>? sentData;
    final container = _container(workspaceId, (options) {
      expect(options.method, 'POST');
      expect(options.path, '/workspaces/$workspaceId/collections');
      sentData = Map<String, dynamic>.from(options.data as Map);
      return _jsonBody({
        'success': true,
        'data': {'id': 9, 'name': 'Orders API', 'description': '', 'createdAt': '2026-01-01T00:00:00.000Z', 'updatedAt': '2026-01-01T00:00:00.000Z'},
      }, 201);
    });
    addTearDown(container.dispose);
    await container.read(workspaceProvider.future);

    final collection = await container.read(workspaceProvider.notifier).createCollection(name: 'Orders API');

    expect(sentData, {'name': 'Orders API'});
    expect(collection.origin, WorkspaceOrigin.remote);
    expect(collection.remoteWorkspaceId, workspaceId);
    expect(collection.remoteId, 9);
    expect((await JsonStore.instance.read(WorkspacePaths.remoteCollectionFile(workspaceId, collection.id)))?['collection'], isA<Map>());
  });

  test('WorkspaceNotifier validates remote collection create before HTTP', () async {
    const workspaceId = 705;
    var called = false;
    final container = _container(workspaceId, (options) {
      called = true;
      return _jsonBody({'success': true, 'data': {}}, 200);
    });
    addTearDown(container.dispose);
    await container.read(workspaceProvider.future);

    await expectLater(container.read(workspaceProvider.notifier).createCollection(name: 'A'), throwsA(isA<RemoteApiException>()));
    expect(called, isFalse);
  });

  test('WorkspaceNotifier creates requests in remote collections through endpoint create', () async {
    const workspaceId = 702;
    await JsonStore.instance.deleteDirectory(WorkspacePaths.remoteRoot(workspaceId));
    final calls = <String>[];
    final container = _container(workspaceId, (options) {
      calls.add('${options.method} ${options.path}');
      if (options.path.endsWith('/collections')) {
        return _jsonBody({
          'success': true,
          'data': {
            'id': 11,
            'name': 'Orders API',
            'description': '',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        }, 201);
      }
      expect(Map<String, dynamic>.from(options.data as Map)['url'], '/');
      return _jsonBody({
        'success': true,
        'data': {
          'id': 44,
          'name': 'New Request',
          'method': 'GET',
          'url': '/',
          'headers': const [],
          'queryParams': const [],
          'body': {'mode': 'none'},
          'auth': {'type': 'none'},
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        },
      }, 201);
    });
    addTearDown(container.dispose);
    await container.read(workspaceProvider.future);
    final collection = await container.read(workspaceProvider.notifier).createCollection(name: 'Orders API');

    final request = await container.read(workspaceProvider.notifier).createRequest(collectionId: collection.id, name: 'New Request');

    expect(calls, ['POST /workspaces/$workspaceId/collections', 'POST /workspaces/$workspaceId/collections/11/endpoints']);
    expect(request.origin, WorkspaceOrigin.remote);
    expect(request.remoteId, 44);
  });

  test('WorkspaceNotifier validates remote request create before endpoint HTTP', () async {
    const workspaceId = 706;
    var endpointCalled = false;
    final container = _container(workspaceId, (options) {
      if (options.path.endsWith('/collections')) {
        return _jsonBody({
          'success': true,
          'data': {
            'id': 13,
            'name': 'Users API',
            'description': '',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        }, 201);
      }
      endpointCalled = true;
      return _jsonBody({'success': true, 'data': {}}, 200);
    });
    addTearDown(container.dispose);
    await container.read(workspaceProvider.future);
    final collection = await container.read(workspaceProvider.notifier).createCollection(name: 'Users API');

    await expectLater(
      container.read(workspaceProvider.notifier).createRequest(collectionId: collection.id, name: 'A'),
      throwsA(isA<RemoteApiException>()),
    );
    expect(endpointCalled, isFalse);
  });

  test('WorkspaceNotifier duplicates remote requests by creating a copied remote endpoint', () async {
    const workspaceId = 704;
    await JsonStore.instance.deleteDirectory(WorkspacePaths.remoteRoot(workspaceId));
    final calls = <String>[];
    final endpointPayloads = <Map<String, dynamic>>[];
    final container = _container(workspaceId, (options) {
      calls.add('${options.method} ${options.path}');
      if (options.path.endsWith('/collections')) {
        return _jsonBody({
          'success': true,
          'data': {
            'id': 12,
            'name': 'Users API',
            'description': '',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        }, 201);
      }

      final payload = Map<String, dynamic>.from(options.data as Map);
      endpointPayloads.add(payload);
      final endpointId = endpointPayloads.length == 1 ? 45 : 46;
      return _jsonBody({
        'success': true,
        'data': {
          'id': endpointId,
          'name': payload['name'],
          'method': payload['method'],
          'url': payload['url'],
          'headers': payload['headers'],
          'queryParams': payload['queryParams'],
          'body': payload['body'],
          'auth': payload['auth'],
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        },
      }, 201);
    });
    addTearDown(container.dispose);
    await container.read(workspaceProvider.future);
    final collection = await container.read(workspaceProvider.notifier).createCollection(name: 'Users API');
    final now = DateTime.utc(2026);
    final template = ApiRequest(
      id: 'template',
      collectionId: collection.id,
      name: 'Create user',
      method: HttpMethod.post,
      url: '/users',
      headers: const [KeyValueEntry(key: 'Content-Type', value: 'application/json')],
      queryParams: const [KeyValueEntry(key: 'verbose', value: 'true')],
      requestBody: const RawBody(contentType: 'application/json', raw: '{"name":"Ada"}'),
      authType: AuthType.bearer,
      authConfig: const {AuthConfigKeys.token: 'token-123'},
      description: 'Creates a user',
      createdAt: now,
      updatedAt: now,
    );
    final source = await container
        .read(workspaceProvider.notifier)
        .createRequest(collectionId: collection.id, name: 'Create user', template: template);

    final duplicate = await container.read(workspaceProvider.notifier).duplicateRequest(source);

    expect(calls, [
      'POST /workspaces/$workspaceId/collections',
      'POST /workspaces/$workspaceId/collections/12/endpoints',
      'POST /workspaces/$workspaceId/collections/12/endpoints',
    ]);
    expect(endpointPayloads.last['name'], 'Create user copy');
    expect(endpointPayloads.last['method'], 'POST');
    expect(endpointPayloads.last['url'], '/users');
    expect(endpointPayloads.last['headers'], [
      {'key': 'Content-Type', 'value': 'application/json', 'enabled': true},
    ]);
    expect(endpointPayloads.last['queryParams'], [
      {'key': 'verbose', 'value': 'true', 'enabled': true},
    ]);
    expect(endpointPayloads.last['body'], {'mode': 'raw', 'contentType': 'application/json', 'raw': '{"name":"Ada"}'});
    expect(endpointPayloads.last['auth'], {'type': 'bearer', 'token': 'token-123'});
    expect(duplicate.origin, WorkspaceOrigin.remote);
    expect(duplicate.remoteId, 46);
    expect(duplicate.description, 'Creates a user');
  });

  test('EnvironmentsNotifier creates signed-in environments and initial variables remotely', () async {
    const workspaceId = 703;
    await JsonStore.instance.deleteDirectory(WorkspacePaths.remoteRoot(workspaceId));
    final calls = <String>[];
    final container = _container(workspaceId, (options) {
      calls.add('${options.method} ${options.path}');
      if (options.path.endsWith('/environments')) {
        return _jsonBody({
          'success': true,
          'data': {'id': 3, 'name': 'Staging', 'createdAt': '2026-01-01T00:00:00.000Z', 'updatedAt': '2026-01-01T00:00:00.000Z'},
        }, 201);
      }
      return _jsonBody({
        'success': true,
        'data': {'id': 10, 'key': 'BASE_URL', 'value': 'https://api.example.com', 'enabled': true, 'isSecret': false, 'position': 0},
      }, 201);
    });
    addTearDown(container.dispose);
    await container.read(environmentsProvider.future);

    final env = await container
        .read(environmentsProvider.notifier)
        .create(
          name: 'Staging',
          variables: const [EnvironmentVariable(key: 'BASE_URL', value: 'https://api.example.com')],
        );

    expect(calls, ['POST /workspaces/$workspaceId/environments', 'POST /workspaces/$workspaceId/environments/3/variables']);
    expect(env.origin, WorkspaceOrigin.remote);
    expect(env.remoteId, 3);
    expect(env.variables.single.remoteId, 10);
  });

  test('EnvironmentsNotifier validates remote environment create before HTTP', () async {
    const workspaceId = 707;
    var called = false;
    final container = _container(workspaceId, (options) {
      called = true;
      return _jsonBody({'success': true, 'data': {}}, 200);
    });
    addTearDown(container.dispose);
    await container.read(environmentsProvider.future);

    await expectLater(container.read(environmentsProvider.notifier).create(name: 'A'), throwsA(isA<RemoteApiException>()));
    expect(called, isFalse);
  });
}
