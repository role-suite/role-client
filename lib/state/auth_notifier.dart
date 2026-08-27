import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/models/auth_session.dart';
import '../core/models/auth_user.dart';
import '../core/models/remote_workspace.dart';
import '../core/remote/api_client.dart';
import '../core/remote/auth/auth_interceptor.dart';
import '../core/remote/auth/auth_state.dart';
import '../core/remote/auth/token_store.dart';
import '../core/remote/workspace_permissions.dart';
import '../core/utils/logger.dart';

/// Wraps `POST /api/v1/auth/{register,login,refresh,logout}` and
/// `GET /api/v1/auth/me` per §4 of docs/08-ONLINE-MODE-INTEGRATION.md.
/// Nothing here is called unless a user explicitly opens sign-in — a
/// local-only user never triggers this notifier's build() to do anything but
/// return [AuthSignedOut] and attach an (unused) interceptor.
class AuthNotifier extends Notifier<AuthState> {
  TokenStorage get _tokenStore => ref.read(tokenStoreProvider);
  RemoteApiClient? _attachedTo;

  @override
  AuthState build() {
    final client = ref.watch(remoteApiClientProvider);
    if (client != null && !identical(client, _attachedTo)) {
      _attachedTo = client;
      client.dio.interceptors.add(
        AuthInterceptor(
          readTokens: _tokenStore.read,
          writeTokens: _tokenStore.write,
          clearTokens: _tokenStore.clear,
          refreshTokens: (refreshToken) => _rawRefresh(client.dio.options.baseUrl, refreshToken),
          onRefreshFailed: () async => state = const AuthSignedOut(),
        ),
      );
    }
    return const AuthSignedOut();
  }

  RemoteApiClient _requireClient() {
    final client = ref.read(remoteApiClientProvider);
    if (client == null) {
      throw StateError('No remote base URL configured; online mode is unavailable.');
    }
    return client;
  }

