import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/collection_model.dart';

import '../../../../../core/presentation/widgets/app_button.dart';
import '../../viewmodels/home_dialog_view_models.dart';

class DeleteCollectionDialog extends ConsumerStatefulWidget {
  const DeleteCollectionDialog({
    super.key,
    required this.collection,
  });

  final CollectionModel collection;

  @override
  ConsumerState<DeleteCollectionDialog> createState() => _DeleteCollectionDialogState();
}

class _DeleteCollectionDialogState extends ConsumerState<DeleteCollectionDialog> {
  bool _isDeleting = false;

  Future<void> _handleDelete() async {
    final viewModel = ref.read(deleteEntitiesViewModelProvider);
    setState(() => _isDeleting = true);

    try {
      await viewModel.deleteCollection(widget.collection);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Collection "${widget.collection.name}" and its requests deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete collection: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Collection'),
      content: Text(
        'Are you sure you want to delete "${widget.collection.name}"?\n\n'
        'This will also delete all requests in this collection. This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: _isDeleting ? 'Deleting...' : 'Delete',
          variant: AppButtonVariant.danger,
          onPressed: _isDeleting ? null : _handleDelete,
        ),
      ],
    );
  }
}

