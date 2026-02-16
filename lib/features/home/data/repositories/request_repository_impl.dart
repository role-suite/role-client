import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/features/home/data/datasources/request_data_source.dart';
import 'package:relay/features/home/domain/repositories/request_repository.dart';

/// Implementation of RequestRepository (local or remote data source).
class RequestRepositoryImpl implements RequestRepository {
  final RequestDataSource _dataSource;

  RequestRepositoryImpl(this._dataSource);

  @override
  Future<List<ApiRequestModel>> getAllRequests() async {
    return await _dataSource.getAllRequests();
  }

  @override
  Future<ApiRequestModel?> getRequestById(String id) async {
    return await _dataSource.getRequestById(id);
  }

  @override
  Future<void> saveRequest(ApiRequestModel request) async {
    await _dataSource.saveRequest(request);
  }

  @override
  Future<void> deleteRequest(String id) async {
    await _dataSource.deleteRequest(id);
  }

  @override
  Future<List<ApiRequestModel>> getRequestsByCollection(String collection) async {
    return await _dataSource.getRequestsByCollection(collection);
  }
}
