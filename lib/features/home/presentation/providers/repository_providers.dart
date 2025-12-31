import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/services/environment_service.dart';
import 'package:relay/core/services/file_storage_service.dart';
import 'package:relay/core/services/workspace_service.dart';
import 'package:relay/features/home/data/datasources/collection_local_data_source.dart';
import 'package:relay/features/home/data/datasources/request_local_data_source.dart';
import 'package:relay/features/home/data/repositories/collection_repository_impl.dart';
import 'package:relay/features/home/data/repositories/environment_repository_impl.dart';
import 'package:relay/features/home/data/repositories/request_repository_impl.dart';
import 'package:relay/features/home/domain/repositories/collection_repository.dart';
import 'package:relay/features/home/domain/repositories/environment_repository.dart';
import 'package:relay/features/home/domain/repositories/request_repository.dart';

/// Provider for RequestLocalDataSource
final requestLocalDataSourceProvider = Provider<RequestLocalDataSource>((ref) {
  return RequestLocalDataSource(FileStorageService.instance, WorkspaceService.instance);
});

/// Provider for RequestRepository
final requestRepositoryProvider = Provider<RequestRepository>((ref) {
  final dataSource = ref.watch(requestLocalDataSourceProvider);
  return RequestRepositoryImpl(dataSource);
});

/// Provider for EnvironmentRepository
final environmentRepositoryProvider = Provider<EnvironmentRepository>((ref) {
  return EnvironmentRepositoryImpl(EnvironmentService.instance);
});

/// Provider for CollectionLocalDataSource
final collectionLocalDataSourceProvider = Provider<CollectionLocalDataSource>((ref) {
  return CollectionLocalDataSource(FileStorageService.instance, WorkspaceService.instance);
});

/// Provider for CollectionRepository
final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  final dataSource = ref.watch(collectionLocalDataSourceProvider);
  return CollectionRepositoryImpl(dataSource);
});
