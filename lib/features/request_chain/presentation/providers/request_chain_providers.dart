import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/services/file_storage_service.dart';
import 'package:relay/core/services/workspace_service.dart';
import 'package:relay/features/home/presentation/providers/repository_providers.dart';
import 'package:relay/features/request_chain/data/datasources/saved_chain_local_data_source.dart';
import 'package:relay/features/request_chain/data/repositories/saved_chain_repository_impl.dart';
import 'package:relay/features/request_chain/data/services/request_chain_service.dart';
import 'package:relay/features/request_chain/domain/repositories/saved_chain_repository.dart';

/// Provider for RequestChainService
final requestChainServiceProvider = Provider<RequestChainService>((ref) {
  final environmentRepository = ref.watch(environmentRepositoryProvider);
  return RequestChainService(environmentRepository);
});

/// Provider for SavedChainLocalDataSource
final savedChainLocalDataSourceProvider = Provider<SavedChainLocalDataSource>((ref) {
  return SavedChainLocalDataSource(FileStorageService.instance, WorkspaceService.instance);
});

/// Provider for SavedChainRepository
final savedChainRepositoryProvider = Provider<SavedChainRepository>((ref) {
  final dataSource = ref.watch(savedChainLocalDataSourceProvider);
  return SavedChainRepositoryImpl(dataSource);
});
