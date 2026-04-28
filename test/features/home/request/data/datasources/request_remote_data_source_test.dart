import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/services/relay_api/relay_api_client.dart';
import 'package:relay/core/utils/extension.dart';
import 'package:relay/features/home/request/data/datasources/request_remote_data_source.dart';

void main() {
  group('RequestRemoteDataSource', () {
    test('getAllRequests aggregates requests from all collections', () async {
      final api = _FakeRelayApiClient(
        collections: [_collection('10', 'A'), _collection('20', 'B')],
        requestsByCollection: {
          '10': [_request('r-1', '10')],
          '20': [_request('r-2', '20'), _request('r-3', '20')],
        },
      );
      final dataSource = RequestRemoteDataSource(api);

      final requests = await dataSource.getAllRequests();

      expect(requests.map((r) => r.id), ['r-1', 'r-2', 'r-3']);
      expect(api.listCollectionsCalls, 1);
      expect(api.listRequestsCalls, ['10', '20']);
    });

    test('saveRequest creates when request does not exist', () async {
      final api = _FakeRelayApiClient(getRequestById: {});
      final dataSource = RequestRemoteDataSource(api);
      final request = _request('new-1', '10');

      await dataSource.saveRequest(request);

      expect(api.createRequestCalls, [request]);
      expect(api.updateRequestCalls, isEmpty);
    });

    test('saveRequest updates when request already exists', () async {
      final existing = _request('req-1', '10');
      final api = _FakeRelayApiClient(getRequestById: {'req-1': existing});
      final dataSource = RequestRemoteDataSource(api);
      final updated = existing.copyWith(name: 'Updated name');

      await dataSource.saveRequest(updated);

      expect(api.createRequestCalls, isEmpty);
      expect(api.updateRequestCalls, [updated]);
    });

    test('deleteRequest delegates to api client', () async {
      final api = _FakeRelayApiClient();
      final dataSource = RequestRemoteDataSource(api);

      await dataSource.deleteRequest('r-55');

      expect(api.deleteRequestCalls, ['r-55']);
    });

    test('getAllRequests propagates api errors', () async {
      final api = _FakeRelayApiClient(listCollectionsError: StateError('boom'));
      final dataSource = RequestRemoteDataSource(api);

      expect(() => dataSource.getAllRequests(), throwsA(isA<StateError>()));
    });
  });
}

class _FakeRelayApiClient implements RelayApiClient {
  _FakeRelayApiClient({
    this.collections = const [],
    this.requestsByCollection = const {},
    this.getRequestById = const {},
    this.listCollectionsError,
  });

  final List<CollectionModel> collections;
  final Map<String, List<ApiRequestModel>> requestsByCollection;
  final Map<String, ApiRequestModel> getRequestById;
  final Object? listCollectionsError;

  int listCollectionsCalls = 0;
  final List<String> listRequestsCalls = <String>[];
  final List<ApiRequestModel> createRequestCalls = <ApiRequestModel>[];
  final List<ApiRequestModel> updateRequestCalls = <ApiRequestModel>[];
  final List<String> deleteRequestCalls = <String>[];

  @override
  Future<List<CollectionModel>> listCollections() async {
    listCollectionsCalls += 1;
    if (listCollectionsError != null) {
      throw listCollectionsError!;
    }
    return collections;
  }

  @override
  Future<List<ApiRequestModel>> listRequests(String collectionId) async {
    listRequestsCalls.add(collectionId);
    return requestsByCollection[collectionId] ?? const [];
  }

  @override
  Future<ApiRequestModel?> getRequest(String requestId) async => getRequestById[requestId];

  @override
  Future<void> createRequest(ApiRequestModel request) async {
    createRequestCalls.add(request);
  }

  @override
  Future<void> updateRequest(ApiRequestModel request) async {
    updateRequestCalls.add(request);
  }

  @override
  Future<void> deleteRequest(String requestId) async {
    deleteRequestCalls.add(requestId);
  }

  @override
  Future<void> createCollection(CollectionModel collection) async {}

  @override
  Future<void> createEnvironment(EnvironmentModel environment) async {}

  @override
  Future<void> deleteCollection(String id) async {}

  @override
  Future<void> deleteEnvironment(String name) async {}

  @override
  Future<CollectionModel?> getCollection(String id) async => null;

  @override
  Future<EnvironmentModel?> getEnvironment(String name) async => null;

  @override
  Future<List<EnvironmentModel>> listEnvironments() async => const [];

  @override
  Future<void> updateCollection(CollectionModel collection) async {}

  @override
  Future<void> updateEnvironment(EnvironmentModel environment) async {}
}

CollectionModel _collection(String id, String name) {
  final now = DateTime(2025, 1, 1);
  return CollectionModel(id: id, name: name, createdAt: now, updatedAt: now);
}

ApiRequestModel _request(String id, String collectionId) {
  final now = DateTime(2025, 1, 1);
  return ApiRequestModel(
    id: id,
    name: 'Request $id',
    method: HttpMethod.get,
    urlTemplate: 'https://example.test',
    collectionId: collectionId,
    createdAt: now,
    updatedAt: now,
  );
}
