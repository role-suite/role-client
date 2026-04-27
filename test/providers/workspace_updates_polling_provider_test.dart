import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/services/relay_api/workspace_updates_api_client.dart';
import 'package:relay/core/services/relay_api/relay_api_client.dart';
import 'package:relay/core/services/relay_api/relay_api_http.dart';
import 'package:relay/features/home/presentation/providers/data_source_providers.dart';
import 'package:relay/features/home/presentation/providers/repository_providers.dart';
import 'package:relay/features/home/presentation/providers/workspace_updates_polling_provider.dart';
import 'package:relay/features/home/request/presentation/providers/request_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers/fake_home_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CollectionModel collection(String id, String name) {
    final now = DateTime.now();
    return CollectionModel(id: id, name: name, createdAt: now, updatedAt: now);
  }

  test('polling advances cursor and de-duplicates event ids', () async {
    SharedPreferences.setMockInitialValues({
      'data_source_mode': DataSourceMode.api.name,
      'data_source_api_base_url': 'https://example.test',
      'data_source_api_key': 'token-1',
    });

    final fakeApi = _FakeRelayApiClient();
    final fakeHttp = _FakeWorkspaceUpdatesHttp(
      workspaceId: '101',
      updatesBySince: {
        0: {
          'events': [
            {
              'id': 'evt-1',
              'type': 'request.created',
              'data': {'id': 'r-1', 'name': 'Users', 'method': 'GET', 'url': 'https://api.example.test/users', 'collectionId': '10'},
            },
          ],
          'cursor': {'next': 1},
        },
        1: {
          'events': [
            {
              'id': 'evt-1',
              'type': 'request.created',
              'data': {'id': 'r-1', 'name': 'Users', 'method': 'GET', 'url': 'https://api.example.test/users', 'collectionId': '10'},
            },
          ],
          'cursor': {'next': 2},
        },
      },
    );

    final container = ProviderContainer(
      overrides: [
        activeRelayApiClientProvider.overrideWithValue(fakeApi),
        workspaceUpdatesApiFactoryProvider.overrideWith((ref) {
          return (baseUrl, accessToken, workspaceId) => fakeHttp;
        }),
        workspaceUpdatesPollIntervalProvider.overrideWith((ref) => const Duration(milliseconds: 30)),
        workspaceUpdatesInitialDelayProvider.overrideWith((ref) => const Duration(milliseconds: 1)),
        workspaceUpdatesOfflineProbeIntervalProvider.overrideWith((ref) => const Duration(milliseconds: 20)),
        workspaceUpdatesObserveLifecycleProvider.overrideWith((ref) => false),
        collectionRepositoryProvider.overrideWithValue(FakeCollectionRepository(initialCollections: [collection('10', 'Default')])),
        requestRepositoryProvider.overrideWithValue(FakeRequestRepository(initialRequests: const [])),
        environmentRepositoryProvider.overrideWithValue(FakeEnvironmentRepository(initialEnvironments: const [])),
      ],
    );
    addTearDown(container.dispose);

    await container.read(dataSourceStateNotifierProvider.future);
    await container.read(requestsNotifierProvider.future);
    container.read(workspaceUpdatesPollingProvider);

    await _waitForCondition(() => fakeHttp.sinceHistory.contains(1));

    expect(fakeHttp.sinceHistory.isNotEmpty, isTrue);
    expect(fakeHttp.sinceHistory.first, 0);
    expect(fakeHttp.sinceHistory.contains(1), isTrue);

    final requests = container.read(requestsNotifierProvider).requireValue;
    expect(requests.length, 1);
    expect(requests.first.id, 'r-1');
  });

  test('polling stops and falls back to local mode on 401', () async {
    SharedPreferences.setMockInitialValues({
      'data_source_mode': DataSourceMode.api.name,
      'data_source_api_base_url': 'https://example.test',
      'data_source_api_key': 'token-401',
      'data_source_api_refresh_token': 'refresh-1',
    });

    final fakeApi = _FakeRelayApiClient();
    final fakeHttp = _FakeWorkspaceUpdatesHttp(workspaceId: '101', failUnauthorized: true);

    final container = ProviderContainer(
      overrides: [
        activeRelayApiClientProvider.overrideWithValue(fakeApi),
        workspaceUpdatesApiFactoryProvider.overrideWith((ref) {
          return (baseUrl, accessToken, workspaceId) => fakeHttp;
        }),
        workspaceUpdatesPollIntervalProvider.overrideWith((ref) => const Duration(milliseconds: 20)),
        workspaceUpdatesInitialDelayProvider.overrideWith((ref) => const Duration(milliseconds: 1)),
        workspaceUpdatesObserveLifecycleProvider.overrideWith((ref) => false),
      ],
    );
    addTearDown(container.dispose);

    await container.read(dataSourceStateNotifierProvider.future);
    container.read(workspaceUpdatesPollingProvider);

    await _waitForCondition(() => fakeHttp.updatesCalls > 0);
    await _waitForCondition(() => container.read(currentDataSourceStateProvider)?.mode == DataSourceMode.local);

    final stateAfter401 = container.read(currentDataSourceStateProvider);
    expect(stateAfter401, isNotNull);
    expect(stateAfter401!.mode, DataSourceMode.local);
    expect(stateAfter401.config.apiKey, isNull);

    final callsAfterFallback = fakeHttp.updatesCalls;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(fakeHttp.updatesCalls, callsAfterFallback);
  });
}

