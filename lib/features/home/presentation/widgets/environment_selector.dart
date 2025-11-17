import 'package:flutter/material.dart';
import 'package:relay/core/model/environment_model.dart';

class EnvironmentSelector extends StatelessWidget {
  const EnvironmentSelector({
    super.key,
    required this.envs,
    required this.activeEnvName,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final List<EnvironmentModel> envs;
  final String? activeEnvName;
  final ValueChanged<String?> onSelect;
  final void Function(EnvironmentModel env) onEdit;
  final void Function(EnvironmentModel env) onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud, size: 20),
          const SizedBox(width: 4),
          Text(
            activeEnvName ?? 'No Env',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
      onSelected: (name) => onSelect(name),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: null,
          child: Text('No Environment'),
        ),
        if (envs.isNotEmpty) const PopupMenuDivider(),
        ...envs.map(
          (env) => PopupMenuItem(
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


