import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../state/workbench_notifier.dart';
import '../../state/workbench_state.dart';
import '../environments/environments_sidebar_panel.dart';
import '../flows/flows_sidebar_panel.dart';
import '../history/history_sidebar_panel.dart';
import '../runner/runs_sidebar_panel.dart';
import '../sidebar/requests_sidebar_panel.dart';

class SidebarPanel extends ConsumerWidget {
  const SidebarPanel({super.key, this.width = AppSizes.sidebarWidthDefault});

  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final section = ref.watch(workbenchProvider.select((s) => s.section));

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.border)),
      ),
      child: switch (section) {
        WorkspaceSection.requests => const RequestsSidebarPanel(),
        WorkspaceSection.history => const HistorySidebarPanel(),
        WorkspaceSection.runs => const RunsSidebarPanel(),
        WorkspaceSection.flows => const FlowsSidebarPanel(),
        WorkspaceSection.environments => const EnvironmentsSidebarPanel(),
      },
    );
  }
}
