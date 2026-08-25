import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/remote/api_client.dart';
import 'package:relay/core/remote/sync/workspace_sync_service.dart';

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

WorkspaceSyncService _serviceWith(ResponseBody Function(RequestOptions options) respond) {
  final dio = Dio(BaseOptions(baseUrl: 'https://role.example.com/api/v1'))..httpClientAdapter = _ScriptedAdapter(respond);
  return WorkspaceSyncService(RemoteApiClient(baseUrl: 'https://role.example.com', dio: dio));
}

void main() {
  group('fetchUpdates', () {
    test('collects the distinct entity names touched and the next cursor', () async {
      final service = _serviceWith(
        (options) => _jsonBody({
          'success': true,
          'data': {
            'items': [
              {'id': 101, 'entity': 'collection_endpoint', 'action': 'updated', 'entityId': 5},
              {'id': 102, 'entity': 'collection_endpoint', 'action': 'updated', 'entityId': 6},
            ],
            'cursor': {'next': 102, 'hasMore': false},
          },
        }, 200),
      );

      final page = await service.fetchUpdates(1, since: 0);
      expect(page.entities, {'collection_endpoint'});
      expect(page.nextCursor, 102);
      expect(page.hasMore, isFalse);
    });

    test('an empty page keeps the cursor unchanged', () async {
      final service = _serviceWith(
        (options) => _jsonBody({
          'success': true,
          'data': {
            'items': [],
            'cursor': {'next': 5, 'hasMore': false},
          },
        }, 200),
      );

      final page = await service.fetchUpdates(1, since: 5);
      expect(page.entities, isEmpty);
      expect(page.nextCursor, 5);
    });
  });

  group('fetchCollections', () {
    test('fetches the collection list then each collection\'s endpoints', () async {
      final calls = <String>[];
      final service = _serviceWith((options) {
        calls.add(options.path);
        if (options.path.endsWith('/collections')) {
          return _jsonBody({
            'success': true,
            'data': {
              'items': [
                {'id': 7, 'name': 'Orders API', 'description': '', 'createdAt': '2026-01-01T10:00:00.000Z', 'updatedAt': '2026-01-01T10:00:00.000Z'},
              ],
            },
          }, 200);
        }
        return _jsonBody({
          'success': true,
          'data': {
            'items': [
              {
                'id': 42,
                'name': 'Get Orders',
                'method': 'GET',
                'url': 'https://api.example.com/orders',
                'headers': [],
                'queryParams': [],
                'body': null,
                'auth': null,
                'createdAt': '2026-01-01T10:00:00.000Z',
                'updatedAt': '2026-01-01T10:00:00.000Z',
              },
            ],
          },
        }, 200);
      });

      final bundles = await service.fetchCollections(1);
      expect(bundles, hasLength(1));
      expect(bundles.single.collection.name, 'Orders API');
      expect(bundles.single.requests.single.name, 'Get Orders');
      expect(bundles.single.requests.single.collectionId, bundles.single.collection.id);
      expect(calls, ['/workspaces/1/collections', '/workspaces/1/collections/7/endpoints']);
    });
  });

  group('fetchEnvironments', () {
    test('fetches the environment list then each environment\'s variables', () async {
      final calls = <String>[];
      final service = _serviceWith((options) {
        calls.add(options.path);
        if (options.path.endsWith('/environments')) {
          return _jsonBody({
            'success': true,
            'data': {
              'items': [
                {'id': 3, 'name': 'Staging', 'createdAt': '2026-01-01T10:00:00.000Z', 'updatedAt': '2026-01-01T10:00:00.000Z'},
              ],
            },
          }, 200);
        }
        return _jsonBody({
          'success': true,
          'data': {
            'items': [
              {'id': 9, 'key': 'apiUrl', 'value': 'https://api.example.com', 'enabled': true, 'isSecret': false, 'position': 0},
            ],
          },
        }, 200);
      });

      final environments = await service.fetchEnvironments(1);
      expect(environments, hasLength(1));
      expect(environments.single.name, 'Staging');
      expect(environments.single.variables.single.key, 'apiUrl');
      expect(calls, ['/workspaces/1/environments', '/workspaces/1/environments/3/variables']);
    });
  });
}
