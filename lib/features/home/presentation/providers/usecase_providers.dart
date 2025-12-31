import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/features/home/domain/usecases/create_collection_usecase.dart';
import 'package:relay/features/home/domain/usecases/create_environment_usecase.dart';
import 'package:relay/features/home/domain/usecases/create_request_usecase.dart';
import 'package:relay/features/home/domain/usecases/delete_collection_usecase.dart';
import 'package:relay/features/home/domain/usecases/delete_environment_usecase.dart';
import 'package:relay/features/home/domain/usecases/delete_request_usecase.dart';
import 'package:relay/features/home/domain/usecases/get_active_environment_usecase.dart';
import 'package:relay/features/home/domain/usecases/get_all_collections_usecase.dart';
import 'package:relay/features/home/domain/usecases/get_all_environments_usecase.dart';
import 'package:relay/features/home/domain/usecases/get_all_requests_usecase.dart';
import 'package:relay/features/home/domain/usecases/get_requests_by_collection_usecase.dart';
import 'package:relay/features/home/domain/usecases/set_active_environment_usecase.dart';
import 'package:relay/features/home/domain/usecases/update_environment_usecase.dart';
import 'package:relay/features/home/domain/usecases/update_request_usecase.dart';
import 'package:relay/features/home/presentation/providers/repository_providers.dart';

/// Provider for GetAllRequestsUseCase
final getAllRequestsUseCaseProvider = Provider<GetAllRequestsUseCase>((ref) {
  final repository = ref.watch(requestRepositoryProvider);
  return GetAllRequestsUseCase(repository);
});

/// Provider for CreateRequestUseCase
final createRequestUseCaseProvider = Provider<CreateRequestUseCase>((ref) {
  final repository = ref.watch(requestRepositoryProvider);
  return CreateRequestUseCase(repository);
});

/// Provider for UpdateRequestUseCase
final updateRequestUseCaseProvider = Provider<UpdateRequestUseCase>((ref) {
  final repository = ref.watch(requestRepositoryProvider);
  return UpdateRequestUseCase(repository);
});

/// Provider for DeleteRequestUseCase
final deleteRequestUseCaseProvider = Provider<DeleteRequestUseCase>((ref) {
  final repository = ref.watch(requestRepositoryProvider);
  return DeleteRequestUseCase(repository);
});

/// Provider for GetAllEnvironmentsUseCase
final getAllEnvironmentsUseCaseProvider = Provider<GetAllEnvironmentsUseCase>((ref) {
  final repository = ref.watch(environmentRepositoryProvider);
  return GetAllEnvironmentsUseCase(repository);
});

/// Provider for SetActiveEnvironmentUseCase
final setActiveEnvironmentUseCaseProvider = Provider<SetActiveEnvironmentUseCase>((ref) {
  final repository = ref.watch(environmentRepositoryProvider);
  return SetActiveEnvironmentUseCase(repository);
});

/// Provider for GetActiveEnvironmentUseCase
final getActiveEnvironmentUseCaseProvider = Provider<GetActiveEnvironmentUseCase>((ref) {
  final repository = ref.watch(environmentRepositoryProvider);
  return GetActiveEnvironmentUseCase(repository);
});

/// Provider for GetAllCollectionsUseCase
final getAllCollectionsUseCaseProvider = Provider<GetAllCollectionsUseCase>((ref) {
  final repository = ref.watch(collectionRepositoryProvider);
  return GetAllCollectionsUseCase(repository);
});

/// Provider for CreateCollectionUseCase
final createCollectionUseCaseProvider = Provider<CreateCollectionUseCase>((ref) {
  final repository = ref.watch(collectionRepositoryProvider);
  return CreateCollectionUseCase(repository);
});

/// Provider for DeleteCollectionUseCase
final deleteCollectionUseCaseProvider = Provider<DeleteCollectionUseCase>((ref) {
  final repository = ref.watch(collectionRepositoryProvider);
  return DeleteCollectionUseCase(repository);
});

/// Provider for GetRequestsByCollectionUseCase
final getRequestsByCollectionUseCaseProvider = Provider<GetRequestsByCollectionUseCase>((ref) {
  final repository = ref.watch(requestRepositoryProvider);
  return GetRequestsByCollectionUseCase(repository);
});

/// Provider for CreateEnvironmentUseCase
final createEnvironmentUseCaseProvider = Provider<CreateEnvironmentUseCase>((ref) {
  final repository = ref.watch(environmentRepositoryProvider);
  return CreateEnvironmentUseCase(repository);
});

/// Provider for UpdateEnvironmentUseCase
final updateEnvironmentUseCaseProvider = Provider<UpdateEnvironmentUseCase>((ref) {
  final repository = ref.watch(environmentRepositoryProvider);
  return UpdateEnvironmentUseCase(repository);
});

/// Provider for DeleteEnvironmentUseCase
final deleteEnvironmentUseCaseProvider = Provider<DeleteEnvironmentUseCase>((ref) {
  final repository = ref.watch(environmentRepositoryProvider);
  return DeleteEnvironmentUseCase(repository);
});
