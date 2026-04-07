import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/models/user_profile_model.dart';
import 'package:relay/core/services/role_node_api/auth_api_client.dart';
import 'package:relay/features/home/collection/presentation/providers/collection_providers.dart';
import 'package:relay/features/home/environment/presentation/providers/environment_providers.dart';
import 'package:relay/features/home/presentation/providers/data_source_providers.dart';
import 'package:relay/features/home/presentation/providers/home_ui_providers.dart';
import 'package:relay/features/home/presentation/providers/workspace_team_providers.dart';
import 'package:relay/features/home/presentation/providers/workspace_selection_providers.dart';
import 'package:relay/features/home/request/presentation/providers/request_providers.dart';

final profileApiClientProvider = Provider<AuthApiClient?>((ref) {
  final state = ref.watch(currentDataSourceStateProvider);
  if (state == null || !state.config.isValid) return null;
  return AuthApiClient(baseUrl: state.config.baseUrl);
});

class UserProfileNotifier extends AsyncNotifier<UserProfileModel?> {
  @override
  Future<UserProfileModel?> build() async {
    final api = ref.watch(profileApiClientProvider);
    final state = ref.watch(currentDataSourceStateProvider);
    if (api == null || state == null) return null;
    final accessToken = state.config.apiKey?.trim();
    if (accessToken == null || accessToken.isEmpty) return null;
    final data = await api.me(accessToken);
    final nested = data['user'];
    if (nested is Map<String, dynamic>) {
      return UserProfileModel.fromJson(nested);
    }
    return UserProfileModel.fromJson(data);
  }
}

final userProfileProvider = AsyncNotifierProvider<UserProfileNotifier, UserProfileModel?>(UserProfileNotifier.new);

class ProfileActions {
  ProfileActions(this.ref);

  final Ref ref;

  Future<void> logout() async {
    final state = ref.read(currentDataSourceStateProvider);
    if (state == null) return;
    final config = state.config;
    final refreshToken = config.refreshToken?.trim();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        final authApi = AuthApiClient(baseUrl: config.baseUrl);
        await authApi.logout(refreshToken);
      } catch (_) {
        // Ignore logout failures and still clear local state.
      }
    }

    await ref.read(dataSourceStateNotifierProvider.notifier).setConfig(config.copyWith(apiKey: null, refreshToken: null));
    await ref.read(dataSourceStateNotifierProvider.notifier).setMode(DataSourceMode.local);

    ref.invalidate(userProfileProvider);
    ref.invalidate(workspaceMembersProvider);
    ref.invalidate(currentWorkspaceIdProvider);
    ref.invalidate(workspacesProvider);
    ref.invalidate(activeWorkspaceIdProvider);
    ref.invalidate(collectionsNotifierProvider);
    ref.invalidate(requestsNotifierProvider);
    ref.invalidate(environmentsNotifierProvider);
    ref.invalidate(activeEnvironmentNotifierProvider);

    ref.read(selectedCollectionIdProvider.notifier).select(null);
    await ref.read(activeEnvironmentNotifierProvider.notifier).setActiveEnvironment(null);
    ref.read(activeEnvironmentNameProvider.notifier).setActiveName(null);
  }
}

final profileActionsProvider = Provider<ProfileActions>((ref) => ProfileActions(ref));
