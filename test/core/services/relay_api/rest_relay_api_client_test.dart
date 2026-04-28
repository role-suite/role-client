import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/request_enums.dart';
import 'package:relay/core/services/relay_api/relay_api_http.dart';
import 'package:relay/core/services/relay_api/rest_relay_api_client.dart';
import 'package:relay/core/utils/extension.dart';

void main() {
  group('RestRelayApiClient', () {
    late _TestApiServer server;

    setUp(() async {
      server = await _TestApiServer.start();
    });

    tearDown(() async {
      await server.close();
    });

    test('listCollections maps and sorts collections by name', () async {
      server.on('GET', '/api/workspaces/ws-1/collections', (request) {
        return _JsonResponse.ok({
          'success': true,
          'data': [
            {'id': '2', 'name': 'zeta', 'description': 'second'},
            {'id': '1', 'name': 'Alpha', 'description': 'first'},
          ],
        });
      });

      final client = RestRelayApiClient(baseUrl: server.baseUrl, workspaceId: 'ws-1');

      final collections = await client.listCollections();

      expect(collections.map((c) => c.id), ['1', '2']);
      expect(collections.map((c) => c.name), ['Alpha', 'zeta']);
      expect(collections.first.description, 'first');
    });

    test('listCollections returns empty list when payload shape is malformed', () async {
      server.on('GET', '/api/workspaces/ws-1/collections', (request) {
        return _JsonResponse.ok({'success': true, 'data': 'not-a-list'});
      });

      final client = RestRelayApiClient(baseUrl: server.baseUrl, workspaceId: 'ws-1');

      final collections = await client.listCollections();

      expect(collections, isEmpty);
    });

    test('getCollection returns null when API returns non-object data', () async {
      server.on('GET', '/api/workspaces/ws-1/collections/99', (request) {
        return _JsonResponse.ok({'success': true, 'data': ['unexpected']});
      });

      final client = RestRelayApiClient(baseUrl: server.baseUrl, workspaceId: 'ws-1');

      final collection = await client.getCollection('99');

      expect(collection, isNull);
    });

    test('createRequest sends transformed API payload', () async {
      server.on('POST', '/api/workspaces/ws-1/collections/10/endpoints', (request) {
        return _JsonResponse.ok({'success': true, 'data': {'id': 'created'}});
      });

      final client = RestRelayApiClient(baseUrl: server.baseUrl, workspaceId: 'ws-1');
      final now = DateTime(2025, 1, 1);
      final request = ApiRequestModel(
        id: 'r-1',
        name: 'Create User',
        method: HttpMethod.post,
        urlTemplate: 'https://api.example.com/users',
        headers: {'Content-Type': 'application/json', 'X-Trace': 'abc'},
        queryParams: {'include': 'profile'},
        body: '{"name":"Jane"}',
        bodyType: BodyType.raw,
        authType: AuthType.bearer,
        authConfig: {AuthConfigKeys.token: 'token-123'},
        collectionId: '10',
        createdAt: now,
        updatedAt: now,
      );

      await client.createRequest(request);

      final captured = server.requests.singleWhere((r) => r.method == 'POST' && r.path == '/api/workspaces/ws-1/collections/10/endpoints');
      final payload = captured.jsonBody as Map<String, dynamic>;
      final body = payload['body'] as Map<String, dynamic>;
      final auth = payload['auth'] as Map<String, dynamic>;

      expect(payload['name'], 'Create User');
      expect(payload['method'], 'POST');
      expect(payload['url'], 'https://api.example.com/users');
      expect(body['mode'], 'raw');
      expect(body['raw'], '{"name":"Jane"}');
      expect(body['contentType'], 'application/json');
      expect(auth, {'type': 'bearer', 'token': 'token-123'});
    });

    test('listCollections throws RelayApiException on HTTP errors', () async {
      server.on('GET', '/api/workspaces/ws-1/collections', (request) {
        return _JsonResponse(statusCode: 500, body: {'message': 'server exploded'});
      });

      final client = RestRelayApiClient(baseUrl: server.baseUrl, workspaceId: 'ws-1');

      expect(
        () => client.listCollections(),
        throwsA(
          isA<RelayApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message', contains('server exploded')),
        ),
      );
    });
  });
}

class _TestApiServer {
  _TestApiServer._(this._server);

  final HttpServer _server;
  final Map<String, _RouteHandler> _handlers = <String, _RouteHandler>{};
  final List<_CapturedRequest> requests = <_CapturedRequest>[];

  String get baseUrl => 'http://${_server.address.host}:${_server.port}';

  static Future<_TestApiServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final testServer = _TestApiServer._(server);
    unawaited(testServer._listen());
    return testServer;
  }

  void on(String method, String path, _RouteHandler handler) {
    _handlers[_key(method, path)] = handler;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _listen() async {
    await for (final request in _server) {
      final bodyText = await utf8.decoder.bind(request).join();
      dynamic parsedBody;
      if (bodyText.isNotEmpty) {
        try {
          parsedBody = jsonDecode(bodyText);
        } catch (_) {
          parsedBody = bodyText;
        }
      }

      requests.add(
        _CapturedRequest(
          method: request.method,
          path: request.uri.path,
          jsonBody: parsedBody,
        ),
      );

      final handler = _handlers[_key(request.method, request.uri.path)];
      final response = handler?.call(request) ?? _JsonResponse(statusCode: 404, body: {'message': 'missing route'});

      request.response.statusCode = response.statusCode;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response.body));
      await request.response.close();
    }
  }

  String _key(String method, String path) => '${method.toUpperCase()} $path';
}

typedef _RouteHandler = _JsonResponse Function(HttpRequest request);

class _JsonResponse {
  const _JsonResponse({required this.statusCode, required this.body});

  final int statusCode;
  final dynamic body;

  factory _JsonResponse.ok(dynamic body) => _JsonResponse(statusCode: 200, body: body);
}

class _CapturedRequest {
  const _CapturedRequest({required this.method, required this.path, required this.jsonBody});

  final String method;
  final String path;
  final dynamic jsonBody;
}
