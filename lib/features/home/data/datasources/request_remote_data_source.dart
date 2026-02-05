import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/workspace_bundle.dart';
import 'package:relay/core/services/workspace_api/workspace_api_client.dart';
import 'package:relay/features/home/data/datasources/request_data_source.dart';

/// Data source that reads/writes requests via the remote workspace API.
class RequestRemoteDataSource implements RequestDataSource {
  RequestRemoteDataSource(this._client);

  final WorkspaceApiClient _client;

  @override
  Future<List<ApiRequestModel>> getAllRequests() async {
    final bundle = await _client.getWorkspace();
    final list = <ApiRequestModel>[];
    for (final cb in bundle.collections) {
      for (final r in cb.requests) {
        list.add(r.collectionId == cb.collection.id ? r : r.copyWith(collectionId: cb.collection.id));
      }
    }
    return list;
  }

  @override
  Future<ApiRequestModel?> getRequestById(String id) async {
    final all = await getAllRequests();
    try {
      return all.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<ApiRequestModel>> getRequestsByCollection(String collection) async {
    final bundle = await _client.getWorkspace();
    final list = bundle.collections.where((b) => b.collection.id == collection).toList();
    if (list.isEmpty) return [];
    final cb = list.first;
    return cb.requests.map((r) => r.collectionId == collection ? r : r.copyWith(collectionId: collection)).toList();
  }

  @override
  Future<void> saveRequest(ApiRequestModel request) async {
    final bundle = await _client.getWorkspace();
    final newCollections = <CollectionBundle>[];
    for (final cb in bundle.collections) {
      if (cb.collection.id != request.collectionId) {
        newCollections.add(cb);
        continue;
      }
      final newRequests = <ApiRequestModel>[];
      var found = false;
      for (final r in cb.requests) {
        if (r.id == request.id) {
          newRequests.add(request);
          found = true;
        } else {
          newRequests.add(r);
        }
      }
      if (!found) {
        newRequests.add(request);
      }
      newCollections.add(CollectionBundle(collection: cb.collection, requests: newRequests));
    }
    // If collection doesn't exist, add a minimal bundle entry for this request
    if (!newCollections.any((c) => c.collection.id == request.collectionId)) {
      final now = DateTime.now();
      final placeholder = CollectionModel(
        id: request.collectionId,
        name: 'Collection ${request.collectionId}',
        description: '',
        createdAt: now,
        updatedAt: now,
      );
      newCollections.add(CollectionBundle(collection: placeholder, requests: [request]));
    }
    final newBundle = WorkspaceBundle(
      version: bundle.version,
      exportedAt: bundle.exportedAt,
      source: bundle.source,
      collections: newCollections,
      environments: bundle.environments,
    );
    await _client.putWorkspace(newBundle);
  }

  @override
  Future<void> deleteRequest(String id) async {
    final request = await getRequestById(id);
    if (request == null) return;
    final bundle = await _client.getWorkspace();
    final newCollections = <CollectionBundle>[];
    for (final cb in bundle.collections) {
      if (cb.collection.id != request.collectionId) {
        newCollections.add(cb);
        continue;
      }
      final newRequests = cb.requests.where((r) => r.id != id).toList();
      newCollections.add(CollectionBundle(collection: cb.collection, requests: newRequests));
    }
    final newBundle = WorkspaceBundle(
      version: bundle.version,
      exportedAt: bundle.exportedAt,
      source: bundle.source,
      collections: newCollections,
      environments: bundle.environments,
    );
    await _client.putWorkspace(newBundle);
  }
}
