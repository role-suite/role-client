import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../state/workbench_notifier.dart';
import '../widgets/widgets.dart';
import 'tab_strip.dart';
import 'workbench_tab_content.dart';

class Workbench extends ConsumerWidget {
  const Workbench({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(workbenchProvider.select((s) => s.tabs));
    final activeTab = ref.watch(workbenchProvider.select((s) => s.activeTab));
    final colors = context.colors;

    return Container(
      color: colors.bg,
      child: Column(
        children: [
          if (tabs.isNotEmpty) const TabStrip(),
          Expanded(
            child: activeTab == null
                ? _WorkbenchEmptyState(hasClosedTabs: tabs.isNotEmpty)
                : IndexedStack(
                    index: tabs.indexOf(activeTab),
                    children: [for (final tab in tabs) buildWorkbenchTabContent(tab)],
                  ),
          ),
        ],
      ),
    );
  }
}

class _WorkbenchEmptyState extends StatelessWidget {
  const _WorkbenchEmptyState({required this.hasClosedTabs});

  final bool hasClosedTabs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: EmptyState(
        icon: Icons.bolt_outlined,
        title: 'Röle Workbench',
        message: 'Open a request from the sidebar, or create a new one to get started.',
      ),
    );
  }
}
