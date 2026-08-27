import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/collection.dart';
import '../../core/theme/app_tokens.dart';
import '../../state/workspace_notifier.dart';
import '../remote_error.dart';
import '../widgets/widgets.dart';

Future<void> showCreateCollectionDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (context) => _NameDialog(title: 'New collection', controller: controller, confirmLabel: 'Create'),
  );
  if (name == null || name.trim().isEmpty) return;
  try {
    await ref.read(workspaceProvider.notifier).createCollection(name: name.trim());
  } catch (error) {
    if (context.mounted) showRemoteErrorSnackBar(context, 'Could not create collection', error);
  }
}

Future<void> showRenameCollectionDialog(BuildContext context, WidgetRef ref, Collection collection) async {
  final controller = TextEditingController(text: collection.name);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => _NameDialog(title: 'Rename collection', controller: controller, confirmLabel: 'Save'),
  );
  if (name == null || name.trim().isEmpty) return;
  try {
    await ref.read(workspaceProvider.notifier).updateCollection(collection.copyWith(name: name.trim(), updatedAt: DateTime.now()));
  } catch (error) {
    if (context.mounted) showRemoteErrorSnackBar(context, 'Could not rename collection', error);
  }
}

Future<void> showDeleteCollectionDialog(BuildContext context, WidgetRef ref, Collection collection) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete collection?'),
      content: Text('"${collection.name}" and all of its requests will be deleted. This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await ref.read(workspaceProvider.notifier).deleteCollection(collection.id);
  } catch (error) {
    if (context.mounted) showRemoteErrorSnackBar(context, 'Could not delete collection', error);
  }
}

class _NameDialog extends StatelessWidget {
  const _NameDialog({required this.title, required this.controller, required this.confirmLabel});

  final String title;
  final TextEditingController controller;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 320,
        child: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        const SizedBox(width: AppSpacing.xs),
        AppButton(label: confirmLabel, variant: AppButtonVariant.primary, onPressed: () => Navigator.of(context).pop(controller.text)),
      ],
    );
  }
}
