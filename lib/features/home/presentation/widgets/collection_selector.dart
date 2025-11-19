import 'package:flutter/material.dart';
import 'package:relay/core/model/collection_model.dart';

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

  @override
  Widget build(BuildContext context) {
    // Ensure default collection exists
    final allCollections = [
      if (!collections.any((c) => c.id == 'default'))
        CollectionModel(
          id: 'default',
          name: 'Default',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ...collections,
    ];

    final theme = Theme.of(context);
    final bool isDefaultSelected = selectedCollectionId == null || selectedCollectionId == 'default';
    final Color iconColor = isDefaultSelected ? theme.colorScheme.onSurface.withOpacity(0.6) : theme.colorScheme.primary;

    final selectedLabel = () {
      final collection = allCollections.firstWhere(
        (c) => c.id == selectedCollectionId,
        orElse: () => allCollections.first,
      );
      return collection.name.isNotEmpty ? collection.name : collection.id;
    }();

    return PopupMenuButton<String>(
      tooltip: 'Select Collection',
      icon: iconOnly
          ? Icon(Icons.folder, size: 24, color: iconColor)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder, size: 20, color: iconColor),
                const SizedBox(width: 4),
                Text(
                  selectedLabel,
                  style: theme.textTheme.labelMedium,
                ),
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
                if (selectedCollectionId == collection.id)
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
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
                      child: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.error,
                      ),
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


