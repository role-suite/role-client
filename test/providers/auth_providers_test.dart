import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/constants/api_style.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/models/data_source_config.dart';
import 'package:relay/features/auth/presentation/providers/auth_providers.dart';
import 'package:relay/features/home/presentation/providers/data_source_providers.dart';
import 'package:relay_server_client/relay_server_client.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

void main() {
  test('sign-in availability is false when data source state is unavailable', () {
    final container = ProviderContainer(overrides: [currentDataSourceStateProvider.overrideWith((ref) => null)]);
    addTearDown(container.dispose);

    final availability = container.read(serverpodSignInAvailabilityProvider);
    expect(availability.isAvailable, isFalse);
    expect(availability.baseUrl, isNull);
  });

  test('sign-in availability is true for API + Serverpod + baseUrl', () {
    final state = (mode: DataSourceMode.api, config: const DataSourceConfig(baseUrl: 'http://localhost:8080', apiStyle: ApiStyle.serverpod));

    final container = ProviderContainer(overrides: [currentDataSourceStateProvider.overrideWith((ref) => state)]);
    addTearDown(container.dispose);

    final availability = container.read(serverpodSignInAvailabilityProvider);
    expect(availability.isAvailable, isTrue);
    expect(availability.baseUrl, 'http://localhost:8080');
  });

  test('ui state is unavailable when sign-in is not available', () {
    final state = (mode: DataSourceMode.local, config: const DataSourceConfig(baseUrl: '', apiStyle: ApiStyle.rest));

    final container = ProviderContainer(overrides: [currentDataSourceStateProvider.overrideWith((ref) => state)]);
    addTearDown(container.dispose);

    expect(container.read(serverpodSignInUiStateProvider), ServerpodSignInUiState.unavailable);
  });

  test('ui state is loading while sign-in client resolves', () {
    final state = (mode: DataSourceMode.api, config: const DataSourceConfig(baseUrl: 'http://localhost:8080', apiStyle: ApiStyle.serverpod));
    final completer = Completer<Client?>();

    final container = ProviderContainer(
      overrides: [currentDataSourceStateProvider.overrideWith((ref) => state), serverpodSignInClientProvider.overrideWith((ref) => completer.future)],
    );
    addTearDown(() {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      container.dispose();
    });

    expect(container.read(serverpodSignInUiStateProvider), ServerpodSignInUiState.loading);
  });

  test('ui state is ready when sign-in client is available', () async {
    final state = (mode: DataSourceMode.api, config: const DataSourceConfig(baseUrl: 'http://localhost:8080', apiStyle: ApiStyle.serverpod));

    final container = ProviderContainer(
      overrides: [
        currentDataSourceStateProvider.overrideWith((ref) => state),
        serverpodSignInClientProvider.overrideWith((ref) async => Client('http://localhost:8080')),
      ],
    );
    addTearDown(container.dispose);

    await container.read(serverpodSignInClientProvider.future);

    expect(container.read(serverpodSignInUiStateProvider), ServerpodSignInUiState.ready);
  });

  test('ui state is failed when sign-in client resolves to null', () async {
    final state = (mode: DataSourceMode.api, config: const DataSourceConfig(baseUrl: 'http://localhost:8080', apiStyle: ApiStyle.serverpod));

    final container = ProviderContainer(
      overrides: [currentDataSourceStateProvider.overrideWith((ref) => state), serverpodSignInClientProvider.overrideWith((ref) async => null)],
    );
    addTearDown(container.dispose);

    await container.read(serverpodSignInClientProvider.future);

    expect(container.read(serverpodSignInUiStateProvider), ServerpodSignInUiState.failed);
  });

  test('auth session state resolves to signedOut when auth stream returns null', () async {
    final state = (mode: DataSourceMode.api, config: const DataSourceConfig(baseUrl: 'http://localhost:8080', apiStyle: ApiStyle.serverpod));

    final container = ProviderContainer(
      overrides: [
        currentDataSourceStateProvider.overrideWith((ref) => state),
        serverpodAuthInfoStreamProvider.overrideWithValue(const AsyncData(null)),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(serverpodAuthSessionStateProvider), ServerpodAuthSessionState.signedOut);
  });

  test('auth session state resolves to signedIn when auth info exists', () async {
    final state = (mode: DataSourceMode.api, config: const DataSourceConfig(baseUrl: 'http://localhost:8080', apiStyle: ApiStyle.serverpod));
    final authSuccess = AuthSuccess.fromJson({
      'authStrategy': 'session',
      'token': 'token',
      'authUserId': '550e8400-e29b-41d4-a716-446655440000',
      'scopeNames': <String>[],
    });

    final container = ProviderContainer(
      overrides: [
        currentDataSourceStateProvider.overrideWith((ref) => state),
        serverpodAuthInfoStreamProvider.overrideWithValue(AsyncData(authSuccess)),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(serverpodAuthSessionStateProvider), ServerpodAuthSessionState.signedIn);
  });
}
