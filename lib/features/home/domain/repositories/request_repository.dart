import 'package:relay/core/model/api_request_model.dart';

/// Repository interface for managing API requests
/// This is part of the domain layer and defines the contract
abstract class RequestRepository {
  /// Get all requests
  Future<List<ApiRequestModel>> getAllRequests();

  /// Get a request by ID
  Future<ApiRequestModel?> getRequestById(String id);

  /// Save a request (create or update)
  Future<void> saveRequest(ApiRequestModel request);

  /// Delete a request by ID
  Future<void> deleteRequest(String id);

  /// Get requests by collection/folder
  Future<List<ApiRequestModel>> getRequestsByCollection(String collection);
}

