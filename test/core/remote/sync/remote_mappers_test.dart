import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/enums.dart';
import 'package:relay/core/models/request_body.dart';
import 'package:relay/core/models/workspace_origin.dart';
import 'package:relay/core/remote/sync/remote_mappers.dart';

void main() {
  group('collectionFromRemote', () {
    test('maps role-node collection response fields, stamped remote', () {
      final collection = collectionFromRemote({
        'id': 7,
        'workspaceId': 1,
        'name': 'Orders API',
        'description': 'Collection for orders endpoints',
        'createdByUserId': 1,
        'createdAt': '2026-01-01T10:00:00.000Z',
        'updatedAt': '2026-01-02T10:00:00.000Z',
      }, workspaceId: 1);

      expect(collection.id, remoteCollectionLocalId(1, 7));
      expect(collection.name, 'Orders API');
      expect(collection.description, 'Collection for orders endpoints');
      expect(collection.origin, WorkspaceOrigin.remote);
      expect(collection.remoteWorkspaceId, 1);
      expect(collection.remoteId, 7);
      expect(collection.syncedAt, isNotNull);
    });

    test('local id is stable across repeated calls with the same remote id', () {
      final json = {'id': 7, 'name': 'Orders API', 'createdAt': '2026-01-01T10:00:00.000Z', 'updatedAt': '2026-01-01T10:00:00.000Z'};
      final first = collectionFromRemote(json, workspaceId: 1);
      final second = collectionFromRemote(json, workspaceId: 1);
      expect(first.id, second.id);
    });
  });

  group('apiRequestFromRemoteEndpoint', () {
    Map<String, dynamic> endpoint({dynamic body, dynamic auth}) => {
      'id': 42,
      'collectionId': 7,
      'folderId': null,
      'name': 'Get Orders',
      'method': 'GET',
      'url': 'https://api.example.com/orders',
      'headers': [
        {'key': 'Accept', 'value': 'application/json'},
      ],
      'queryParams': [
        {'key': 'limit', 'value': '10'},
      ],
      'body': body,
      'auth': auth,
      'position': 0,
      'createdAt': '2026-01-01T10:00:00.000Z',
      'updatedAt': '2026-01-01T10:00:00.000Z',
    };

    test('maps headers/queryParams directly (already {key,value,enabled?} shape)', () {
      final request = apiRequestFromRemoteEndpoint(endpoint(), workspaceId: 1, collectionId: 'col-1');
      expect(request.id, remoteRequestLocalId(1, 42));
      expect(request.collectionId, 'col-1');
      expect(request.method, HttpMethod.get);
      expect(request.headers.single.key, 'Accept');
      expect(request.queryParams.single.value, '10');
      expect(request.origin, WorkspaceOrigin.remote);
    });

    test('maps a raw body (mode -> type)', () {
      final request = apiRequestFromRemoteEndpoint(
        endpoint(body: {'mode': 'raw', 'contentType': 'application/json', 'raw': '{"a":1}'}),
        workspaceId: 1,
        collectionId: 'col-1',
      );
      final body = request.requestBody as RawBody;
      expect(body.contentType, 'application/json');
      expect(body.raw, '{"a":1}');
    });

    test('maps a urlencoded body', () {
      final request = apiRequestFromRemoteEndpoint(
        endpoint(
          body: {
            'mode': 'urlencoded',
            'entries': [
              {'key': 'a', 'value': '1', 'enabled': true},
            ],
          },
        ),
        workspaceId: 1,
        collectionId: 'col-1',
      );
      final body = request.requestBody as UrlEncodedBody;
      expect(body.entries.single.key, 'a');
    });

    test('maps a formdata body (entries -> parts, text and file variants)', () {
      final request = apiRequestFromRemoteEndpoint(
        endpoint(
          body: {
            'mode': 'formdata',
            'entries': [
              {'type': 'text', 'key': 'name', 'value': 'Altay', 'enabled': true},
              {'type': 'file', 'key': 'avatar', 'fileName': 'a.png', 'contentType': 'image/png', 'dataBase64': 'YWJj', 'enabled': true},
            ],
          },
        ),
        workspaceId: 1,
        collectionId: 'col-1',
      );
      final body = request.requestBody as FormDataBody;
      final text = body.parts[0] as FormTextPart;
      final file = body.parts[1] as FormFilePart;
      expect(text.key, 'name');
      expect(text.value, 'Altay');
      expect(file.fileName, 'a.png');
      expect(file.dataBase64, 'YWJj');
    });

    test('maps a binary body', () {
      final request = apiRequestFromRemoteEndpoint(
        endpoint(body: {'mode': 'binary', 'fileName': 'a.bin', 'contentType': 'application/octet-stream', 'dataBase64': 'YWJj'}),
        workspaceId: 1,
        collectionId: 'col-1',
      );
      final body = request.requestBody as BinaryBody;
      expect(body.fileName, 'a.bin');
      expect(body.dataBase64, 'YWJj');
    });

    test('maps a none body and a null body the same way', () {
      expect(apiRequestFromRemoteEndpoint(endpoint(body: {'mode': 'none'}), workspaceId: 1, collectionId: 'col-1').requestBody, isA<NoneBody>());
      expect(apiRequestFromRemoteEndpoint(endpoint(body: null), workspaceId: 1, collectionId: 'col-1').requestBody, isA<NoneBody>());
    });

    test('maps bearer auth', () {
      final request = apiRequestFromRemoteEndpoint(
        endpoint(auth: {'type': 'bearer', 'token': 'secret-token'}),
        workspaceId: 1,
        collectionId: 'col-1',
      );
      expect(request.authType, AuthType.bearer);
      expect(request.authConfig[AuthConfigKeys.token], 'secret-token');
    });

    test('maps basic auth', () {
      final request = apiRequestFromRemoteEndpoint(
        endpoint(auth: {'type': 'basic', 'username': 'u', 'password': 'p'}),
        workspaceId: 1,
        collectionId: 'col-1',
      );
      expect(request.authType, AuthType.basic);
      expect(request.authConfig[AuthConfigKeys.username], 'u');
      expect(request.authConfig[AuthConfigKeys.password], 'p');
    });

    test('maps none/absent auth to AuthType.none', () {
      expect(apiRequestFromRemoteEndpoint(endpoint(auth: {'type': 'none'}), workspaceId: 1, collectionId: 'col-1').authType, AuthType.none);
      expect(apiRequestFromRemoteEndpoint(endpoint(auth: null), workspaceId: 1, collectionId: 'col-1').authType, AuthType.none);
    });
  });

  group('environmentFromRemote / environmentVariableFromRemote', () {
    test('maps environment fields, stamped remote', () {
      final environment = environmentFromRemote(
        {'id': 3, 'workspaceId': 1, 'name': 'Staging', 'createdAt': '2026-01-01T10:00:00.000Z', 'updatedAt': '2026-01-01T10:00:00.000Z'},
        workspaceId: 1,
        variables: const [],
      );

      expect(environment.id, remoteEnvironmentLocalId(1, 3));
      expect(environment.name, 'Staging');
      expect(environment.origin, WorkspaceOrigin.remote);
      expect(environment.remoteId, 3);
    });

    test('variable rows already match EnvironmentVariable field names', () {
      final variable = environmentVariableFromRemote({
        'id': 9,
        'environmentId': 3,
        'key': 'apiUrl',
        'value': 'https://api.example.com',
        'enabled': true,
        'isSecret': false,
        'position': 0,
      });

      expect(variable.key, 'apiUrl');
      expect(variable.value, 'https://api.example.com');
      expect(variable.enabled, isTrue);
      expect(variable.isSecret, isFalse);
    });
  });
}
