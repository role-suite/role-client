import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/services/relay_api/relay_api_client.dart';
import 'package:relay/features/home/data/datasources/request_data_source.dart';

/// Data source that reads/writes requests via the Relay API (REST or Serverpod).
class RequestRemoteDataSource implements RequestDataSource {
  RequestRemoteDataSource(this._api);

  final RelayApiClient _api;

  @override
  Future<List<ApiRequestModel>> getAllRequests() async {
    final collections = await _api.listCollections();
    final list = <ApiRequestModel>[];
    for (final c in collections) {
      final requests = await _api.listRequests(c.id);
      list.addAll(requests);
    }
    return list;
  }

  @override
  Future<ApiRequestModel?> getRequestById(String id) async {
    return _api.getRequest(id);
  }

  @override
  Future<List<ApiRequestModel>> getRequestsByCollection(String collectionId) async {
    return _api.listRequests(collectionId);
  }

  @override
  Future<void> saveRequest(ApiRequestModel request) async {
    final existing = await getRequestById(request.id);
    if (existing == null) {
      await _api.createRequest(request);
    } else {
      await _api.updateRequest(request);
    }
  }

  @override
  Future<void> deleteRequest(String id) async {
    await _api.deleteRequest(id);
  }
}
