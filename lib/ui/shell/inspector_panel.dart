import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../state/workbench_notifier.dart';
import '../../state/workbench_state.dart';
import '../request/request_inspector_content.dart';
import '../widgets/widgets.dart';

class InspectorPanel extends ConsumerWidget {
  const InspectorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final activeTab = ref.watch(workbenchProvider.select((s) => s.activeTab));

    return Container(
      width: AppSizes.inspectorWidth,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(left: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            'Inspector',
            trailing: AppIconButton(
              icon: Icons.close,
              tooltip: 'Hide inspector',
              onPressed: () => ref.read(workbenchProvider.notifier).toggleInspector(),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _InspectorContent(tab: activeTab)),
        ],
      ),
    );
  }
}

class _InspectorContent extends StatelessWidget {
  const _InspectorContent({required this.tab});

  final WorkbenchTab? tab;

  @override
  Widget build(BuildContext context) {
    final activeTab = tab;
    if (activeTab == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: EmptyState(icon: Icons.info_outline, title: 'Nothing selected', message: 'Open a tab to see its details here.'),
      );
    }

    if (activeTab.type == WorkbenchTabType.request && activeTab.payloadId != null) {
      return RequestInspectorContent(requestId: activeTab.payloadId!);
    }

    return const Padding(
      padding: EdgeInsets.all(16),
      child: EmptyState(icon: Icons.info_outline, title: 'Details', message: 'Contextual info for this tab goes here.'),
    );
  }
}
