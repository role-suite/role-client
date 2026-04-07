import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/models/workspace_summary_model.dart';
import 'package:relay/core/services/role_node_api/workspaces_api_client.dart';
import 'package:relay/core/services/workspace_preferences_service.dart';
import 'package:relay/features/home/collection/presentation/providers/collection_providers.dart';
import 'package:relay/features/home/environment/presentation/providers/environment_providers.dart';
import 'package:relay/features/home/presentation/providers/data_source_providers.dart';
import 'package:relay/features/home/presentation/providers/home_ui_providers.dart';
import 'package:relay/features/home/request/presentation/providers/request_providers.dart';

final workspacesApiClientProvider = Provider<WorkspacesApiClient?>((ref) {
  final state = ref.watch(currentDataSourceStateProvider);
  if (state == null || !state.config.isValid) return null;
  final accessToken = state.config.apiKey?.trim();
  if (accessToken == null || accessToken.isEmpty) return null;
  if (state.mode != DataSourceMode.api) return null;
  return WorkspacesApiClient(baseUrl: state.config.baseUrl, accessToken: accessToken);
});

class WorkspacesNotifier extends AsyncNotifier<List<WorkspaceSummaryModel>> {
  @override
  Future<List<WorkspaceSummaryModel>> build() async {
    final api = ref.watch(workspacesApiClientProvider);
    if (api == null) return const [];
    final data = await api.listWorkspaces();
    return data.map(WorkspaceSummaryModel.fromJson).toList();
  }
}

final workspacesProvider = AsyncNotifierProvider<WorkspacesNotifier, List<WorkspaceSummaryModel>>(WorkspacesNotifier.new);

class ActiveWorkspaceIdNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final state = ref.watch(currentDataSourceStateProvider);
    if (state == null || state.mode != DataSourceMode.api || !state.config.isValid) return null;
    final accessToken = state.config.apiKey?.trim();
    if (accessToken == null || accessToken.isEmpty) return null;

    final workspaces = await ref.watch(workspacesProvider.future);
    if (workspaces.isEmpty) return null;

    final saved = await WorkspacePreferencesService.loadActiveWorkspaceId(state.config.baseUrl);
    final active = workspaces.any((w) => w.id == saved) ? saved : workspaces.first.id;
    if (active != null) {
      await WorkspacePreferencesService.saveActiveWorkspaceId(state.config.baseUrl, active);
    }
    return active;
  }

  Future<void> setActiveWorkspaceId(String workspaceId) async {
    final stateValue = ref.read(currentDataSourceStateProvider);
    if (stateValue == null || !stateValue.config.isValid) return;
    await WorkspacePreferencesService.saveActiveWorkspaceId(stateValue.config.baseUrl, workspaceId);
    state = AsyncData(workspaceId);

    ref.read(selectedCollectionIdProvider.notifier).select(null);
    ref.read(activeEnvironmentNameProvider.notifier).setActiveName(null);
  }

  Future<void> refreshFromServer() async {
    state = const AsyncLoading();
    state = AsyncData(await build());
  }
}

final activeWorkspaceIdProvider = AsyncNotifierProvider<ActiveWorkspaceIdNotifier, String?>(ActiveWorkspaceIdNotifier.new);

final activeWorkspaceProvider = Provider<WorkspaceSummaryModel?>((ref) {
  final activeId = ref.watch(activeWorkspaceIdProvider).asData?.value;
  if (activeId == null) return null;
  final workspaces = ref.watch(workspacesProvider).asData?.value ?? const [];
  for (final workspace in workspaces) {
    if (workspace.id == activeId) return workspace;
  }
  return null;
});
