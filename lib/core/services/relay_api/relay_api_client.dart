import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/environment_model.dart';

/// Abstract client for collections, environments, and requests (REST or Serverpod).
/// Remote data sources use this to read/write via the API.
abstract class RelayApiClient {
  // Collections
  Future<List<CollectionModel>> listCollections();
  Future<CollectionModel?> getCollection(String id);
  Future<void> createCollection(CollectionModel collection);
  Future<void> updateCollection(CollectionModel collection);
  Future<void> deleteCollection(String id);

  // Environments
  Future<List<EnvironmentModel>> listEnvironments();
  Future<EnvironmentModel?> getEnvironment(String name);
  Future<void> createEnvironment(EnvironmentModel environment);
  Future<void> updateEnvironment(EnvironmentModel environment);
  Future<void> deleteEnvironment(String name);

  // Requests (scoped by collection)
  Future<List<ApiRequestModel>> listRequests(String collectionId);
  Future<ApiRequestModel?> getRequest(String requestId);
  Future<void> createRequest(ApiRequestModel request);
  Future<void> updateRequest(ApiRequestModel request);
  Future<void> deleteRequest(String requestId);
}
