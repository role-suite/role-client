import 'package:flutter/material.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/presentation/widgets/app_text_field.dart';
import '../controllers/request_form_controller.dart';

/// A text field that offers an "insert environment variable" affordance,
/// wired to [RequestFormController.insertVariableIntoController].
class EnvAwareTextField extends StatelessWidget {
  const EnvAwareTextField({
    super.key,
    required this.controller,
    required this.environments,
    required this.targetController,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.isSubmitting = false,
  });

  final RequestFormController controller;
  final List<EnvironmentModel>? environments;
  final TextEditingController targetController;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: targetController,
      label: label,
      hint: hint,
      maxLines: maxLines,
      keyboardType: keyboardType,
      enabled: !isSubmitting,
      suffixIcon: environments == null
          ? null
          : IconButton(
              icon: const Icon(Icons.data_object),
              tooltip: 'Insert environment variable',
              onPressed: isSubmitting ? null : () => controller.insertVariableIntoController(context, environments!, targetController),
            ),
    );
  }
}

/// A titled section of key/value rows (used for headers, query/path params,
/// and form-data fields), each row optionally environment-variable-aware.
class KeyValueRowsSection extends StatelessWidget {
  const KeyValueRowsSection({
    super.key,
    required this.title,
    required this.addLabel,
    required this.keyControllers,
    required this.valueControllers,
    required this.keyHint,
    required this.valueHint,
    required this.onAdd,
    required this.onRemove,
    this.controller,
    this.environments,
    this.valueEnvAware = true,
    this.isSubmitting = false,
  });

  final String title;
  final String addLabel;
  final List<TextEditingController> keyControllers;
  final List<TextEditingController> valueControllers;
  final String keyHint;
  final String valueHint;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final RequestFormController? controller;
  final List<EnvironmentModel>? environments;
  final bool valueEnvAware;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    final theme = Theme.of(context);

    final headerText = Text(title, style: theme.textTheme.titleSmall, softWrap: true);
    final addButton = TextButton.icon(
      onPressed: isSubmitting ? null : onAdd,
      icon: const Icon(Icons.add, size: 18),
      label: Text(addLabel),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isCompact)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [headerText, const SizedBox(height: 8), addButton],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: headerText),
              const SizedBox(width: 8),
              addButton,
            ],
          ),
        const SizedBox(height: 8),
        ...List.generate(
          keyControllers.length,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildRow(context, i, isCompact),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, int index, bool isCompact) {
    final keyField = AppTextField(controller: keyControllers[index], label: 'Key', hint: keyHint, enabled: !isSubmitting);
    final valueField = valueEnvAware && controller != null
        ? EnvAwareTextField(
            controller: controller!,
            environments: environments,
            targetController: valueControllers[index],
            label: 'Value',
            hint: valueHint,
            isSubmitting: isSubmitting,
          )
        : AppTextField(controller: valueControllers[index], label: 'Value', hint: valueHint, enabled: !isSubmitting);
    final removeButton = IconButton(
      icon: const Icon(Icons.delete_outline),
      tooltip: 'Remove',
      onPressed: isSubmitting ? null : () => onRemove(index),
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          keyField,
          const SizedBox(height: 8),
          Row(children: [Expanded(child: valueField), const SizedBox(width: 8), removeButton]),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: keyField),
        const SizedBox(width: 8),
        Expanded(child: valueField),
        const SizedBox(width: 8),
        removeButton,
      ],
    );
  }
}
