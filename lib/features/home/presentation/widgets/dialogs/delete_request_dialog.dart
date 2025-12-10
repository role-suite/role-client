import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/api_request_model.dart';

import '../../../../../core/presentation/widgets/app_button.dart';
import '../../viewmodels/home_dialog_view_models.dart';

class DeleteRequestDialog extends ConsumerStatefulWidget {
  const DeleteRequestDialog({
    super.key,
    required this.request,
  });

  final ApiRequestModel request;

  @override
  ConsumerState<DeleteRequestDialog> createState() => _DeleteRequestDialogState();
}

class _DeleteRequestDialogState extends ConsumerState<DeleteRequestDialog> {
  bool _isDeleting = false;

  Future<void> _handleDelete() async {
    final viewModel = ref.read(deleteEntitiesViewModelProvider);
    setState(() => _isDeleting = true);

    try {
      await viewModel.deleteRequest(widget.request);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request "${widget.request.name}" deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete request: $e'),
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
      title: const Text('Delete Request'),
      content: Text('Are you sure you want to delete "${widget.request.name}"?'),
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

