import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/models/data_source_config.dart';
import 'package:relay/core/models/workspace_member_model.dart';
import 'package:relay/features/home/presentation/providers/data_source_providers.dart';
import 'package:relay/features/home/presentation/providers/workspace_team_providers.dart';
import 'package:relay/features/home/presentation/workspace_team_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows validation error when join token is empty', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataSourceStateNotifierProvider.overrideWith(_NoApiDataSourceNotifier.new),
          currentWorkspaceIdProvider.overrideWith((ref) async => 'ws-1'),
          workspaceMembersProvider.overrideWith(_StaticMembersNotifier.new),
        ],
        child: const MaterialApp(home: WorkspaceTeamScreen()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Join workspace'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Join workspace'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an invitation token.'), findsOneWidget);
  });

  testWidgets('renders members list from provider', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataSourceStateNotifierProvider.overrideWith(_NoApiDataSourceNotifier.new),
          currentWorkspaceIdProvider.overrideWith((ref) async => 'ws-1'),
          workspaceMembersProvider.overrideWith(_StaticMembersNotifier.new),
        ],
        child: const MaterialApp(home: WorkspaceTeamScreen()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Alice Johnson'), 240, scrollable: find.byType(Scrollable).first);

    expect(find.text('Alice Johnson'), findsOneWidget);
    expect(find.text('alice@example.com'), findsOneWidget);
    expect(find.text('admin'), findsOneWidget);
  });
}

class _NoApiDataSourceNotifier extends DataSourceStateNotifier {
  @override
  Future<({DataSourceMode mode, DataSourceConfig config})> build() async {
    return (mode: DataSourceMode.local, config: const DataSourceConfig(baseUrl: ''));
  }
}

class _StaticMembersNotifier extends WorkspaceMembersNotifier {
  @override
  Future<List<WorkspaceMemberModel>> build() async {
    return [WorkspaceMemberModel(userId: 'u1', name: 'Alice Johnson', email: 'alice@example.com', role: 'admin', status: 'active')];
  }
}
