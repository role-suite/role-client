import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/services/relay_api/relay_api_client.dart';
import 'package:relay/features/home/collection/data/datasources/collection_remote_data_source.dart';

void main() {
  group('CollectionRemoteDataSource', () {
    test('getCollectionByName returns matching collection and null otherwise', () async {
      final api = _FakeRelayApiClient(collections: [_collection('1', 'Default'), _collection('2', 'Users')]);
      final dataSource = CollectionRemoteDataSource(api);

      final found = await dataSource.getCollectionByName('Users');
      final missing = await dataSource.getCollectionByName('Missing');

      expect(found?.id, '2');
      expect(missing, isNull);
    });

    test('saveCollection creates collection when id is not persisted api id', () async {
      final api = _FakeRelayApiClient();
      final dataSource = CollectionRemoteDataSource(api);
      final collection = _collection('tmp-local', 'Draft');

      await dataSource.saveCollection(collection);

      expect(api.createCollectionCalls, [collection]);
      expect(api.getCollectionCalls, isEmpty);
      expect(api.updateCollectionCalls, isEmpty);
    });

    test('saveCollection creates collection when numeric id is missing remotely', () async {
      final api = _FakeRelayApiClient(collectionById: {});
      final dataSource = CollectionRemoteDataSource(api);
      final collection = _collection('12', 'Users');

      await dataSource.saveCollection(collection);

      expect(api.getCollectionCalls, ['12']);
      expect(api.createCollectionCalls, [collection]);
      expect(api.updateCollectionCalls, isEmpty);
    });

    test('saveCollection updates collection when numeric id exists remotely', () async {
      final existing = _collection('77', 'Users');
      final api = _FakeRelayApiClient(collectionById: {'77': existing});
      final dataSource = CollectionRemoteDataSource(api);
      final updated = existing.copyWith(description: 'updated');

      await dataSource.saveCollection(updated);

      expect(api.getCollectionCalls, ['77']);
      expect(api.createCollectionCalls, isEmpty);
      expect(api.updateCollectionCalls, [updated]);
    });

    test('deleteCollection rejects default collection id', () async {
      final api = _FakeRelayApiClient();
      final dataSource = CollectionRemoteDataSource(api);

      expect(() => dataSource.deleteCollection('default'), throwsArgumentError);
      expect(api.deleteCollectionCalls, isEmpty);
    });

    test('collectionExists reflects getCollectionByName result', () async {
      final api = _FakeRelayApiClient(collections: [_collection('1', 'Main')]);
      final dataSource = CollectionRemoteDataSource(api);

      final exists = await dataSource.collectionExists('Main');
      final missing = await dataSource.collectionExists('Unknown');

      expect(exists, isTrue);
      expect(missing, isFalse);
    });

    test('getAllCollections propagates api errors', () async {
      final api = _FakeRelayApiClient(listCollectionsError: StateError('unavailable'));
      final dataSource = CollectionRemoteDataSource(api);

      expect(() => dataSource.getAllCollections(), throwsA(isA<StateError>()));
    });
  });
}

class _FakeRelayApiClient implements RelayApiClient {
  _FakeRelayApiClient({
    this.collections = const [],
    this.collectionById = const {},
    this.listCollectionsError,
  });

  final List<CollectionModel> collections;
  final Map<String, CollectionModel> collectionById;
  final Object? listCollectionsError;

  final List<String> getCollectionCalls = <String>[];
  final List<CollectionModel> createCollectionCalls = <CollectionModel>[];
  final List<CollectionModel> updateCollectionCalls = <CollectionModel>[];
  final List<String> deleteCollectionCalls = <String>[];

  @override
  Future<List<CollectionModel>> listCollections() async {
    if (listCollectionsError != null) {
      throw listCollectionsError!;
    }
    return collections;
  }

  @override
  Future<CollectionModel?> getCollection(String id) async {
    getCollectionCalls.add(id);
    return collectionById[id];
  }

  @override
  Future<void> createCollection(CollectionModel collection) async {
    createCollectionCalls.add(collection);
  }

  @override
  Future<void> updateCollection(CollectionModel collection) async {
    updateCollectionCalls.add(collection);
  }

  @override
  Future<void> deleteCollection(String id) async {
    deleteCollectionCalls.add(id);
  }

  @override
  Future<void> createEnvironment(EnvironmentModel environment) async {}

  @override
  Future<void> createRequest(ApiRequestModel request) async {}

  @override
  Future<void> deleteEnvironment(String name) async {}

  @override
  Future<void> deleteRequest(String requestId) async {}

  @override
  Future<EnvironmentModel?> getEnvironment(String name) async => null;

  @override
  Future<ApiRequestModel?> getRequest(String requestId) async => null;

  @override
  Future<List<EnvironmentModel>> listEnvironments() async => const [];

  @override
  Future<List<ApiRequestModel>> listRequests(String collectionId) async => const [];

  @override
  Future<void> updateEnvironment(EnvironmentModel environment) async {}

  @override
  Future<void> updateRequest(ApiRequestModel request) async {}
}

CollectionModel _collection(String id, String name) {
  final now = DateTime(2025, 1, 1);
  return CollectionModel(id: id, name: name, createdAt: now, updatedAt: now);
}
