import 'package:flutter/material.dart';

import '../../../../../core/presentation/widgets/app_text_field.dart';
import '../../controllers/environment_form_controller.dart';

class EnvironmentForm extends StatelessWidget {
  const EnvironmentForm({super.key, required this.controller, required this.isSubmitting});

  final EnvironmentFormController controller;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final isEdit = controller.isEdit;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final keyControllers = controller.variableKeyControllers;
        final valueControllers = controller.variableValueControllers;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(controller: controller.nameController, label: 'Environment Name', hint: 'Production', autofocus: !isEdit, enabled: !isEdit),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Variables', style: Theme.of(context).textTheme.titleSmall),
                TextButton.icon(
                  onPressed: isSubmitting ? null : controller.addVariableRow,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Variable'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(keyControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: AppTextField(controller: keyControllers[index], label: 'Key', hint: 'API_URL', enabled: !isSubmitting),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppTextField(
                        controller: valueControllers[index],
                        label: 'Value',
                        hint: 'https://api.example.com',
                        enabled: !isSubmitting,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Remove variable',
                      onPressed: isSubmitting ? null : () => controller.removeVariableRow(index),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
