import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../state/chains_notifier.dart';
import '../../state/workbench_notifier.dart';
import '../../state/workbench_state.dart';
import '../widgets/widgets.dart';
import 'flow_dialogs.dart';

class FlowsSidebarPanel extends ConsumerWidget {
  const FlowsSidebarPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chains = ref.watch(chainsProvider);
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Flows',
          trailing: AppIconButton(
            icon: Icons.add,
            tooltip: 'New flow',
            onPressed: () async {
              final chain = await ref.read(chainsProvider.notifier).create(name: 'New Flow');
              ref.read(workbenchProvider.notifier).openTab(type: WorkbenchTabType.flow, title: chain.name, payloadId: chain.id);
            },
          ),
        ),
        Expanded(
          child: chains.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (error, _) => Padding(padding: const EdgeInsets.all(16), child: Text('$error')),
            data: (list) {
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: EmptyState(icon: Icons.alt_route, title: 'No flows yet', message: 'Chain requests together to run them in sequence.'),
                );
              }
              return ListView(
                children: [
                  for (final chain in list)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () =>
                            ref.read(workbenchProvider.notifier).openTab(type: WorkbenchTabType.flow, title: chain.name, payloadId: chain.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                          child: Row(
                            children: [
                              Icon(Icons.alt_route, size: 14, color: colors.textMuted),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(chain.name, style: context.type.body, overflow: TextOverflow.ellipsis),
                              ),
                              Text('${chain.steps.length}', style: context.type.caption),
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_horiz, size: 14, color: colors.textMuted),
                                color: colors.surfaceRaised,
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppRadius.mdRadius,
                                  side: BorderSide(color: colors.border),
                                ),
                                itemBuilder: (context) => const [PopupMenuItem(value: 'delete', child: Text('Delete'))],
                                onSelected: (action) {
                                  if (action == 'delete') {
                                    ref.read(workbenchProvider.notifier).closeTab(WorkbenchTab.idFor(WorkbenchTabType.flow, chain.id));
                                    showDeleteFlowDialog(context, ref, chain);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
