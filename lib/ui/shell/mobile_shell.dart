import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/role_theme.dart';
import '../../state/settings_providers.dart';
import '../../state/workbench_notifier.dart';
import '../../state/workbench_state.dart';
import '../environments/environments_sidebar_panel.dart';
import '../flows/flows_sidebar_panel.dart';
import '../history/history_sidebar_panel.dart';
import '../runner/runs_sidebar_panel.dart';
import '../sidebar/requests_sidebar_panel.dart';
import 'import_export_actions.dart';
import 'workbench_tab_content.dart';

/// Mobile navigation: bottom nav over the section panels the desktop
/// sidebar uses; opening a request/environment/run/flow pushes a
/// full-screen route instead of a workbench tab, since there's no
/// persistent tab strip or inspector on small screens.
class MobileShell extends ConsumerStatefulWidget {
  const MobileShell({super.key});

  @override
  ConsumerState<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends ConsumerState<MobileShell> {
  int? _lastOpenSignal;

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(workbenchProvider.select((s) => s.openSignal), (previous, next) {
      if (_lastOpenSignal == null) {
        _lastOpenSignal = next;
        return;
      }
      if (next == _lastOpenSignal) return;
      _lastOpenSignal = next;

      final tab = ref.read(workbenchProvider).activeTab;
      if (tab == null) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => _MobileTabScreen(tab: tab)));
    });

    final colors = context.colors;
    final section = ref.watch(workbenchProvider.select((s) => s.section));
    final themeMode = ref.watch(themeModeProvider);

    final content = switch (section) {
      WorkspaceSection.requests => const RequestsSidebarPanel(),
      WorkspaceSection.history => const HistorySidebarPanel(),
      WorkspaceSection.runs => const RunsSidebarPanel(),
      WorkspaceSection.flows => const FlowsSidebarPanel(),
      WorkspaceSection.environments => const EnvironmentsSidebarPanel(),
    };

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: const Text('Röle'),
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.file_upload_outlined), tooltip: 'Import', onPressed: () => runImportWorkspace(context, ref)),
          IconButton(icon: const Icon(Icons.file_download_outlined), tooltip: 'Export', onPressed: () => runExportWorkspace(context, ref)),
          IconButton(
            icon: Icon(themeModeIcon(themeMode)),
            tooltip: 'Theme: ${themeMode.name}',
            onPressed: () => ref.read(themeModeProvider.notifier).cycleThemeMode(),
          ),
        ],
      ),
      body: content,
      bottomNavigationBar: NavigationBar(
        backgroundColor: colors.surface,
        selectedIndex: WorkspaceSection.values.indexOf(section),
        onDestinationSelected: (i) => ref.read(workbenchProvider.notifier).selectSection(WorkspaceSection.values[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dns_outlined), label: 'Requests'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.play_circle_outline), label: 'Runs'),
          NavigationDestination(icon: Icon(Icons.alt_route), label: 'Flows'),
          NavigationDestination(icon: Icon(Icons.public), label: 'Env'),
        ],
      ),
    );
  }
}

class _MobileTabScreen extends StatelessWidget {
  const _MobileTabScreen({required this.tab});

  final WorkbenchTab tab;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: Text(tab.title), backgroundColor: colors.surface, foregroundColor: colors.textPrimary, elevation: 0),
      body: buildWorkbenchTabContent(tab),
    );
  }
}