Future<void> _waitForCondition(bool Function() condition, {Duration timeout = const Duration(seconds: 2)}) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < timeout) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw TimeoutException('Condition was not met within $timeout');
}

class _FakeWorkspaceUpdatesHttp implements WorkspaceUpdatesApi {
  _FakeWorkspaceUpdatesHttp({required this.workspaceId, this.updatesBySince = const {}, this.failUnauthorized = false});

  final String workspaceId;
  final Map<int, Map<String, dynamic>> updatesBySince;
  final bool failUnauthorized;
  final List<int> sinceHistory = <int>[];
  int updatesCalls = 0;

  @override
  Future<Map<String, dynamic>> getUpdates({required String workspaceId, required int since, required int limit}) async {
    updatesCalls += 1;
    if (failUnauthorized) {
      throw RelayApiException('Unauthorized', statusCode: 401);
    }
    sinceHistory.add(since);
    return updatesBySince[since] ??
        {
          'events': const [],
          'cursor': {'next': since},
        };
  }

  @override
  Future<String> resolveWorkspaceId() async => workspaceId;
}

class _FakeRelayApiClient implements RelayApiClient {
  @override
  Future<void> createCollection(CollectionModel collection) async {}

  @override
  Future<void> createEnvironment(EnvironmentModel environment) async {}

  @override
  Future<void> createRequest(ApiRequestModel request) async {}

  @override
  Future<void> deleteCollection(String id) async {}

  @override
  Future<void> deleteEnvironment(String name) async {}

  @override
  Future<void> deleteRequest(String requestId) async {}

  @override
  Future<CollectionModel?> getCollection(String id) async => null;

  @override
  Future<EnvironmentModel?> getEnvironment(String name) async => null;

  @override
  Future<ApiRequestModel?> getRequest(String requestId) async => null;

  @override
  Future<List<CollectionModel>> listCollections() async => const [];

  @override
  Future<List<EnvironmentModel>> listEnvironments() async => const [];

  @override
  Future<List<ApiRequestModel>> listRequests(String collectionId) async => const [];

  @override
  Future<void> updateCollection(CollectionModel collection) async {}

  @override
  Future<void> updateEnvironment(EnvironmentModel environment) async {}

  @override
  Future<void> updateRequest(ApiRequestModel request) async {}
}
