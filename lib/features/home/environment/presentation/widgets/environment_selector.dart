import 'package:flutter/material.dart';
import 'package:relay/core/models/environment_model.dart';

const String _noEnvironmentMenuValue = '__menu_no_environment__';

class EnvironmentSelector extends StatelessWidget {
  const EnvironmentSelector({
    super.key,
    required this.envs,
    required this.activeEnvName,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    this.iconOnly = false,
  });

  final List<EnvironmentModel> envs;
  final String? activeEnvName;
  final ValueChanged<String?> onSelect;
  final void Function(EnvironmentModel env) onEdit;
  final void Function(EnvironmentModel env) onDelete;
  final bool iconOnly;

  Future<void> _openMobileSelector(BuildContext context, ThemeData theme) async {
    final selectedName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.7;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Select Environment', style: theme.textTheme.titleMedium),
                ),
                const Divider(height: 0),
                Expanded(
                  child: ListView.separated(
                    itemCount: envs.length + 1,
                    separatorBuilder: (_, _) => const Divider(height: 0),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return ListTile(
                          leading: activeEnvName == null ? const Icon(Icons.check) : const SizedBox(width: 24),
                          title: const Text('No Environment'),
                          onTap: () => Navigator.of(context).pop(_noEnvironmentMenuValue),
                        );
                      }
                      final env = envs[index - 1];
                      final isSelected = activeEnvName == env.name;
                      return ListTile(
                        leading: isSelected ? const Icon(Icons.check) : const SizedBox(width: 24),
                        title: Text(env.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => Navigator.of(context).pop(env.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit environment',
                              onPressed: () {
                                Navigator.of(context).pop();
                                onEdit(env);
                              },
                              icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                            ),
                            IconButton(
                              tooltip: 'Delete environment',
                              onPressed: () {
                                Navigator.of(context).pop();
                                onDelete(env);
                              },
                              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedName != null) {
      onSelect(selectedName == _noEnvironmentMenuValue ? null : selectedName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool hasEnvironment = activeEnvName != null && activeEnvName!.isNotEmpty;
    final Color iconColor = hasEnvironment ? theme.colorScheme.secondary : theme.colorScheme.onSurface.withValues(alpha: 0.6);

    if (iconOnly) {
      return IconButton(
        tooltip: 'Select Environment',
        icon: Icon(Icons.cloud, size: 24, color: iconColor),
        onPressed: () => _openMobileSelector(context, theme),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Select Environment',
      color: theme.colorScheme.surfaceContainerHighest,
      surfaceTintColor: theme.colorScheme.surfaceContainerHighest,
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud, size: 20, color: iconColor),
          const SizedBox(width: 4),
          Text(activeEnvName ?? 'No Env', style: theme.textTheme.labelMedium),
        ],
      ),
      onSelected: (name) => onSelect(name == _noEnvironmentMenuValue ? null : name),
      itemBuilder: (context) => [
        const PopupMenuItem<String>(value: _noEnvironmentMenuValue, child: Text('No Environment')),
        if (envs.isNotEmpty) const PopupMenuDivider(),
        ...envs.map(
          (env) => PopupMenuItem<String>(
            value: env.name,
            child: Row(
              children: [
                if (activeEnvName == env.name) const Icon(Icons.check, size: 18) else const SizedBox(width: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(env.name)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    onEdit(env);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.edit_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    onDelete(env);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline, size: 16, color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
