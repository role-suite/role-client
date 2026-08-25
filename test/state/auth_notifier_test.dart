import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/remote/api_client.dart';
import 'package:relay/core/remote/auth/auth_state.dart';
import 'package:relay/core/remote/auth/token_store.dart';
import 'package:relay/state/auth_notifier.dart';

const _authResponse = {
  'user': {'id': 1, 'name': 'Altay', 'email': 'altay@example.com'},
  'workspace': {'id': 1, 'name': "Altay's Workspace", 'slug': 'altays-workspace', 'type': 'single', 'role': 'owner'},
  'memberships': [
    {'workspaceId': 1, 'name': "Altay's Workspace", 'slug': 'altays-workspace', 'type': 'single', 'role': 'owner'},
    {'workspaceId': 2, 'name': 'Core Team', 'slug': 'core-team', 'type': 'team', 'role': 'member'},
  ],
  'tokens': {'accessToken': 'access-1', 'refreshToken': 'refresh-1', 'accessTokenTtlSeconds': 900, 'refreshTokenTtlSeconds': 2592000},
};

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

class _FakeTokenStorage implements TokenStorage {
  TokenPair? stored;

  @override
  Future<TokenPair?> read() async => stored;

  @override
  Future<void> write(TokenPair tokens) async => stored = tokens;

  @override
  Future<void> clear() async => stored = null;
}

ProviderContainer _containerWithAdapter(ResponseBody Function(RequestOptions options) respond) {
  final dio = Dio(BaseOptions(baseUrl: 'https://role.example.com/api/v1'))..httpClientAdapter = _ScriptedAdapter(respond);
  final client = RemoteApiClient(baseUrl: 'https://role.example.com', dio: dio);
  return ProviderContainer(overrides: [remoteApiClientProvider.overrideWithValue(client), tokenStoreProvider.overrideWithValue(_FakeTokenStorage())]);
}

void main() {
  group('AuthNotifier', () {
    test('login moves signedOut -> signingIn -> signedIn, mapping memberships (workspaceId) and the active workspace (id) alike', () async {
      final container = _containerWithAdapter((options) => _jsonBody({'success': true, 'data': _authResponse}, 200));
      addTearDown(container.dispose);

      expect(container.read(authNotifierProvider), isA<AuthSignedOut>());

      final future = container.read(authNotifierProvider.notifier).login(email: 'altay@example.com', password: 'password123');
      expect(container.read(authNotifierProvider), isA<AuthSigningIn>());

      await future;

      final state = container.read(authNotifierProvider) as AuthSignedIn;
      expect(state.user.email, 'altay@example.com');
      expect(state.activeWorkspaceId, 1);
      expect(state.workspaces.map((w) => w.id), containsAll([1, 2]));
      expect(state.activeWorkspace.slug, 'altays-workspace');
    });

    test('register applies the same AuthResponse shape', () async {
      final container = _containerWithAdapter((options) => _jsonBody({'success': true, 'data': _authResponse}, 200));
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .register(name: 'Altay', email: 'altay@example.com', password: 'password123', accountType: 'single');

      expect(container.read(authNotifierProvider), isA<AuthSignedIn>());
    });

    test('a failed login drops back to signedOut and rethrows', () async {
      final container = _containerWithAdapter(
        (options) => _jsonBody({
          'success': false,
          'error': {'code': 'INVALID_CREDENTIALS', 'message': 'Invalid credentials'},
        }, 401),
      );
      addTearDown(container.dispose);

      await expectLater(container.read(authNotifierProvider.notifier).login(email: 'altay@example.com', password: 'wrong'), throwsA(anything));

      expect(container.read(authNotifierProvider), isA<AuthSignedOut>());
    });

    test('logout clears state even when the server call fails', () async {
      final container = _containerWithAdapter((options) {
        if (options.path.contains('/auth/login')) {
          return _jsonBody({'success': true, 'data': _authResponse}, 200);
        }
        return _jsonBody({
          'success': false,
          'error': {'code': 'UNKNOWN_ERROR', 'message': 'boom'},
        }, 500);
      });
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.login(email: 'altay@example.com', password: 'password123');
      expect(container.read(authNotifierProvider), isA<AuthSignedIn>());

      await notifier.logout();

      expect(container.read(authNotifierProvider), isA<AuthSignedOut>());
    });

    test('switchWorkspace treats the response as a full token/state replacement, scoped to the new workspace', () async {
      final switchedResponse = {
        ..._authResponse,
        'workspace': {'id': 2, 'name': 'Core Team', 'slug': 'core-team', 'type': 'team', 'role': 'member'},
        'tokens': {'accessToken': 'access-2', 'refreshToken': 'refresh-2', 'accessTokenTtlSeconds': 900, 'refreshTokenTtlSeconds': 2592000},
      };
      final container = _containerWithAdapter((options) {
        if (options.path.contains('switch-workspace')) {
          return _jsonBody({'success': true, 'data': switchedResponse}, 200);
        }
        return _jsonBody({'success': true, 'data': _authResponse}, 200);
      });
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      await notifier.login(email: 'altay@example.com', password: 'password123');
      await notifier.switchWorkspace(2);

      final state = container.read(authNotifierProvider) as AuthSignedIn;
      expect(state.activeWorkspaceId, 2);
      expect(state.activeWorkspace.slug, 'core-team');
    });

    test('listSessions parses the items envelope, revokeSession/revokeOtherSessions hit the right routes', () async {
      final calls = <String>[];
      final container = _containerWithAdapter((options) {
        calls.add('${options.method} ${options.path}');
        if (options.path.endsWith('/auth/sessions') && options.method == 'GET') {
          return _jsonBody({
            'success': true,
            'data': {
              'items': [
                {
                  'id': 12,
                  'workspaceId': 1,
                  'workspaceName': "Altay's Workspace",
                  'workspaceSlug': 'altays-workspace',
                  'createdAt': '2026-08-24T10:00:00.000Z',
                  'expiresAt': '2026-08-31T10:00:00.000Z',
                  'current': true,
                },
              ],
            },
          }, 200);
        }
        if (options.path.endsWith('/auth/sessions') && options.method == 'DELETE') {
          return _jsonBody({
            'success': true,
            'data': {'action': 'revoked', 'count': 3},
          }, 200);
        }
        return _jsonBody({
          'success': true,
          'data': {'action': 'revoked'},
        }, 200);
      });
      addTearDown(container.dispose);

      final notifier = container.read(authNotifierProvider.notifier);
      final sessions = await notifier.listSessions();
      expect(sessions, hasLength(1));
      expect(sessions.single.current, isTrue);
      expect(sessions.single.workspaceSlug, 'altays-workspace');

      await notifier.revokeSession(12);
      expect(calls, contains('DELETE /auth/sessions/12'));

      final revokedCount = await notifier.revokeOtherSessions();
      expect(revokedCount, 3);
    });

    test('restore() never throws when tokens exist but online mode is unconfigured (StateError from _requireClient)', () async {
      final container = ProviderContainer(
        overrides: [
          remoteApiClientProvider.overrideWithValue(null),
          tokenStoreProvider.overrideWithValue(_FakeTokenStorage()..stored = const TokenPair(accessToken: 'a', refreshToken: 'r')),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).restore();

      expect(container.read(authNotifierProvider), isA<AuthSignedOut>());
    });
  });
}
