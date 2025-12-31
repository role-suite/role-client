import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/features/collection_runner/data/services/collection_run_history_service.dart';
import 'package:relay/features/collection_runner/domain/models/collection_run_history.dart';
import 'package:relay/features/collection_runner/presentation/controllers/collection_runner_controller.dart';
import 'package:relay/features/home/presentation/providers/repository_providers.dart';
import 'package:relay/features/home/presentation/providers/usecase_providers.dart';

final collectionRunHistoryServiceProvider = Provider<CollectionRunHistoryService>((ref) {
  return CollectionRunHistoryService.instance;
});

final collectionRunHistoriesProvider = FutureProvider<List<CollectionRunHistory>>((ref) async {
  final service = ref.watch(collectionRunHistoryServiceProvider);
  return await service.getAllHistories();
});

final collectionRunnerControllerProvider = StateNotifierProvider.autoDispose<CollectionRunnerController, CollectionRunnerState>((ref) {
  final getRequestsByCollectionUseCase = ref.watch(getRequestsByCollectionUseCaseProvider);
  final environmentRepository = ref.watch(environmentRepositoryProvider);
  final historyService = ref.watch(collectionRunHistoryServiceProvider);
  return CollectionRunnerController(getRequestsByCollectionUseCase, environmentRepository, historyService);
});
