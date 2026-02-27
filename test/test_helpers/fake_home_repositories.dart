import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/features/home/domain/repositories/collection_repository.dart';
import 'package:relay/features/home/domain/repositories/environment_repository.dart';
import 'package:relay/features/home/domain/repositories/request_repository.dart';

class FakeCollectionRepository implements CollectionRepository {
  FakeCollectionRepository({List<CollectionModel>? initialCollections, this.throwOnGetAll = false}) : _collections = [...?initialCollections];

  final List<CollectionModel> _collections;
  bool throwOnGetAll;

  @override
  Future<bool> collectionExists(String name) async {
    return _collections.any((collection) => collection.name == name);
  }

  @override
  Future<void> deleteCollection(String id) async {
    _collections.removeWhere((collection) => collection.id == id);
  }

  @override
  Future<List<CollectionModel>> getAllCollections() async {
    if (throwOnGetAll) {
      throw Exception('failed to load collections');
    }
    return List.unmodifiable(_collections);
  }

  @override
  Future<CollectionModel?> getCollectionById(String id) async {
    for (final collection in _collections) {
      if (collection.id == id) {
        return collection;
      }
    }
    return null;
  }

  @override
  Future<CollectionModel?> getCollectionByName(String name) async {
    for (final collection in _collections) {
      if (collection.name == name) {
        return collection;
      }
    }
    return null;
  }

  @override
  Future<void> saveCollection(CollectionModel collection) async {
    final index = _collections.indexWhere((item) => item.id == collection.id);
    if (index >= 0) {
      _collections[index] = collection;
      return;
    }
    _collections.add(collection);
  }
}

class FakeRequestRepository implements RequestRepository {
  FakeRequestRepository({List<ApiRequestModel>? initialRequests, this.throwOnGetAll = false}) : _requests = [...?initialRequests];

  final List<ApiRequestModel> _requests;
  bool throwOnGetAll;

  @override
  Future<void> deleteRequest(String id) async {
    _requests.removeWhere((request) => request.id == id);
  }

  @override
  Future<List<ApiRequestModel>> getAllRequests() async {
    if (throwOnGetAll) {
      throw Exception('failed to load requests');
    }
    return List.unmodifiable(_requests);
  }

  @override
  Future<ApiRequestModel?> getRequestById(String id) async {
    for (final request in _requests) {
      if (request.id == id) {
        return request;
      }
    }
    return null;
  }

  @override
  Future<List<ApiRequestModel>> getRequestsByCollection(String collection) async {
    return _requests.where((request) => request.collectionId == collection).toList();
  }

  @override
  Future<void> saveRequest(ApiRequestModel request) async {
    final index = _requests.indexWhere((item) => item.id == request.id);
    if (index >= 0) {
      _requests[index] = request;
      return;
    }
    _requests.add(request);
  }
}

class FakeEnvironmentRepository implements EnvironmentRepository {
  FakeEnvironmentRepository({List<EnvironmentModel>? initialEnvironments, this.throwOnGetAll = false}) : _environments = [...?initialEnvironments];

  final List<EnvironmentModel> _environments;
  bool throwOnGetAll;
  String? _activeEnvironmentName;

  @override
  Future<void> deleteEnvironment(String name) async {
    _environments.removeWhere((environment) => environment.name == name);
    if (_activeEnvironmentName == name) {
      _activeEnvironmentName = null;
    }
  }

  @override
  Future<EnvironmentModel?> getActiveEnvironment() async {
    if (_activeEnvironmentName == null) {
      return null;
    }
    return getEnvironmentByName(_activeEnvironmentName!);
  }

  @override
  Future<List<EnvironmentModel>> getAllEnvironments() async {
    if (throwOnGetAll) {
      throw Exception('failed to load environments');
    }
    return List.unmodifiable(_environments);
  }

  @override
  Future<EnvironmentModel?> getEnvironmentByName(String name) async {
    for (final environment in _environments) {
      if (environment.name == name) {
        return environment;
      }
    }
    return null;
  }

  @override
  String resolveTemplate(String input, EnvironmentModel? environment) {
    if (environment == null) {
      return input;
    }

    var output = input;
    environment.variables.forEach((key, value) {
      output = output.replaceAll('{{$key}}', value);
    });
    return output;
  }

  @override
  Future<void> saveEnvironment(EnvironmentModel environment) async {
    final index = _environments.indexWhere((item) => item.name == environment.name);
    if (index >= 0) {
      _environments[index] = environment;
      return;
    }
    _environments.add(environment);
  }

  @override
  Future<void> setActiveEnvironment(String? name) async {
    _activeEnvironmentName = name;
  }
}
