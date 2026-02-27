import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/utils/extension.dart';
import 'package:relay/features/home/presentation/providers/collection_providers.dart';
import 'package:relay/features/home/presentation/providers/environment_providers.dart';
import 'package:relay/features/home/presentation/providers/repository_providers.dart';
import 'package:relay/features/home/presentation/providers/request_providers.dart';

import '../test_helpers/fake_home_repositories.dart';

CollectionModel _collection(String id, String name) {
  final now = DateTime.now();
  return CollectionModel(id: id, name: name, createdAt: now, updatedAt: now);
}

ApiRequestModel _request(String id, String collectionId) {
  final now = DateTime.now();
  return ApiRequestModel(
    id: id,
    name: id,
    method: HttpMethod.get,
    urlTemplate: 'https://example.com',
    collectionId: collectionId,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('collections notifier loads initial collections', () async {
    final collectionRepo = FakeCollectionRepository(initialCollections: [_collection('c1', 'Default')]);

    final container = ProviderContainer(overrides: [collectionRepositoryProvider.overrideWithValue(collectionRepo)]);
    addTearDown(container.dispose);

    final collections = await container.read(collectionsNotifierProvider.future);
    expect(collections.map((item) => item.id), ['c1']);
  });

  test('collections notifier becomes error when loading fails', () async {
    final collectionRepo = FakeCollectionRepository(throwOnGetAll: true);

    final container = ProviderContainer(overrides: [collectionRepositoryProvider.overrideWithValue(collectionRepo)]);
    addTearDown(container.dispose);

    final didError = Completer<void>();
    final subscription = container.listen<AsyncValue<List<CollectionModel>>>(collectionsNotifierProvider, (previous, next) {
      if (!didError.isCompleted && next.hasError) {
        didError.complete();
      }
    }, fireImmediately: true);
    addTearDown(subscription.close);

    await didError.future.timeout(const Duration(seconds: 3));
    expect(container.read(collectionsNotifierProvider).hasError, isTrue);
  });

  test('requests notifier addRequest updates state', () async {
    final requestRepo = FakeRequestRepository(initialRequests: [_request('r1', 'c1')]);

    final container = ProviderContainer(overrides: [requestRepositoryProvider.overrideWithValue(requestRepo)]);
    addTearDown(container.dispose);

    await container.read(requestsNotifierProvider.future);
    await container.read(requestsNotifierProvider.notifier).addRequest(_request('r2', 'c1'));

    final requests = container.read(requestsNotifierProvider).requireValue;
    expect(requests.map((item) => item.id), ['r1', 'r2']);
  });

  test('environments notifier loads and active environment can be changed', () async {
    final envRepo = FakeEnvironmentRepository(
      initialEnvironments: [
        EnvironmentModel(name: 'dev', variables: {'baseUrl': 'https://dev.example.com'}),
        EnvironmentModel(name: 'prod', variables: {'baseUrl': 'https://prod.example.com'}),
      ],
    );

    final container = ProviderContainer(overrides: [environmentRepositoryProvider.overrideWithValue(envRepo)]);
    addTearDown(container.dispose);

    final environments = await container.read(environmentsNotifierProvider.future);
    expect(environments.length, 2);

    await container.read(activeEnvironmentNotifierProvider.notifier).setActiveEnvironment('prod');
    final active = await container.read(activeEnvironmentNotifierProvider.future);
    expect(active?.name, 'prod');
  });
}
