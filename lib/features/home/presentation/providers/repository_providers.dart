import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/models/data_source_config.dart';
import 'package:relay/core/services/environment_service.dart';
import 'package:relay/core/services/file_storage_service.dart';
import 'package:relay/core/services/relay_api/relay_api_client.dart';
import 'package:relay/core/services/relay_api/rest_relay_api_client.dart';
import 'package:relay/core/services/workspace_service.dart';
import 'package:relay/features/home/collection/data/datasources/collection_data_source.dart';
import 'package:relay/features/home/collection/data/datasources/collection_local_data_source.dart';
import 'package:relay/features/home/collection/data/datasources/collection_remote_data_source.dart';
import 'package:relay/features/home/request/data/datasources/request_data_source.dart';
import 'package:relay/features/home/request/data/datasources/request_local_data_source.dart';
import 'package:relay/features/home/request/data/datasources/request_remote_data_source.dart';
import 'package:relay/features/home/collection/data/repositories/collection_repository_impl.dart';
import 'package:relay/features/home/environment/data/repositories/environment_repository_impl.dart';
import 'package:relay/features/home/environment/data/repositories/environment_repository_remote_impl.dart';
import 'package:relay/features/home/request/data/repositories/request_repository_impl.dart';
import 'package:relay/features/home/collection/domain/repositories/collection_repository.dart';
import 'package:relay/features/home/environment/domain/repositories/environment_repository.dart';
import 'package:relay/features/home/request/domain/repositories/request_repository.dart';
import 'package:relay/features/home/presentation/providers/data_source_providers.dart';
import 'package:relay/features/home/presentation/providers/workspace_selection_providers.dart';

/// Provider for RequestLocalDataSource
final requestLocalDataSourceProvider = Provider<RequestLocalDataSource>((ref) {
  return RequestLocalDataSource(FileStorageService.instance, WorkspaceService.instance);
});

/// Provider for CollectionLocalDataSource
final collectionLocalDataSourceProvider = Provider<CollectionLocalDataSource>((ref) {
  return CollectionLocalDataSource(FileStorageService.instance, WorkspaceService.instance);
});

RelayApiClient _createRelayApiClient(DataSourceConfig config) {
  return RestRelayApiClient(baseUrl: config.baseUrl, apiKey: config.apiKey);
}

final activeRelayApiClientProvider = Provider<RelayApiClient?>((ref) {
  final state = ref.watch(currentDataSourceStateProvider);
  final activeWorkspaceId = ref.watch(activeWorkspaceIdProvider).asData?.value;
  if (state == null || state.mode != DataSourceMode.api || !state.config.isValid) {
    return null;
  }

  return RestRelayApiClient(baseUrl: state.config.baseUrl, apiKey: state.config.apiKey, workspaceId: activeWorkspaceId);
});

/// Active collection data source (local or remote depending on data source mode).
final collectionDataSourceProvider = Provider<CollectionDataSource>((ref) {
  final api = ref.watch(activeRelayApiClientProvider);
  if (api != null) {
    return CollectionRemoteDataSource(api);
  }
  return ref.watch(collectionLocalDataSourceProvider);
});

/// Active request data source (local or remote depending on data source mode).
final requestDataSourceProvider = Provider<RequestDataSource>((ref) {
  final api = ref.watch(activeRelayApiClientProvider);
  if (api != null) {
    return RequestRemoteDataSource(api);
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
  final api = ref.watch(activeRelayApiClientProvider);
  if (api != null) {
    return EnvironmentRepositoryRemoteImpl(api, EnvironmentService.instance);
  }
  return EnvironmentRepositoryImpl(EnvironmentService.instance);
});
