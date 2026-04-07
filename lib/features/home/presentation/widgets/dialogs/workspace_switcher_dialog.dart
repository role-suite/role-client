import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/features/home/presentation/providers/providers.dart';

class WorkspaceSwitcherDialog extends ConsumerStatefulWidget {
  const WorkspaceSwitcherDialog({super.key});

  @override
  ConsumerState<WorkspaceSwitcherDialog> createState() => _WorkspaceSwitcherDialogState();
}

class _WorkspaceSwitcherDialogState extends ConsumerState<WorkspaceSwitcherDialog> {
  bool _isUpdating = false;

  Future<void> _selectWorkspace(String workspaceId) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      await ref.read(activeWorkspaceIdProvider.notifier).setActiveWorkspaceId(workspaceId);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workspacesAsync = ref.watch(workspacesProvider);
    final activeWorkspaceId = ref.watch(activeWorkspaceIdProvider).asData?.value;

    return AlertDialog(
      title: const Text('Switch workspace'),
      content: SizedBox(
        width: 420,
        child: workspacesAsync.when(
          data: (workspaces) {
            if (workspaces.isEmpty) {
              return Text('No workspaces found.', style: theme.textTheme.bodySmall);
            }
            return ListView.separated(
              shrinkWrap: true,
              itemCount: workspaces.length,
              separatorBuilder: (_, _) => const Divider(height: 12),
              itemBuilder: (context, index) {
                final workspace = workspaces[index];
                final selected = workspace.id == activeWorkspaceId;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(workspace.name),
                  subtitle: workspace.type.trim().isEmpty ? null : Text(workspace.type),
                  trailing: selected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                  onTap: _isUpdating || selected ? null : () => _selectWorkspace(workspace.id),
                );
              },
            );
          },
          loading: () => const SizedBox(height: 32, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          error: (error, _) => Text(error.toString(), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
        ),
      ),
      actions: [TextButton(onPressed: _isUpdating ? null : () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}
