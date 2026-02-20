import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/environment_model.dart';

import '../../../../../core/presentation/widgets/app_button.dart';
import '../../viewmodels/home_dialog_view_models.dart';

class DeleteEnvironmentDialog extends ConsumerStatefulWidget {
  const DeleteEnvironmentDialog({super.key, required this.environment});

  final EnvironmentModel environment;

  @override
  ConsumerState<DeleteEnvironmentDialog> createState() => _DeleteEnvironmentDialogState();
}

class _DeleteEnvironmentDialogState extends ConsumerState<DeleteEnvironmentDialog> {
  bool _isDeleting = false;

  Future<void> _handleDelete() async {
    final viewModel = ref.read(deleteEntitiesViewModelProvider);
    setState(() => _isDeleting = true);

    try {
      await viewModel.deleteEnvironment(widget.environment);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Environment "${widget.environment.name}" deleted successfully'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete environment: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Environment'),
      content: Text(
        'Are you sure you want to delete "${widget.environment.name}"?\n\n'
        'This action cannot be undone.',
      ),
      actions: [
        TextButton(onPressed: _isDeleting ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        AppButton(label: _isDeleting ? 'Deleting...' : 'Delete', variant: AppButtonVariant.danger, onPressed: _isDeleting ? null : _handleDelete),
      ],
    );
  }
}
