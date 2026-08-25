import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../state/auth_notifier.dart';
import '../../state/workbench_notifier.dart';
import 'import_export_actions.dart';
import 'inspector_panel.dart';
import 'mobile_shell.dart';
import 'responsive.dart';
import 'side_rail.dart';
import 'sidebar_panel.dart';
import 'status_bar.dart';
import 'top_bar.dart';
import 'workbench.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  double _sidebarWidth = AppSizes.sidebarWidthDefault;

  @override
  void initState() {
    super.initState();
    // Re-hydrates a previously signed-in session, if any. No-op with no
    // network/UI effect for the large majority of users who never signed in
    // — see AuthNotifier.restore().
    Future.microtask(() => ref.read(authNotifierProvider.notifier).restore());
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktop(context)) {
      return const MobileShell();
    }

    final colors = context.colors;
    final sidebarCollapsed = ref.watch(workbenchProvider.select((s) => s.sidebarCollapsed));
    final inspectorVisible = ref.watch(workbenchProvider.select((s) => s.inspectorVisible));

    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: [
          TopBar(onImport: () => runImportWorkspace(context, ref), onExport: () => runExportWorkspace(context, ref)),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SideRail(),
                if (!sidebarCollapsed) ...[
                  SidebarPanel(width: _sidebarWidth),
                  _SidebarResizeHandle(
                    onDrag: (dx) => setState(() {
                      _sidebarWidth = (_sidebarWidth + dx).clamp(AppSizes.sidebarWidthMin, AppSizes.sidebarWidthMax);
                    }),
                  ),
                ],
                const Expanded(child: Workbench()),
                if (inspectorVisible) const InspectorPanel(),
              ],
            ),
          ),
          const StatusBar(),
        ],
      ),
    );
  }
}

class _SidebarResizeHandle extends StatelessWidget {
  const _SidebarResizeHandle({required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        child: SizedBox(width: 4, child: ColoredBox(color: Colors.transparent)),
      ),
    );
  }
}
