import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/workspace_invitation_model.dart';
import 'package:relay/core/models/workspace_member_model.dart';
import 'package:relay/core/services/relay_api/workspaces_api_client.dart';
import 'package:relay/features/home/presentation/providers/data_source_providers.dart';
import 'package:relay/features/home/presentation/providers/home_ui_providers.dart';
import 'package:relay/features/home/presentation/providers/workspace_selection_providers.dart';
import 'package:relay/features/home/collection/presentation/providers/collection_providers.dart';
import 'package:relay/features/home/environment/presentation/providers/environment_providers.dart';
import 'package:relay/features/home/request/presentation/providers/request_providers.dart';

final workspaceTeamApiClientProvider = Provider<WorkspacesApiClient?>((ref) {
  final state = ref.watch(currentDataSourceStateProvider);
  final activeWorkspaceId = ref.watch(activeWorkspaceIdProvider).asData?.value;
  if (state == null || !state.config.isValid) return null;
  final accessToken = state.config.apiKey?.trim();
  if (accessToken == null || accessToken.isEmpty) return null;
  return WorkspacesApiClient(baseUrl: state.config.baseUrl, accessToken: accessToken, workspaceId: activeWorkspaceId);
});

final currentWorkspaceIdProvider = FutureProvider<String?>((ref) async {
  final api = ref.watch(workspaceTeamApiClientProvider);
  if (api == null) return null;
  final activeWorkspaceId = ref.watch(activeWorkspaceIdProvider).asData?.value;
  if (activeWorkspaceId != null && activeWorkspaceId.isNotEmpty) return activeWorkspaceId;
  return api.resolveWorkspaceId();
});

class WorkspaceMembersNotifier extends AsyncNotifier<List<WorkspaceMemberModel>> {
  @override
  Future<List<WorkspaceMemberModel>> build() async {
    final api = ref.watch(workspaceTeamApiClientProvider);
    if (api == null) return const [];
    final workspaceId = await api.resolveWorkspaceId();
    final members = await api.listMembers(workspaceId);
    return members.map(WorkspaceMemberModel.fromJson).toList();
  }
}

final workspaceMembersProvider = AsyncNotifierProvider<WorkspaceMembersNotifier, List<WorkspaceMemberModel>>(WorkspaceMembersNotifier.new);

class WorkspaceTeamActions {
  WorkspaceTeamActions(this.ref);

  final Ref ref;

  WorkspacesApiClient _requireApiClient() {
    final api = ref.read(workspaceTeamApiClientProvider);
    if (api == null) {
      throw Exception('API source is not configured or authenticated');
    }
    return api;
  }

  Future<String> _requireWorkspaceId() async {
    final api = _requireApiClient();
    final activeWorkspaceId = ref.read(activeWorkspaceIdProvider).asData?.value;
    if (activeWorkspaceId != null && activeWorkspaceId.isNotEmpty) {
      return activeWorkspaceId;
    }
    return api.resolveWorkspaceId();
  }

  void _invalidateWorkspaceProviders() {
    ref.invalidate(collectionsNotifierProvider);
    ref.invalidate(requestsNotifierProvider);
    ref.invalidate(environmentsNotifierProvider);
    ref.invalidate(activeEnvironmentNotifierProvider);
  }

  Future<void> _resetSelectionAndEnvironment() async {
    ref.read(selectedCollectionIdProvider.notifier).select(null);
    await ref.read(activeEnvironmentNotifierProvider.notifier).setActiveEnvironment(null);
    ref.read(activeEnvironmentNameProvider.notifier).setActiveName(null);
  }

  Future<WorkspaceInvitationModel> inviteMember({required String email, required String role}) async {
    final api = _requireApiClient();
    final workspaceId = await _requireWorkspaceId();
    final response = await api.createInvitation(workspaceId: workspaceId, email: email, role: role);
    ref.invalidate(workspaceMembersProvider);
    return WorkspaceInvitationModel.fromJson(response);
  }

  Future<void> joinWorkspace({required String token}) async {
    final api = _requireApiClient();
    final response = await api.joinWorkspace(token: token);
    final workspaceId = response['workspaceId'] ?? response['id'];
    if (workspaceId != null) {
      await ref.read(activeWorkspaceIdProvider.notifier).setActiveWorkspaceId(workspaceId.toString());
    } else {
      ref.invalidate(workspacesProvider);
      await ref.read(activeWorkspaceIdProvider.notifier).refreshFromServer();
    }
    ref.invalidate(currentWorkspaceIdProvider);
    ref.invalidate(workspaceMembersProvider);
    _invalidateWorkspaceProviders();
    await _resetSelectionAndEnvironment();
  }

  Future<void> leaveWorkspace() async {
    final api = _requireApiClient();
    final workspaceId = await _requireWorkspaceId();
    await api.leaveWorkspace(workspaceId);
    ref.invalidate(workspacesProvider);
    await ref.read(activeWorkspaceIdProvider.notifier).refreshFromServer();
    ref.invalidate(currentWorkspaceIdProvider);
    ref.invalidate(workspaceMembersProvider);
    _invalidateWorkspaceProviders();
    await _resetSelectionAndEnvironment();
  }

  Future<void> convertToTeam({String? teamName}) async {
    final api = _requireApiClient();
    final workspaceId = await _requireWorkspaceId();
    await api.convertToTeam(workspaceId: workspaceId, teamName: teamName);
    ref.invalidate(workspacesProvider);
    await ref.read(activeWorkspaceIdProvider.notifier).refreshFromServer();
    ref.invalidate(currentWorkspaceIdProvider);
    ref.invalidate(workspaceMembersProvider);
    _invalidateWorkspaceProviders();
    await _resetSelectionAndEnvironment();
  }

  Future<void> updateMemberRole({required String memberUserId, required String role}) async {
    final api = _requireApiClient();
    final workspaceId = await _requireWorkspaceId();
    await api.updateMemberRole(workspaceId: workspaceId, memberUserId: memberUserId, role: role);
    ref.invalidate(workspaceMembersProvider);
  }

  Future<void> removeMember({required String memberUserId}) async {
    final api = _requireApiClient();
    final workspaceId = await _requireWorkspaceId();
    await api.removeMember(workspaceId: workspaceId, memberUserId: memberUserId);
    ref.invalidate(workspaceMembersProvider);
  }
}

final workspaceTeamActionsProvider = Provider<WorkspaceTeamActions>((ref) => WorkspaceTeamActions(ref));
