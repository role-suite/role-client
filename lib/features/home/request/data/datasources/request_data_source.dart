import 'package:relay/core/models/api_request_model.dart';

/// Abstraction for request storage (local or remote).
abstract class RequestDataSource {
  Future<List<ApiRequestModel>> getAllRequests();
  Future<ApiRequestModel?> getRequestById(String id);
  Future<void> saveRequest(ApiRequestModel request);
  Future<void> deleteRequest(String id);
  Future<List<ApiRequestModel>> getRequestsByCollection(String collection);
}
