import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/features/collection_runner/data/services/collection_run_history_service.dart';
import 'package:relay/features/collection_runner/domain/models/collection_run_history.dart';
import 'package:relay/features/collection_runner/presentation/controllers/collection_runner_controller.dart';

final collectionRunHistoryServiceProvider = Provider<CollectionRunHistoryService>((ref) {
  return CollectionRunHistoryService.instance;
});

final collectionRunHistoriesProvider = FutureProvider<List<CollectionRunHistory>>((ref) async {
  final service = ref.watch(collectionRunHistoryServiceProvider);
  return service.getAllHistories();
});

final collectionRunnerControllerProvider = NotifierProvider.autoDispose<CollectionRunnerController, CollectionRunnerState>(
  CollectionRunnerController.new,
);
