import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/utils/extension.dart';
import 'package:relay/features/home/presentation/providers/home_ui_providers.dart';
import 'package:relay/features/home/presentation/providers/request_providers.dart';

ApiRequestModel _request({required String id, required String collectionId}) {
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
  test('filteredRequestsProvider returns all requests when no collection selected', () async {
    final requests = [_request(id: 'r1', collectionId: 'c1'), _request(id: 'r2', collectionId: 'c2')];

    final container = ProviderContainer(
      overrides: [
        selectedCollectionIdProvider.overrideWith(SelectedCollectionIdNotifier.new),
        requestsNotifierProvider.overrideWith(() => _FakeRequestsNotifier(AsyncData(requests))),
      ],
    );
    addTearDown(container.dispose);

    container.read(selectedCollectionIdProvider.notifier).select(null);
    await container.read(requestsNotifierProvider.future);
    final filtered = container.read(filteredRequestsProvider).requireValue;
    expect(filtered.length, 2);
  });

  test('filteredRequestsProvider returns only selected collection requests', () async {
    final requests = [_request(id: 'r1', collectionId: 'c1'), _request(id: 'r2', collectionId: 'c2'), _request(id: 'r3', collectionId: 'c1')];

    final container = ProviderContainer(overrides: [requestsNotifierProvider.overrideWith(() => _FakeRequestsNotifier(AsyncData(requests)))]);
    addTearDown(container.dispose);

    container.read(selectedCollectionIdProvider.notifier).select('c1');
    await container.read(requestsNotifierProvider.future);
    final filtered = container.read(filteredRequestsProvider).requireValue;
    expect(filtered.map((request) => request.id).toList(), ['r1', 'r3']);
  });
}

class _FakeRequestsNotifier extends RequestsNotifier {
  _FakeRequestsNotifier(this.initial);

  final AsyncValue<List<ApiRequestModel>> initial;

  @override
  Future<List<ApiRequestModel>> build() async {
    return initial.requireValue;
  }
}
