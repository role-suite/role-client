import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/utils/extension.dart';
import 'package:relay/features/home/presentation/providers/repository_providers.dart';
import 'package:relay/features/home/request/presentation/providers/request_providers.dart';

import '../test_helpers/fake_home_repositories.dart';

ApiRequestModel _request(String id, {String name = 'request', String collectionId = 'default'}) {
  final now = DateTime.now();
  return ApiRequestModel(
    id: id,
    name: name,
    method: HttpMethod.get,
    urlTemplate: 'https://example.com',
    collectionId: collectionId,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('applyRemoteUpsert initializes state while requests are still loading', () {
    final completer = Completer<List<ApiRequestModel>>();
    final container = ProviderContainer(
      overrides: [
        requestsNotifierProvider.overrideWith(() => _DelayedRequestsNotifier(completer)),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(requestsNotifierProvider.notifier);
    notifier.applyRemoteUpsert(_request('r1', name: 'from-remote'));

    final requests = container.read(requestsNotifierProvider).requireValue;
    expect(requests.map((item) => item.id), ['r1']);

    completer.complete(const []);
  });

  test('applyRemoteUpsert replaces matching request id', () async {
    final container = ProviderContainer(
      overrides: [
        requestRepositoryProvider.overrideWithValue(
          FakeRequestRepository(initialRequests: [_request('r1', name: 'old-name')]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(requestsNotifierProvider.future);
    container.read(requestsNotifierProvider.notifier).applyRemoteUpsert(_request('r1', name: 'new-name'));

    final request = container.read(requestsNotifierProvider).requireValue.single;
    expect(request.name, 'new-name');
  });

  test('applyRemoteDelete removes request from current state', () async {
    final container = ProviderContainer(
      overrides: [
        requestRepositoryProvider.overrideWithValue(
          FakeRequestRepository(initialRequests: [_request('r1'), _request('r2')]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(requestsNotifierProvider.future);
    container.read(requestsNotifierProvider.notifier).applyRemoteDelete('r1');

    final remainingIds = container.read(requestsNotifierProvider).requireValue.map((item) => item.id).toList();
    expect(remainingIds, ['r2']);
  });

  test('replaceFromRemote stores a defensive copy', () async {
    final container = ProviderContainer(
      overrides: [
        requestRepositoryProvider.overrideWithValue(FakeRequestRepository(initialRequests: const [])),
      ],
    );
    addTearDown(container.dispose);

    await container.read(requestsNotifierProvider.future);
    final remoteSnapshot = <ApiRequestModel>[_request('r1')];
    container.read(requestsNotifierProvider.notifier).replaceFromRemote(remoteSnapshot);
    remoteSnapshot.add(_request('r2'));

    final ids = container.read(requestsNotifierProvider).requireValue.map((item) => item.id).toList();
    expect(ids, ['r1']);
  });
}

class _DelayedRequestsNotifier extends RequestsNotifier {
  _DelayedRequestsNotifier(this._completer);

  final Completer<List<ApiRequestModel>> _completer;

  @override
  Future<List<ApiRequestModel>> build() => _completer.future;
}
