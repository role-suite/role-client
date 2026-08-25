import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/api_request.dart';
import 'package:relay/core/models/collection.dart';
import 'package:relay/core/models/enums.dart';
import 'package:relay/core/models/environment.dart';
import 'package:relay/core/models/environment_variable.dart';
import 'package:relay/core/models/key_value_entry.dart';
import 'package:relay/core/models/request_body.dart';
import 'package:relay/core/models/workspace_origin.dart';
import 'package:relay/core/remote/api_client.dart';
import 'package:relay/core/remote/sync/workspace_push_service.dart';

ResponseBody _jsonBody(Object body, int statusCode) => ResponseBody.fromString(
  jsonEncode(body),
  statusCode,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);
  final ResponseBody Function(RequestOptions options) _respond;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async => _respond(options);
}

WorkspacePushService _serviceWith(ResponseBody Function(RequestOptions options) respond) {
  final dio = Dio(BaseOptions(baseUrl: 'https://role.example.com/api/v1'))..httpClientAdapter = _ScriptedAdapter(respond);
  return WorkspacePushService(RemoteApiClient(baseUrl: 'https://role.example.com', dio: dio));
}

Collection _collection() => Collection(
  id: 'remote-col-1-7',
  name: 'Orders API',
  description: 'desc',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  origin: WorkspaceOrigin.remote,
  remoteWorkspaceId: 1,
  remoteId: 7,
);

ApiRequest _request({RequestBody body = const NoneBody(), AuthType authType = AuthType.none, Map<String, String> authConfig = const {}}) =>
    ApiRequest(
      id: 'remote-req-1-42',
      collectionId: 'remote-col-1-7',
      name: 'Get Orders',
      method: HttpMethod.get,
      url: 'https://api.example.com/orders',
      headers: const [KeyValueEntry(key: 'Accept', value: 'application/json')],
      requestBody: body,
      authType: authType,
      authConfig: authConfig,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      origin: WorkspaceOrigin.remote,
      remoteWorkspaceId: 1,
      remoteId: 42,
    );

void main() {
  group('updateCollection / deleteCollection', () {
    test('PATCHes name+description, DELETEs by remote id', () async {
      final calls = <String>[];
      final service = _serviceWith((options) {
        calls.add('${options.method} ${options.path}');
        return _jsonBody({'success': true, 'data': {}}, 200);
      });

      await service.updateCollection(1, 7, _collection());
      await service.deleteCollection(1, 7);

      expect(calls, ['PATCH /workspaces/1/collections/7', 'DELETE /workspaces/1/collections/7']);
    });
  });

  group('updateEndpoint / deleteEndpoint', () {
    test('sends the whole object shape role-node expects', () async {
      Map<String, dynamic>? sentData;
      final service = _serviceWith((options) {
        if (options.method == 'PATCH') sentData = Map<String, dynamic>.from(options.data as Map);
        return _jsonBody({'success': true, 'data': {}}, 200);
      });

      await service.updateEndpoint(
        1,
        7,
        42,
        _request(
          body: const RawBody(contentType: 'application/json', raw: '{}'),
        ),
      );

      expect(sentData!['method'], 'GET');
      expect(sentData!['headers'], [
        {'key': 'Accept', 'value': 'application/json', 'enabled': true},
      ]);
      expect(sentData!['body'], {'mode': 'raw', 'contentType': 'application/json', 'raw': '{}'});
      expect(sentData!['auth'], {'type': 'none'});
    });

    test('maps bearer/basic auth to wire shape', () async {
      Map<String, dynamic>? sentData;
      final service = _serviceWith((options) {
        sentData = Map<String, dynamic>.from(options.data as Map);
        return _jsonBody({'success': true, 'data': {}}, 200);
      });

      await service.updateEndpoint(1, 7, 42, _request(authType: AuthType.bearer, authConfig: {AuthConfigKeys.token: 'secret'}));
      expect(sentData!['auth'], {'type': 'bearer', 'token': 'secret'});
    });

    test('deleteEndpoint hits the nested route', () async {
      final calls = <String>[];
      final service = _serviceWith((options) {
        calls.add('${options.method} ${options.path}');
        return _jsonBody({'success': true, 'data': {}}, 200);
      });
      await service.deleteEndpoint(1, 7, 42);
      expect(calls, ['DELETE /workspaces/1/collections/7/endpoints/42']);
    });
  });

  group('updateEnvironment / deleteEnvironment', () {
    test('PATCHes name, DELETEs by remote id', () async {
      final calls = <String>[];
      final service = _serviceWith((options) {
        calls.add('${options.method} ${options.path}');
        return _jsonBody({'success': true, 'data': {}}, 200);
      });
      final environment = Environment(
        id: 'remote-env-1-3',
        name: 'Staging',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        origin: WorkspaceOrigin.remote,
        remoteWorkspaceId: 1,
        remoteId: 3,
      );

      await service.updateEnvironment(1, 3, environment);
      await service.deleteEnvironment(1, 3);

      expect(calls, ['PATCH /workspaces/1/environments/3', 'DELETE /workspaces/1/environments/3']);
    });
  });

  group('reconcileVariables', () {
    test('creates a key missing remotely, updates a key present in both, deletes one missing locally', () async {
      final calls = <String>[];
      final service = _serviceWith((options) {
        calls.add('${options.method} ${options.path}');
        if (options.method == 'GET') {
          return _jsonBody({
            'success': true,
            'data': {
              'items': [
                {'id': 100, 'key': 'apiUrl', 'value': 'https://old.example.com', 'enabled': true, 'isSecret': false, 'position': 0},
                {'id': 101, 'key': 'staleKey', 'value': 'x', 'enabled': true, 'isSecret': false, 'position': 1},
              ],
            },
          }, 200);
        }
        return _jsonBody({'success': true, 'data': {}}, 200);
      });

      await service.reconcileVariables(1, 3, [
        const EnvironmentVariable(key: 'apiUrl', value: 'https://new.example.com', remoteId: 100),
        const EnvironmentVariable(key: 'newKey', value: 'v'),
      ]);

      expect(calls, [
        'GET /workspaces/1/environments/3/variables',
        'PATCH /workspaces/1/environments/3/variables/100',
        'POST /workspaces/1/environments/3/variables',
        'DELETE /workspaces/1/environments/3/variables/101',
      ]);
    });

    test('matches a renamed key by remoteId instead of treating it as delete+create', () async {
      final calls = <String>[];
      Map<String, dynamic>? patchedData;
      final service = _serviceWith((options) {
        calls.add('${options.method} ${options.path}');
        if (options.method == 'GET') {
          return _jsonBody({
            'success': true,
            'data': {
              'items': [
                {'id': 100, 'key': 'oldName', 'value': 'v', 'enabled': true, 'isSecret': false, 'position': 0},
              ],
            },
          }, 200);
        }
        if (options.method == 'PATCH') patchedData = Map<String, dynamic>.from(options.data as Map);
        return _jsonBody({'success': true, 'data': {}}, 200);
      });

      // Same remoteId (100), renamed key — must PATCH that row, never DELETE+POST.
      await service.reconcileVariables(1, 3, [const EnvironmentVariable(key: 'newName', value: 'v', remoteId: 100)]);

      expect(calls, ['GET /workspaces/1/environments/3/variables', 'PATCH /workspaces/1/environments/3/variables/100']);
      expect(patchedData!['key'], 'newName');
    });
  });
}
