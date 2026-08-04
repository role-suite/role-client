import 'package:flutter/material.dart';

class RoleShell extends StatelessWidget {
  const RoleShell({
    super.key,
    required this.topBar,
    required this.leftRail,
    required this.sidebarPanel,
    required this.workbench,
    required this.inspector,
    required this.statusBar,
    this.sidebarWidth = 320,
    this.inspectorWidth = 280,
    this.showSidebar = true,
    this.showInspector = true,
  });

  final Widget topBar;
  final Widget leftRail;
  final Widget sidebarPanel;
  final Widget workbench;
  final Widget inspector;
  final Widget statusBar;
  final double sidebarWidth;
  final double inspectorWidth;
  final bool showSidebar;
  final bool showInspector;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          topBar,
          Expanded(
            child: Row(
              children: [
                leftRail,
                if (showSidebar) SizedBox(width: sidebarWidth, child: sidebarPanel),
                Expanded(child: workbench),
                if (showInspector) ...[
                  VerticalDivider(width: 1, thickness: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7)),
                  SizedBox(width: inspectorWidth, child: inspector),
                ],
              ],
            ),
          ),
          statusBar,
        ],
      ),
    );
  }
}
