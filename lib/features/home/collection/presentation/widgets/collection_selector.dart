import 'package:flutter/material.dart';
import 'package:relay/core/models/collection_model.dart';

class CollectionSelector extends StatelessWidget {
  const CollectionSelector({
    super.key,
    required this.collections,
    required this.selectedCollectionId,
    required this.onSelect,
    required this.onDelete,
    this.iconOnly = false,
  });

  final List<CollectionModel> collections;
  final String? selectedCollectionId;
  final ValueChanged<String> onSelect;
  final void Function(CollectionModel collection) onDelete;
  final bool iconOnly;

  Future<void> _openMobileSelector(BuildContext context, ThemeData theme, List<CollectionModel> allCollections) async {
    final selectedId = await showModalBottomSheet<String>(
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
                  child: Text('Select Collection', style: theme.textTheme.titleMedium),
                ),
                const Divider(height: 0),
                Expanded(
                  child: ListView.separated(
                    itemCount: allCollections.length,
                    separatorBuilder: (_, _) => const Divider(height: 0),
                    itemBuilder: (context, index) {
                      final collection = allCollections[index];
                      final displayName = collection.name.isNotEmpty ? collection.name : collection.id;
                      final isDefault = collection.id == 'default';
                      final isSelected = selectedCollectionId == collection.id;

                      return ListTile(
                        leading: isSelected ? const Icon(Icons.check) : const SizedBox(width: 24),
                        title: Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => Navigator.of(context).pop(collection.id),
                        trailing: isDefault
                            ? null
                            : IconButton(
                                tooltip: 'Delete collection',
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  onDelete(collection);
                                },
                                icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
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

    if (selectedId != null) {
      onSelect(selectedId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (collections.isEmpty) {
      return const SizedBox.shrink();
    }

    final allCollections = collections;

    final theme = Theme.of(context);
    final bool isDefaultSelected = selectedCollectionId == null || selectedCollectionId == 'default';
    final Color iconColor = isDefaultSelected ? theme.colorScheme.onSurface.withValues(alpha: 0.6) : theme.colorScheme.primary;

    final selectedLabel = () {
      final collection = allCollections.firstWhere((c) => c.id == selectedCollectionId, orElse: () => allCollections.first);
      return collection.name.isNotEmpty ? collection.name : collection.id;
    }();

    if (iconOnly) {
      return IconButton(
        tooltip: 'Select Collection',
        icon: Icon(Icons.folder, size: 24, color: iconColor),
        onPressed: () => _openMobileSelector(context, theme, allCollections),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Select Collection',
      color: theme.colorScheme.surfaceContainerHighest,
      surfaceTintColor: theme.colorScheme.surfaceContainerHighest,
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder, size: 20, color: iconColor),
          const SizedBox(width: 4),
          Text(selectedLabel, style: theme.textTheme.labelMedium),
        ],
      ),
      onSelected: onSelect,
      itemBuilder: (context) => [
        ...allCollections.map((collection) {
          // Ensure we have a valid name to display
          final displayName = collection.name.isNotEmpty ? collection.name : collection.id;
          final isDefault = collection.id == 'default';
          return PopupMenuItem(
            value: collection.id,
            child: Row(
              children: [
                if (selectedCollectionId == collection.id) const Icon(Icons.check, size: 18) else const SizedBox(width: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(displayName)),
                if (!isDefault) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop(); // Close the menu
                      onDelete(collection);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline, size: 18, color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}
