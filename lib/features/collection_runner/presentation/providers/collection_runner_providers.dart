import 'package:flutter_riverpod/legacy.dart';
import 'package:relay/features/collection_runner/presentation/controllers/collection_runner_controller.dart';
import 'package:relay/features/home/presentation/providers/repository_providers.dart';
import 'package:relay/features/home/presentation/providers/usecase_providers.dart';

final collectionRunnerControllerProvider = StateNotifierProvider.autoDispose<CollectionRunnerController, CollectionRunnerState>((ref) {
  final getRequestsByCollectionUseCase = ref.watch(getRequestsByCollectionUseCaseProvider);
  final environmentRepository = ref.watch(environmentRepositoryProvider);
  return CollectionRunnerController(getRequestsByCollectionUseCase, environmentRepository);
});