  /// Re-hydrates state from a previously stored token pair, e.g. on app
  /// launch. No-op if nothing is stored. Never called implicitly — the app
  /// shell calls this once at startup; local-only users never trigger it.
  Future<void> restore() async {
    final tokens = await _tokenStore.read();
    if (tokens == null) return;
    state = const AuthSigningIn();
    try {
      state = await _me();
    } catch (_) {
      // Access token dead and nothing to recover it with right now (no
      // network, no base URL configured anymore, or the refresh itself
      // failed inside the interceptor). Don't dangle the UI in "signing in"
      // forever, and never let a startup hydration failure crash the app.
      state = const AuthSignedOut();
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String accountType,
    String? teamName,
  }) async {
    state = const AuthSigningIn();
    try {
      Log.d('Register request started', tag: 'auth');
      final data = await _requireClient().post(
        '/auth/register',
        data: {'name': name, 'email': email, 'password': password, 'accountType': accountType, 'teamName': ?teamName},
      );
      state = await _applyAuthResponse(Map<String, dynamic>.from(data as Map));
      Log.d('Register succeeded', tag: 'auth');
    } catch (error) {
      Log.e('Register failed', error: error, tag: 'auth');
      state = const AuthSignedOut();
      rethrow;
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AuthSigningIn();
    try {
      Log.d('Login request started', tag: 'auth');
      final data = await _requireClient().post('/auth/login', data: {'email': email, 'password': password});
      state = await _applyAuthResponse(Map<String, dynamic>.from(data as Map));
      Log.d('Login succeeded', tag: 'auth');
    } catch (error) {
      Log.e('Login failed', error: error, tag: 'auth');
      state = const AuthSignedOut();
      rethrow;
    }
  }

  /// Best-effort server-side (role-node treats an invalid/expired refresh
  /// token as an idempotent no-op) — local sign-out must succeed regardless
  /// of network state.
  Future<void> logout() async {
    final tokens = await _tokenStore.read();
    if (tokens != null) {
      try {
        await _requireClient().post('/auth/logout', data: {'refreshToken': tokens.refreshToken});
      } catch (_) {
        // Ignored — see doc comment above.
      }
    }
    await _tokenStore.clear();
    // SyncNotifier itself notices this transition (it watches this state)
    // and clears the outgoing workspace's cache — see SyncNotifier.build().
    state = const AuthSignedOut();
  }

  /// Switches the active workspace a token pair is scoped to. Per role-node's
  /// guide, this revokes the session backing the access token used to call
  /// it and returns a full token-pair replacement — treat it exactly like a
  /// refresh, not an additive change.
  Future<void> switchWorkspace(int workspaceId) async {
    final data = await _requireClient().post('/auth/switch-workspace', data: {'workspaceId': workspaceId});
    state = await _applyAuthResponse(Map<String, dynamic>.from(data as Map));
  }

  /// The caller's active (non-revoked, non-expired) sessions across every
  /// workspace they've logged into — "manage devices" data.
  Future<List<AuthSession>> listSessions() async {
    final data = Map<String, dynamic>.from(await _requireClient().get('/auth/sessions') as Map);
    return (data['items'] as List).map((e) => AuthSession.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Revokes one of the caller's own sessions by id — "sign out that other
  /// device." Revoking the session backing the current token pair does not
  /// invalidate this device's already-issued access token before its
  /// natural (short) expiry, matching role-node's documented behavior.
  Future<void> revokeSession(int sessionId) async {
    await _requireClient().delete('/auth/sessions/$sessionId');
  }

  /// "Sign out everywhere else": revokes every session except the one
  /// backing the current request.
  Future<int> revokeOtherSessions() async {
    final data = Map<String, dynamic>.from(await _requireClient().delete('/auth/sessions') as Map);
    return data['count'] as int? ?? 0;
  }

  Future<AuthState> _me() async {
    final data = await _requireClient().get('/auth/me');
    return _authStateFromResponse(Map<String, dynamic>.from(data as Map));
  }

  Future<AuthState> _applyAuthResponse(Map<String, dynamic> data) async {
    final tokens = Map<String, dynamic>.from(data['tokens'] as Map);
    await _tokenStore.write(TokenPair(accessToken: tokens['accessToken'] as String, refreshToken: tokens['refreshToken'] as String));
    return _authStateFromResponse(data);
  }

  AuthState _authStateFromResponse(Map<String, dynamic> data) {
    final user = AuthUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    final activeWorkspace = RemoteWorkspace.fromJson(Map<String, dynamic>.from(data['workspace'] as Map));
    final memberships = (data['memberships'] as List).map((m) => RemoteWorkspace.fromJson(Map<String, dynamic>.from(m as Map))).toList();
    final workspaces = {activeWorkspace.id: activeWorkspace, for (final m in memberships) m.id: m}.values.toList();
    return AuthSignedIn(user: user, workspaces: workspaces, activeWorkspaceId: activeWorkspace.id);
  }

  /// Used only by [AuthInterceptor] to refresh on a dead access token — a
  /// bare, interceptor-free [Dio] so it can never re-enter the
  /// [QueuedInterceptor] it's refreshing on behalf of.
  static Future<TokenPair> _rawRefresh(String baseUrl, String refreshToken) async {
    final dio = Dio(
      BaseOptions(baseUrl: baseUrl, connectTimeout: AppConstants.defaultConnectTimeout, receiveTimeout: AppConstants.defaultReceiveTimeout),
    );
    try {
      final response = await dio.post('/auth/refresh', data: {'refreshToken': refreshToken});
      final data = Map<String, dynamic>.from(parseEnvelope(response.data) as Map);
      final tokens = Map<String, dynamic>.from(data['tokens'] as Map);
      return TokenPair(accessToken: tokens['accessToken'] as String, refreshToken: tokens['refreshToken'] as String);
    } on DioException catch (error) {
      throw mapDioError(error);
    }
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// The workspace id whose remote cache should be merged into local state, or
/// null when signed out. Drives both `SyncNotifier` (which workspace to poll)
/// and `WorkspaceNotifier`/`EnvironmentsNotifier` (which `remote/<id>/`
/// subtree to read) — see §7 of docs/08-ONLINE-MODE-INTEGRATION.md.
final activeRemoteWorkspaceIdProvider = Provider<int?>((ref) {
  final auth = ref.watch(authNotifierProvider);
  return auth is AuthSignedIn ? auth.activeWorkspaceId : null;
});

final activeRemoteWorkspaceRoleProvider = Provider<String?>((ref) {
  final auth = ref.watch(authNotifierProvider);
  return auth is AuthSignedIn ? auth.activeWorkspace.role : null;
});

final activeRemoteWorkspaceCanWriteProvider = Provider<bool>((ref) {
  final auth = ref.watch(authNotifierProvider);
  if (auth is! AuthSignedIn) return true;
  return canWriteRemoteWorkspaceRole(auth.activeWorkspace.role);
});
