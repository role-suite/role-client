import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/features/home/presentation/providers/providers.dart';
import '../../../../../core/presentation/widgets/app_dropdown.dart';
import '../../../../../core/presentation/widgets/app_text_field.dart';
import '../../../../../core/utils/extension.dart';
import '../../controllers/request_form_controller.dart';

class RequestForm extends ConsumerWidget {
  const RequestForm({
    super.key,
    required this.controller,
    required this.isSubmitting,
  });

  final RequestFormController controller;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(collectionsNotifierProvider);
    final environmentsAsync = ref.watch(environmentsNotifierProvider);
    final isCompact = MediaQuery.of(context).size.width < 600;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
            final paramKeyControllers = controller.paramKeyControllers;
            final paramValueControllers = controller.paramValueControllers;

        Widget buildMethodAndUrlFields() {
              final methodDropdown = AppDropdown<HttpMethod>(
                label: 'Method',
                value: controller.selectedMethod,
                items: HttpMethod.values
                    .map(
                      (method) => DropdownMenuItem(
                        value: method,
                        child: Text(method.name),
                      ),
                    )
                    .toList(),
                enabled: !isSubmitting,
                isExpanded: true,
                onChanged: (value) {
                  if (value == null || isSubmitting) return;
                  controller.selectedMethod = value;
                },
              );

              final urlField = _EnvAwareTextField(
                controller: controller,
                targetController: controller.urlController,
                label: 'URL',
                hint: 'https://api.example.com/endpoint',
                keyboardType: TextInputType.url,
                isSubmitting: isSubmitting,
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    methodDropdown,
                    const SizedBox(height: 12),
                    urlField,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: methodDropdown),
                  const SizedBox(width: 12),
                  Expanded(flex: 5, child: urlField),
                ],
              );
            }

        Widget buildParamHeader() {
              final headerText = Text(
                'Query / Path Parameters (optional)',
                style: Theme.of(context).textTheme.titleSmall,
                softWrap: true,
              );
              final addButton = TextButton.icon(
                onPressed: isSubmitting ? null : controller.addParamRow,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Param'),
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerText,
                    const SizedBox(height: 8),
                    addButton,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: headerText),
                  const SizedBox(width: 8),
                  addButton,
                ],
              );
            }

        Widget buildParamRow(int index) {
              final keyField = AppTextField(
                controller: paramKeyControllers[index],
                label: 'Key',
                hint: 'userId',
                enabled: !isSubmitting,
              );
              final valueField = _EnvAwareTextField(
                controller: controller,
                targetController: paramValueControllers[index],
                label: 'Value',
                hint: '123',
                isSubmitting: isSubmitting,
              );
              final removeButton = IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove param',
                onPressed: isSubmitting ? null : () => controller.removeParamRow(index),
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    keyField,
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: valueField),
                        const SizedBox(width: 8),
                        removeButton,
                      ],
                    ),
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

        return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: controller.nameController,
                  label: 'Request Name',
                  hint: 'My API Request',
                  enabled: !isSubmitting,
                ),
                const SizedBox(height: 16),
                collectionsAsync.when(
                  data: (collections) {
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
                    return AppDropdown<String>(
                      label: 'Collection',
                      value: controller.selectedCollectionId ?? 'default',
                      items: allCollections
                          .map(
                            (collection) => DropdownMenuItem(
                              value: collection.id,
                              child: Text(collection.name.isNotEmpty ? collection.name : collection.id),
                            ),
                          )
                          .toList(),
                      enabled: !isSubmitting,
                      isExpanded: true,
                      onChanged: (value) {
                        if (isSubmitting) return;
                        controller.selectedCollectionId = value;
                      },
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                environmentsAsync.when(
                  data: (envs) => _EnvironmentSection(
                    controller: controller,
                    environments: envs,
                    isSubmitting: isSubmitting,
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                buildMethodAndUrlFields(),
                const SizedBox(height: 16),
                _EnvAwareTextField(
                  controller: controller,
                  targetController: controller.bodyController,
                  label: 'Body (optional)',
                  hint: '{ "key": "value" }',
                  maxLines: 4,
                  isSubmitting: isSubmitting,
                ),
                const SizedBox(height: 16),
                buildParamHeader(),
                const SizedBox(height: 8),
                ...List.generate(paramKeyControllers.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: buildParamRow(index),
                  );
                }),
              ],
        );
      },
    );
  }
}

class _EnvironmentSection extends StatelessWidget {
  const _EnvironmentSection({
    required this.controller,
    required this.environments,
    required this.isSubmitting,
  });

  final RequestFormController controller;
  final List<EnvironmentModel> environments;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    if (environments.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedEnvironment = controller.findEnvironmentByName(environments, controller.selectedEnvironmentName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDropdown<String?>(
          label: 'Environment (optional)',
          value: controller.selectedEnvironmentName,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('No environment'),
            ),
            ...environments.map(
              (env) => DropdownMenuItem<String?>(
                value: env.name,
                child: Text(env.name),
              ),
            ),
          ],
          enabled: !isSubmitting,
          onChanged: (value) {
            if (isSubmitting) return;
            controller.selectedEnvironmentName = value;
          },
          isExpanded: true,
        ),
        if (controller.selectedEnvironmentName != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              selectedEnvironment != null && selectedEnvironment.variables.isNotEmpty
                  ? 'Variables from "${controller.selectedEnvironmentName}" can be inserted as {{variableName}}.'
                  : 'No variables defined for "${controller.selectedEnvironmentName}".',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (selectedEnvironment != null && selectedEnvironment.variables.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedEnvironment.variables.entries
                  .map((entry) => Chip(label: Text('{{${entry.key}}}')))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _EnvAwareTextField extends ConsumerWidget {
  const _EnvAwareTextField({
    required this.controller,
    required this.targetController,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    required this.isSubmitting,
  });

  final RequestFormController controller;
  final TextEditingController targetController;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environmentsAsync = ref.watch(environmentsNotifierProvider);
    return environmentsAsync.when(
      data: (envs) => AppTextField(
        controller: targetController,
        label: label,
        hint: hint,
        maxLines: maxLines,
        keyboardType: keyboardType,
        enabled: !isSubmitting,
        suffixIcon: IconButton(
          icon: const Icon(Icons.data_object),
          tooltip: 'Insert environment variable',
          onPressed: isSubmitting ? null : () => controller.insertVariableIntoController(context, envs, targetController),
        ),
      ),
      loading: () => AppTextField(
        controller: targetController,
        label: label,
        hint: hint,
        maxLines: maxLines,
        keyboardType: keyboardType,
        enabled: !isSubmitting,
      ),
      error: (_, __) => AppTextField(
        controller: targetController,
        label: label,
        hint: hint,
        maxLines: maxLines,
        keyboardType: keyboardType,
        enabled: !isSubmitting,
      ),
    );
  }
}

