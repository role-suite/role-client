import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/environment_model.dart';

import '../../../../../core/presentation/widgets/app_button.dart';
import '../../controllers/environment_form_controller.dart';
import '../../viewmodels/home_dialog_view_models.dart';
import '../forms/environment_form.dart';

enum EnvironmentDialogMode { create, edit }

class CreateEnvironmentDialog extends EnvironmentFormDialog {
  const CreateEnvironmentDialog({super.key}) : super(mode: EnvironmentDialogMode.create);
}

class EditEnvironmentDialog extends EnvironmentFormDialog {
  const EditEnvironmentDialog({super.key, required EnvironmentModel environment}) : super(mode: EnvironmentDialogMode.edit, environment: environment);
}

class EnvironmentFormDialog extends ConsumerStatefulWidget {
  const EnvironmentFormDialog({super.key, required this.mode, this.environment});

  final EnvironmentDialogMode mode;
  final EnvironmentModel? environment;

  @override
  ConsumerState<EnvironmentFormDialog> createState() => _EnvironmentFormDialogState();
}

class _EnvironmentFormDialogState extends ConsumerState<EnvironmentFormDialog> {
  late final EnvironmentFormController _formController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _formController = EnvironmentFormController(initialEnvironment: widget.environment);
  }

  @override
  void dispose() {
    _formController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_formController.nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.mode == EnvironmentDialogMode.create ? 'Please enter an environment name' : 'Environment name cannot be empty'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final vars = _formController.buildVariables();
    final viewModel = ref.read(environmentDialogViewModelProvider);
    setState(() => _isSubmitting = true);

    try {
      late String successMessage;

      if (widget.mode == EnvironmentDialogMode.create) {
        final environment = EnvironmentModel(name: _formController.nameController.text.trim(), variables: vars);
        await viewModel.createEnvironment(environment);
        successMessage = 'Environment "${environment.name}" created successfully';
      } else {
        final updatedEnvironment = widget.environment!.copyWith(variables: vars);
        await viewModel.updateEnvironment(updatedEnvironment);
        successMessage = 'Environment "${updatedEnvironment.name}" updated successfully';
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save environment: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.mode == EnvironmentDialogMode.edit ? 'Edit Environment' : 'Create New Environment'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: EnvironmentForm(controller: _formController, isSubmitting: _isSubmitting),
        ),
      ),
      actions: [
        TextButton(onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        AppButton(
          label: _isSubmitting ? 'Saving...' : (widget.mode == EnvironmentDialogMode.edit ? 'Save' : 'Create'),
          onPressed: _isSubmitting ? null : _handleSubmit,
        ),
      ],
    );
  }
}
