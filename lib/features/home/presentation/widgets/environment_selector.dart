import 'package:flutter/material.dart';
import 'package:relay/core/model/environment_model.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool hasEnvironment = activeEnvName != null && activeEnvName!.isNotEmpty;
    final Color iconColor =
        hasEnvironment ? theme.colorScheme.secondary : theme.colorScheme.onSurface.withOpacity(0.6);

    return PopupMenuButton<String>(
      tooltip: 'Select Environment',
      color: theme.colorScheme.surfaceContainerHighest,
      surfaceTintColor: theme.colorScheme.surfaceContainerHighest,
      icon: iconOnly
          ? Icon(Icons.cloud, size: 24, color: iconColor)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud, size: 20, color: iconColor),
                const SizedBox(width: 4),
                Text(
                  activeEnvName ?? 'No Env',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
      onSelected: (name) => onSelect(name == _noEnvironmentMenuValue ? null : name),
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: _noEnvironmentMenuValue,
          child: Text('No Environment'),
        ),
        if (envs.isNotEmpty) const PopupMenuDivider(),
        ...envs.map(
          (env) => PopupMenuItem<String>(
            value: env.name,
            child: Row(
              children: [
                if (activeEnvName == env.name)
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
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
                    child: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
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
                    child: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.error,
                    ),
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


