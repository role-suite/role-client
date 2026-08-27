import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../utils/logger.dart';

class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// Read/write/clear the access+refresh token pair. Abstracted from
/// [SecureTokenStore] so [AuthNotifier] and [AuthInterceptor] are testable
/// without a real secure-storage platform channel.
abstract class TokenStorage {
  Future<TokenPair?> read();
  Future<void> write(TokenPair tokens);
  Future<void> clear();
}

/// Access/refresh tokens are secrets and must never go through
/// `shared_preferences` or `JsonStore` (both plaintext on disk) — this is the
/// Keychain/Keystore/DPAPI-backed store instead. See §4 of
/// docs/08-ONLINE-MODE-INTEGRATION.md.
class SecureTokenStore implements TokenStorage {
  SecureTokenStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'auth.accessToken';
  static const _refreshTokenKey = 'auth.refreshToken';

  @override
  Future<TokenPair?> read() async {
    Log.d('Reading token pair', tag: 'auth-store');
    final accessToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (accessToken == null || refreshToken == null) {
      Log.d('No complete token pair found', tag: 'auth-store');
      return null;
    }
    Log.d('Token pair found', tag: 'auth-store');
    return TokenPair(accessToken: accessToken, refreshToken: refreshToken);
  }

  @override
  Future<void> write(TokenPair tokens) async {
    Log.d('Writing token pair', tag: 'auth-store');
    await _storage.write(key: _accessTokenKey, value: tokens.accessToken);
    await _storage.write(key: _refreshTokenKey, value: tokens.refreshToken);
    Log.d('Token pair written', tag: 'auth-store');
  }

  @override
  Future<void> clear() async {
    Log.d('Clearing token pair', tag: 'auth-store');
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    Log.d('Token pair cleared', tag: 'auth-store');
  }
}

final tokenStoreProvider = Provider<TokenStorage>((ref) => SecureTokenStore());
