import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/environment_model.dart';

import '../providers/providers.dart';

class CreateCollectionViewModel {
  CreateCollectionViewModel(this._ref);

  final Ref _ref;

  Future<void> createCollection(CollectionModel collection) async {
    await _ref.read(collectionsNotifierProvider.notifier).addCollection(collection);
  }

  void selectCollection(String id) {
    _ref.read(selectedCollectionIdProvider.notifier).state = id;
  }
}

final createCollectionViewModelProvider = Provider<CreateCollectionViewModel>(
  (ref) => CreateCollectionViewModel(ref),
);

class CreateRequestViewModel {
  CreateRequestViewModel(this._ref);

  final Ref _ref;

  Future<void> createRequest(ApiRequestModel request) async {
    await _ref.read(requestsNotifierProvider.notifier).addRequest(request);
  }
}

final createRequestViewModelProvider = Provider.autoDispose<CreateRequestViewModel>(
  (ref) => CreateRequestViewModel(ref),
);

class EnvironmentDialogViewModel {
  EnvironmentDialogViewModel(this._ref);

  final Ref _ref;

  Future<void> createEnvironment(EnvironmentModel environment) async {
    await _ref.read(environmentsNotifierProvider.notifier).addEnvironment(environment);
  }

  Future<void> updateEnvironment(EnvironmentModel environment) async {
    await _ref.read(environmentsNotifierProvider.notifier).updateEnvironment(environment);
  }

  void setActiveEnvironment(String? name) {
    _ref.read(activeEnvironmentNameProvider.notifier).state = name;
    _ref.read(activeEnvironmentNotifierProvider.notifier).setActiveEnvironment(name);
  }
}

final environmentDialogViewModelProvider = Provider.autoDispose<EnvironmentDialogViewModel>(
  (ref) => EnvironmentDialogViewModel(ref),
);

class DeleteEntitiesViewModel {
  DeleteEntitiesViewModel(this._ref);

  final Ref _ref;

  Future<void> deleteRequest(ApiRequestModel request) async {
    await _ref.read(requestsNotifierProvider.notifier).removeRequest(request.id);
  }

  Future<void> deleteCollection(CollectionModel collection) async {
    await _ref.read(collectionsNotifierProvider.notifier).removeCollection(collection.id);

    final selectedId = _ref.read(selectedCollectionIdProvider);
    if (selectedId == collection.id) {
      _ref.read(selectedCollectionIdProvider.notifier).state = 'default';
    }
  }

  Future<void> deleteEnvironment(EnvironmentModel environment) async {
    await _ref.read(environmentsNotifierProvider.notifier).removeEnvironment(environment.name);

    final activeEnvName = _ref.read(activeEnvironmentNameProvider);
    if (activeEnvName == environment.name) {
      _ref.read(activeEnvironmentNameProvider.notifier).state = null;
      _ref.read(activeEnvironmentNotifierProvider.notifier).setActiveEnvironment(null);
    }
  }
}

final deleteEntitiesViewModelProvider = Provider<DeleteEntitiesViewModel>(
  (ref) => DeleteEntitiesViewModel(ref),
);

