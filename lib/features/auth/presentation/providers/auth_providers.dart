import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/constants/api_style.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/services/relay_api/serverpod_client_provider.dart';
import 'package:relay/features/home/presentation/providers/data_source_providers.dart';
import 'package:relay_server_client/relay_server_client.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

typedef SignInAvailability = ({bool isAvailable, String? baseUrl});

enum ServerpodSignInUiState { unavailable, loading, ready, failed }

enum ServerpodAuthSessionState { unavailable, loading, signedOut, signedIn, failed }

final serverpodSignInAvailabilityProvider = Provider<SignInAvailability>((ref) {
  final state = ref.watch(currentDataSourceStateProvider);
  if (state == null) {
    return (isAvailable: false, baseUrl: null);
  }

  final baseUrl = state.config.baseUrl.trim();
  final isAvailable = state.mode == DataSourceMode.api && state.config.apiStyle == ApiStyle.serverpod && baseUrl.isNotEmpty;

  return (isAvailable: isAvailable, baseUrl: isAvailable ? baseUrl : null);
});

final serverpodSignInClientProvider = FutureProvider<Client?>((ref) async {
  final availability = ref.watch(serverpodSignInAvailabilityProvider);
  final baseUrl = availability.baseUrl;
  if (!availability.isAvailable || baseUrl == null) {
    return null;
  }

  return ref.watch(serverpodClientProvider(baseUrl).future);
});

final serverpodSignInUiStateProvider = Provider<ServerpodSignInUiState>((ref) {
  final availability = ref.watch(serverpodSignInAvailabilityProvider);
  if (!availability.isAvailable) {
    return ServerpodSignInUiState.unavailable;
  }

  final clientAsync = ref.watch(serverpodSignInClientProvider);
  return clientAsync.when(
    data: (client) => client == null ? ServerpodSignInUiState.failed : ServerpodSignInUiState.ready,
    loading: () => ServerpodSignInUiState.loading,
    error: (_, _) => ServerpodSignInUiState.failed,
  );
});

final refreshServerpodSignInClientProvider = Provider<void Function()>((ref) {
  return () => ref.invalidate(serverpodSignInClientProvider);
});

final serverpodAuthInfoStreamProvider = StreamProvider<AuthSuccess?>((ref) async* {
  final client = await ref.watch(serverpodSignInClientProvider.future);
  if (client == null) {
    yield null;
    return;
  }

  final authSessionManager = client.authKeyProvider;
  if (authSessionManager is! FlutterAuthSessionManager) {
    yield null;
    return;
  }

  final controller = StreamController<AuthSuccess?>();

  void onAuthInfoChanged() {
    controller.add(authSessionManager.authInfo);
  }

  authSessionManager.authInfoListenable.addListener(onAuthInfoChanged);
  ref.onDispose(() {
    authSessionManager.authInfoListenable.removeListener(onAuthInfoChanged);
    controller.close();
  });

  yield authSessionManager.authInfo;
  yield* controller.stream;
});

final serverpodAuthSessionStateProvider = Provider<ServerpodAuthSessionState>((ref) {
  final availability = ref.watch(serverpodSignInAvailabilityProvider);
  if (!availability.isAvailable) {
    return ServerpodAuthSessionState.unavailable;
  }

  final authInfoAsync = ref.watch(serverpodAuthInfoStreamProvider);
  return authInfoAsync.when(
    data: (authInfo) => authInfo == null ? ServerpodAuthSessionState.signedOut : ServerpodAuthSessionState.signedIn,
    loading: () => ServerpodAuthSessionState.loading,
    error: (_, _) => ServerpodAuthSessionState.failed,
  );
});

final signOutServerpodCurrentDeviceProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    final client = await ref.read(serverpodSignInClientProvider.future);
    if (client == null) {
      return false;
    }

    final authSessionManager = client.authKeyProvider;
    if (authSessionManager is! FlutterAuthSessionManager) {
      return false;
    }

    final result = await authSessionManager.signOutDevice();
    ref.invalidate(serverpodAuthInfoStreamProvider);
    return result;
  };
});
