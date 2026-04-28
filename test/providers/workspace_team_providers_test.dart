import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/models/data_source_config.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/services/relay_api/workspaces_api_client.dart';
import 'package:relay/features/home/environment/presentation/providers/environment_providers.dart';
import 'package:relay/features/home/presentation/providers/data_source_providers.dart';
import 'package:relay/features/home/presentation/providers/workspace_selection_providers.dart';
import 'package:relay/features/home/presentation/providers/workspace_team_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeWorkspacesApiClient extends WorkspacesApiClient {
  _FakeWorkspacesApiClient({
    this.joinResponse = const <String, dynamic>{},
    this.membersResponse = const <Map<String, dynamic>>[],
  }) : super(baseUrl: 'https://example.com', accessToken: 'token');

  final Map<String, dynamic> joinResponse;
  final List<Map<String, dynamic>> membersResponse;

  @override
  Future<String> resolveWorkspaceId() async => 'ws-resolved';

  @override
  Future<Map<String, dynamic>> joinWorkspace({required String token}) async => joinResponse;

  @override
  Future<List<Map<String, dynamic>>> listMembers(String workspaceId) async => membersResponse;
}

class _FakeActiveWorkspaceIdNotifier extends ActiveWorkspaceIdNotifier {
  static String? lastSetWorkspaceId;

  @override
  Future<String?> build() async => null;

  @override
  Future<void> setActiveWorkspaceId(String workspaceId) async {
    lastSetWorkspaceId = workspaceId;
    state = AsyncData(workspaceId);
  }

  @override
  Future<void> refreshFromServer() async {
    state = const AsyncData(null);
  }
}

class _FakeActiveEnvironmentNotifier extends ActiveEnvironmentNotifier {
  @override
  Future<EnvironmentModel?> build() async => null;

  @override
  Future<void> setActiveEnvironment(String? name) async {
    state = const AsyncData(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('workspaceMembersProvider maps nested user payload shape', () async {
    final container = ProviderContainer(
      overrides: [
        workspaceTeamApiClientProvider.overrideWithValue(
          _FakeWorkspacesApiClient(
            membersResponse: const [
              {
                'id': 'm1',
                'role': 'admin',
                'user': {'id': 'u1', 'name': 'Alice', 'email': 'alice@example.com'},
              },
            ],
          ),
        ),
        activeWorkspaceIdProvider.overrideWith(_FakeActiveWorkspaceIdNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    final members = await container.read(workspaceMembersProvider.future);
    expect(members, hasLength(1));
    expect(members.first.userId, 'u1');
    expect(members.first.name, 'Alice');
    expect(members.first.email, 'alice@example.com');
    expect(members.first.role, 'admin');
  });

  test('joinWorkspace accepts workspace_id response shape', () async {
    _FakeActiveWorkspaceIdNotifier.lastSetWorkspaceId = null;
    final container = ProviderContainer(
      overrides: [
        currentDataSourceStateProvider.overrideWithValue(
          (
            mode: DataSourceMode.api,
            config: const DataSourceConfig(baseUrl: 'https://example.com', apiKey: 'token'),
          ),
        ),
        workspaceTeamApiClientProvider.overrideWithValue(
          _FakeWorkspacesApiClient(
            joinResponse: const {
              'workspace_id': 'ws-nested-7',
            },
          ),
        ),
        activeWorkspaceIdProvider.overrideWith(_FakeActiveWorkspaceIdNotifier.new),
        activeEnvironmentNotifierProvider.overrideWith(_FakeActiveEnvironmentNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    final actions = container.read(workspaceTeamActionsProvider);
    await actions.joinWorkspace(token: 'token-123');

    expect(_FakeActiveWorkspaceIdNotifier.lastSetWorkspaceId, 'ws-nested-7');
  });
}
