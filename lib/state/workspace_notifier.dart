import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/models/api_request.dart';
import '../core/models/collection.dart';
import '../core/models/workspace_bundle.dart';
import '../core/storage/json_store.dart';
import '../core/storage/workspace_paths.dart';
import '../core/utils/id.dart';

class WorkspaceState {
  const WorkspaceState({this.collections = const [], this.requests = const []});

  final List<Collection> collections;
  final List<ApiRequest> requests;

  List<ApiRequest> requestsIn(String collectionId) => requests.where((r) => r.collectionId == collectionId).toList();

  WorkspaceState copyWith({List<Collection>? collections, List<ApiRequest>? requests}) {
    return WorkspaceState(collections: collections ?? this.collections, requests: requests ?? this.requests);
  }
}

/// Owns collections and their requests. Each collection is persisted as one
/// file (`collections/<id>.json`) holding both the collection metadata and
/// its requests — there's no separate per-request storage.
class WorkspaceNotifier extends AsyncNotifier<WorkspaceState> {
  @override
  Future<WorkspaceState> build() async {
    return _loadAll();
  }

  Future<WorkspaceState> _loadAll() async {
    final raw = await JsonStore.instance.readAll(WorkspacePaths.collections);
    final bundles = raw.map(CollectionBundle.fromJson).toList()..sort((a, b) => a.collection.createdAt.compareTo(b.collection.createdAt));

    if (bundles.isEmpty) {
      final defaultCollection = Collection(
        id: AppConstants.defaultCollectionId,
        name: 'My Requests',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _persist(CollectionBundle(collection: defaultCollection, requests: const []));
      return WorkspaceState(collections: [defaultCollection], requests: const []);
    }

    return WorkspaceState(collections: bundles.map((b) => b.collection).toList(), requests: bundles.expand((b) => b.requests).toList());
  }

  Future<void> _persist(CollectionBundle bundle) {
    return JsonStore.instance.write(WorkspacePaths.collectionFile(bundle.collection.id), bundle.toJson());
  }

  CollectionBundle _bundleFor(WorkspaceState state, String collectionId) {
    final collection = state.collections.firstWhere((c) => c.id == collectionId);
    return CollectionBundle(collection: collection, requests: state.requestsIn(collectionId));
  }

  Future<Collection> createCollection({required String name, String description = ''}) async {
    final current = state.value ?? const WorkspaceState();
    final now = DateTime.now();
    final collection = Collection(id: generateId('col'), name: name, description: description, createdAt: now, updatedAt: now);

    await _persist(CollectionBundle(collection: collection, requests: const []));
    state = AsyncData(current.copyWith(collections: [...current.collections, collection]));
    return collection;
  }

  Future<void> updateCollection(Collection updated) async {
    final current = state.value ?? const WorkspaceState();
    final collections = current.collections.map((c) => c.id == updated.id ? updated : c).toList();
    final next = current.copyWith(collections: collections);
    await _persist(_bundleFor(next, updated.id));
    state = AsyncData(next);
  }

  Future<void> deleteCollection(String collectionId) async {
    final current = state.value ?? const WorkspaceState();
    await JsonStore.instance.delete(WorkspacePaths.collectionFile(collectionId));
    state = AsyncData(
      current.copyWith(
        collections: current.collections.where((c) => c.id != collectionId).toList(),
        requests: current.requests.where((r) => r.collectionId != collectionId).toList(),
      ),
    );
  }

  Future<ApiRequest> createRequest({required String collectionId, required String name}) async {
    final current = state.value ?? const WorkspaceState();
    final now = DateTime.now();
    final request = ApiRequest(id: generateId('req'), collectionId: collectionId, name: name, createdAt: now, updatedAt: now);

    final next = current.copyWith(requests: [...current.requests, request]);
    await _persist(_bundleFor(next, collectionId));
    state = AsyncData(next);
    return request;
  }

  Future<void> updateRequest(ApiRequest updated) async {
    final current = state.value ?? const WorkspaceState();
    final requests = current.requests.map((r) => r.id == updated.id ? updated : r).toList();
    final next = current.copyWith(requests: requests);
    await _persist(_bundleFor(next, updated.collectionId));
    state = AsyncData(next);
  }

  Future<void> deleteRequest(ApiRequest request) async {
    final current = state.value ?? const WorkspaceState();
    final next = current.copyWith(requests: current.requests.where((r) => r.id != request.id).toList());
    await _persist(_bundleFor(next, request.collectionId));
    state = AsyncData(next);
  }

  Future<ApiRequest> duplicateRequest(ApiRequest request) async {
    final now = DateTime.now();
    return createRequest(collectionId: request.collectionId, name: '${request.name} copy').then((created) async {
      final duplicated = created.copyWith(
        method: request.method,
        url: request.url,
        headers: request.headers,
        queryParams: request.queryParams,
        bodyType: request.bodyType,
        body: request.body,
        formFields: request.formFields,
        authType: request.authType,
        authConfig: request.authConfig,
        description: request.description,
        updatedAt: now,
      );
      await updateRequest(duplicated);
      return duplicated;
    });
  }

  /// Imports whole collections+requests, e.g. from a workspace/Postman bundle.
  /// [resolveId] decides the final collection id: return the same id to overwrite
  /// an existing collection, a new id to keep both, or null to skip it entirely.
  Future<void> importBundles(List<CollectionBundle> incoming, {String? Function(Collection incoming, bool nameTaken)? resolveId}) async {
    final current = state.value ?? const WorkspaceState();
    var collections = [...current.collections];
    var requests = [...current.requests];

    for (final bundle in incoming) {
      final nameTaken = collections.any((c) => c.name == bundle.collection.name);
      final targetId = resolveId?.call(bundle.collection, nameTaken) ?? generateId('col');

      final now = DateTime.now();
      final collection = Collection(
        id: targetId,
        name: bundle.collection.name,
        description: bundle.collection.description,
        createdAt: bundle.collection.createdAt,
        updatedAt: now,
      );
      final importedRequests = bundle.requests.map((r) => r.copyWith(collectionId: targetId)).toList();

      collections = [...collections.where((c) => c.id != targetId), collection];
      requests = [...requests.where((r) => r.collectionId != targetId), ...importedRequests];
      await _persist(CollectionBundle(collection: collection, requests: importedRequests));
    }

    state = AsyncData(WorkspaceState(collections: collections, requests: requests));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _loadAll());
  }
}

final workspaceProvider = AsyncNotifierProvider<WorkspaceNotifier, WorkspaceState>(WorkspaceNotifier.new);
