import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/ui/widgets/widgets.dart';

import '../../../../../core/util/extension.dart';
import '../../controllers/request_form_controller.dart';
import '../../providers/providers.dart';
import '../../viewmodels/home_dialog_view_models.dart';
import '../forms/request_form.dart';

class CreateRequestDialog extends ConsumerStatefulWidget {
  const CreateRequestDialog({
    super.key,
    this.initialCollectionId,
  });

  final String? initialCollectionId;

  @override
  ConsumerState<CreateRequestDialog> createState() => _CreateRequestDialogState();
}

class _CreateRequestDialogState extends ConsumerState<CreateRequestDialog> {
  late final RequestFormController _formController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final activeEnv = ref.read(activeEnvironmentNameProvider);
    _formController = RequestFormController(
      initialCollectionId: widget.initialCollectionId,
      initialEnvironmentName: activeEnv,
    );
  }

  @override
  void dispose() {
    _formController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateRequest() async {
    final validationError = _formController.validateRequiredFields();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final viewModel = ref.read(createRequestViewModelProvider);
    setState(() => _isSubmitting = true);

    try {
      final request = _formController.buildRequest();
      await viewModel.createRequest(request);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request "${request.name}" created successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableWidth = mediaQuery.size.width - 32; // respect default dialog margin
    final contentMaxWidth = availableWidth > 600 ? 600.0 : availableWidth;
    final safeMaxWidth = contentMaxWidth > 0 ? contentMaxWidth : mediaQuery.size.width;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Create New Request'),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: safeMaxWidth),
        child: SingleChildScrollView(
          child: RequestForm(
            controller: _formController,
            isSubmitting: _isSubmitting,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: _isSubmitting ? 'Creating...' : 'Create',
          onPressed: _isSubmitting ? null : _handleCreateRequest,
        ),
      ],
    );
  }
}

