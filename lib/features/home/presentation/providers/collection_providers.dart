import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/features/home/presentation/providers/usecase_providers.dart';
import 'package:relay/features/home/presentation/providers/request_providers.dart';

import '../../domain/usecases/create_collection_usecase.dart';
import '../../domain/usecases/delete_collection_usecase.dart';
import '../../domain/usecases/get_all_collections_usecase.dart';

/// Provider for all collections
final collectionsProvider = FutureProvider<List<CollectionModel>>((ref) async {
  final useCase = ref.watch(getAllCollectionsUseCaseProvider);
  return useCase();
});

/// Notifier for managing collection state
class CollectionsNotifier extends AsyncNotifier<List<CollectionModel>> {
  late final GetAllCollectionsUseCase _getAllCollectionsUseCase;
  late final CreateCollectionUseCase _createCollectionUseCase;
  late final DeleteCollectionUseCase _deleteCollectionUseCase;

  @override
  Future<List<CollectionModel>> build() {
    _getAllCollectionsUseCase = ref.watch(getAllCollectionsUseCaseProvider);
    _createCollectionUseCase = ref.watch(createCollectionUseCaseProvider);
    _deleteCollectionUseCase = ref.watch(deleteCollectionUseCaseProvider);
    return _getAllCollectionsUseCase();
  }

  Future<void> _loadCollections() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _getAllCollectionsUseCase());
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
      ref.read(requestsNotifierProvider.notifier).refresh();
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
final collectionsNotifierProvider = AsyncNotifierProvider<CollectionsNotifier, List<CollectionModel>>(CollectionsNotifier.new);
