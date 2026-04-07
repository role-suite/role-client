import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/models/shared_request_model.dart';
import 'package:relay/core/services/role_node_api/shared_requests_api_client.dart';
import 'package:relay/features/home/collection/presentation/providers/collection_providers.dart';
import 'package:relay/features/home/environment/presentation/providers/environment_providers.dart';
import 'package:relay/features/home/presentation/providers/data_source_providers.dart';
import 'package:relay/features/home/presentation/providers/home_ui_providers.dart';
import 'package:relay/features/home/presentation/providers/workspace_selection_providers.dart';
import 'package:relay/features/home/request/presentation/providers/request_providers.dart';

final sharedRequestsApiClientProvider = Provider<SharedRequestsApiClient?>((ref) {
  final state = ref.watch(currentDataSourceStateProvider);
  final activeWorkspaceId = ref.watch(activeWorkspaceIdProvider).asData?.value;
  if (state == null || !state.config.isValid) return null;
  if (state.mode != DataSourceMode.api) return null;
  final accessToken = state.config.apiKey?.trim();
  if (accessToken == null || accessToken.isEmpty) return null;
  return SharedRequestsApiClient(baseUrl: state.config.baseUrl, accessToken: accessToken, workspaceId: activeWorkspaceId);
});

class SharedRequestsNotifier extends AsyncNotifier<List<SharedRequestModel>> {
  @override
  Future<List<SharedRequestModel>> build() async {
    final api = ref.watch(sharedRequestsApiClientProvider);
    if (api == null) return const [];
    final workspaceId = await api.resolveWorkspaceId();
    final items = await api.listSharedRequests(workspaceId);
    return items.map(SharedRequestModel.fromJson).toList();
  }
}

final sharedRequestsProvider = AsyncNotifierProvider<SharedRequestsNotifier, List<SharedRequestModel>>(SharedRequestsNotifier.new);

class SharedRequestActions {
  SharedRequestActions(this.ref);

  final Ref ref;

  SharedRequestsApiClient _requireApiClient() {
    final api = ref.read(sharedRequestsApiClientProvider);
    if (api == null) {
      throw Exception('API source is not configured or authenticated');
    }
    return api;
  }

  Future<void> shareRequest({required Map<String, dynamic> request, required String targetWorkspaceId, String? note}) async {
    final api = _requireApiClient();
    final workspaceId = await api.resolveWorkspaceId();
    await api.shareRequest(workspaceId: workspaceId, targetWorkspaceId: targetWorkspaceId, request: request, note: note);
    ref.invalidate(sharedRequestsProvider);
  }

  Future<void> importSharedRequest({required String sharedRequestId, String? collectionId}) async {
    final api = _requireApiClient();
    final workspaceId = await api.resolveWorkspaceId();
    await api.importSharedRequest(workspaceId: workspaceId, sharedRequestId: sharedRequestId, collectionId: collectionId);
    ref.invalidate(sharedRequestsProvider);
    ref.invalidate(collectionsNotifierProvider);
    ref.invalidate(requestsNotifierProvider);
    ref.invalidate(environmentsNotifierProvider);
    ref.invalidate(activeEnvironmentNotifierProvider);
    ref.read(selectedCollectionIdProvider.notifier).select(null);
    await ref.read(activeEnvironmentNotifierProvider.notifier).setActiveEnvironment(null);
    ref.read(activeEnvironmentNameProvider.notifier).setActiveName(null);
  }
}

final sharedRequestActionsProvider = Provider<SharedRequestActions>((ref) => SharedRequestActions(ref));
