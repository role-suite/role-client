import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:relay/core/model/collection_model.dart';
import 'package:relay/features/home/presentation/providers/usecase_providers.dart';
import 'package:relay/features/home/presentation/providers/request_providers.dart';

import '../../domain/usecases/create_collection_usecase.dart';
import '../../domain/usecases/delete_collection_usecase.dart';
import '../../domain/usecases/get_all_collections_usecase.dart';

/// Provider for all collections
final collectionsProvider = FutureProvider<List<CollectionModel>>((ref) async {
  final useCase = ref.watch(getAllCollectionsUseCaseProvider);
  return await useCase();
});

/// Notifier for managing collection state
class CollectionsNotifier extends StateNotifier<AsyncValue<List<CollectionModel>>> {
  final GetAllCollectionsUseCase _getAllCollectionsUseCase;
  final CreateCollectionUseCase _createCollectionUseCase;
  final DeleteCollectionUseCase _deleteCollectionUseCase;
  final Ref _ref;

  CollectionsNotifier(
    this._getAllCollectionsUseCase,
    this._createCollectionUseCase,
    this._deleteCollectionUseCase,
    this._ref,
  ) : super(const AsyncValue.loading()) {
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    state = const AsyncValue.loading();
    try {
      final collections = await _getAllCollectionsUseCase();
      state = AsyncValue.data(collections);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> addCollection(CollectionModel collection) async {
    try {
      await _createCollectionUseCase(collection);
      await _loadCollections();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow; // Re-throw so UI can show error message
    }
  }

  Future<void> removeCollection(String id) async {
    try {
      await _deleteCollectionUseCase(id);
      await _loadCollections();
      // Refresh requests to remove deleted collection's requests from the list
      _ref.read(requestsNotifierProvider.notifier).refresh();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow; // Re-throw so UI can show error message
    }
  }

  void refresh() {
    _loadCollections();
  }
}

/// Provider for CollectionsNotifier
final collectionsNotifierProvider = StateNotifierProvider<CollectionsNotifier, AsyncValue<List<CollectionModel>>>((ref) {
  return CollectionsNotifier(
    ref.watch(getAllCollectionsUseCaseProvider),
    ref.watch(createCollectionUseCaseProvider),
    ref.watch(deleteCollectionUseCaseProvider),
    ref,
  );
});

