import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/constants/api_style.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/models/data_source_config.dart';
import 'package:relay/core/services/environment_service.dart';
import 'package:relay/core/services/file_storage_service.dart';
import 'package:relay/core/services/workspace_service.dart';
import 'package:relay/core/services/workspace_api/rest_workspace_client.dart';
import 'package:relay/core/services/workspace_api/serverpod_workspace_client.dart';
import 'package:relay/core/services/workspace_api/workspace_api_client.dart';
import 'package:relay/features/home/data/datasources/collection_data_source.dart';
import 'package:relay/features/home/data/datasources/collection_local_data_source.dart';
import 'package:relay/features/home/data/datasources/collection_remote_data_source.dart';
import 'package:relay/features/home/data/datasources/request_data_source.dart';
import 'package:relay/features/home/data/datasources/request_local_data_source.dart';
import 'package:relay/features/home/data/datasources/request_remote_data_source.dart';
import 'package:relay/features/home/data/repositories/collection_repository_impl.dart';
import 'package:relay/features/home/data/repositories/environment_repository_impl.dart';
import 'package:relay/features/home/data/repositories/environment_repository_remote_impl.dart';
import 'package:relay/features/home/data/repositories/request_repository_impl.dart';
import 'package:relay/features/home/domain/repositories/collection_repository.dart';
import 'package:relay/features/home/domain/repositories/environment_repository.dart';
import 'package:relay/features/home/domain/repositories/request_repository.dart';
import 'package:relay/features/home/presentation/providers/data_source_providers.dart';

/// Provider for RequestLocalDataSource
final requestLocalDataSourceProvider = Provider<RequestLocalDataSource>((ref) {
  return RequestLocalDataSource(FileStorageService.instance, WorkspaceService.instance);
});

/// Provider for CollectionLocalDataSource
final collectionLocalDataSourceProvider = Provider<CollectionLocalDataSource>((ref) {
  return CollectionLocalDataSource(FileStorageService.instance, WorkspaceService.instance);
});

WorkspaceApiClient _createWorkspaceClient(DataSourceConfig config) {
  switch (config.apiStyle) {
    case ApiStyle.serverpod:
      return ServerpodWorkspaceClient(serverUrl: config.baseUrl);
    case ApiStyle.rest:
      return RestWorkspaceClient(baseUrl: config.baseUrl, apiKey: config.apiKey);
  }
}

/// Active collection data source (local or remote depending on data source mode).
final collectionDataSourceProvider = Provider<CollectionDataSource>((ref) {
  final state = ref.watch(dataSourceStateNotifierProvider).asData?.value;
  if (state != null && state.mode == DataSourceMode.api && state.config.isValid) {
    final client = _createWorkspaceClient(state.config);
    return CollectionRemoteDataSource(client);
  }
  return ref.watch(collectionLocalDataSourceProvider);
});

/// Active request data source (local or remote depending on data source mode).
final requestDataSourceProvider = Provider<RequestDataSource>((ref) {
  final state = ref.watch(dataSourceStateNotifierProvider).asData?.value;
  if (state != null && state.mode == DataSourceMode.api && state.config.isValid) {
    final client = _createWorkspaceClient(state.config);
    return RequestRemoteDataSource(client);
  }
  return ref.watch(requestLocalDataSourceProvider);
});

/// Provider for CollectionRepository (uses local or remote data source by mode)
final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  final dataSource = ref.watch(collectionDataSourceProvider);
  return CollectionRepositoryImpl(dataSource);
});

/// Provider for RequestRepository (uses local or remote data source by mode)
final requestRepositoryProvider = Provider<RequestRepository>((ref) {
  final dataSource = ref.watch(requestDataSourceProvider);
  return RequestRepositoryImpl(dataSource);
});

/// Provider for EnvironmentRepository (local or remote by mode)
final environmentRepositoryProvider = Provider<EnvironmentRepository>((ref) {
  final state = ref.watch(dataSourceStateNotifierProvider).asData?.value;
  if (state != null && state.mode == DataSourceMode.api && state.config.isValid) {
    final client = _createWorkspaceClient(state.config);
    return EnvironmentRepositoryRemoteImpl(client, EnvironmentService.instance);
  }
  return EnvironmentRepositoryImpl(EnvironmentService.instance);
});
