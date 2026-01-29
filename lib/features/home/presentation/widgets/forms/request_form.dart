import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/models/request_enums.dart';
import 'package:relay/features/home/presentation/providers/providers.dart';
import '../../../../../core/presentation/widgets/app_dropdown.dart';
import '../../../../../core/presentation/widgets/app_text_field.dart';
import '../../../../../core/utils/extension.dart';
import '../../controllers/request_form_controller.dart';

class RequestForm extends ConsumerWidget {
  const RequestForm({super.key, required this.controller, required this.isSubmitting});

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
        final headerKeyControllers = controller.headerKeyControllers;
        final headerValueControllers = controller.headerValueControllers;
        final paramKeyControllers = controller.paramKeyControllers;
        final paramValueControllers = controller.paramValueControllers;
        final formDataKeyControllers = controller.formDataKeyControllers;
        final formDataValueControllers = controller.formDataValueControllers;
        final bodyType = controller.selectedBodyType;
        final authType = controller.selectedAuthType;

        Widget buildMethodAndUrlFields() {
          final methodDropdown = AppDropdown<HttpMethod>(
            label: 'Method',
            value: controller.selectedMethod,
            items: HttpMethod.values.map((method) => DropdownMenuItem(value: method, child: Text(method.name))).toList(),
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
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [methodDropdown, const SizedBox(height: 12), urlField]);
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

        Widget buildSectionHeader(String title, VoidCallback? onAdd, {String addLabel = 'Add'}) {
          final headerText = Text(title, style: Theme.of(context).textTheme.titleSmall, softWrap: true);
          final addButton = onAdd == null
              ? null
              : TextButton.icon(
                  onPressed: isSubmitting ? null : onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(addLabel),
                );
          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [headerText, if (addButton != null) ...[const SizedBox(height: 8), addButton]],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: headerText),
              if (addButton != null) ...[const SizedBox(width: 8), addButton],
            ],
          );
        }

        Widget buildKeyValueRow({
          required List<TextEditingController> keyControllers,
          required List<TextEditingController> valueControllers,
          required int index,
          required VoidCallback onRemove,
          required String keyHint,
          required String valueHint,
          bool valueEnvAware = true,
        }) {
          final keyField = AppTextField(
            controller: keyControllers[index],
            label: 'Key',
            hint: keyHint,
            enabled: !isSubmitting,
          );
          final valueField = valueEnvAware
              ? _EnvAwareTextField(
                  controller: controller,
                  targetController: valueControllers[index],
                  label: 'Value',
                  hint: valueHint,
                  isSubmitting: isSubmitting,
                )
              : AppTextField(
                  controller: valueControllers[index],
                  label: 'Value',
                  hint: valueHint,
                  enabled: !isSubmitting,
                );
          final removeButton = IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove',
            onPressed: isSubmitting ? null : onRemove,
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

        Widget buildHeadersSection() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildSectionHeader('Headers (optional)', controller.addHeaderRow, addLabel: 'Add Header'),
              const SizedBox(height: 8),
              ...List.generate(headerKeyControllers.length, (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: buildKeyValueRow(
                  keyControllers: headerKeyControllers,
                  valueControllers: headerValueControllers,
                  index: i,
                  onRemove: () => controller.removeHeaderRow(i),
                  keyHint: 'Content-Type',
                  valueHint: 'application/json',
                  valueEnvAware: true,
                ),
              )),
            ],
          );
        }

        Widget buildBodySection() {
          final bodyTypeDropdown = AppDropdown<BodyType>(
            label: 'Body type',
            value: bodyType,
            items: BodyType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.displayName))).toList(),
            enabled: !isSubmitting,
            isExpanded: true,
            onChanged: (v) {
              if (v == null || isSubmitting) return;
              controller.selectedBodyType = v;
            },
          );
          final showRaw = bodyType == BodyType.raw;
          final showForm = bodyType == BodyType.formData || bodyType == BodyType.urlEncoded;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              bodyTypeDropdown,
              if (showRaw) ...[
                const SizedBox(height: 12),
                _EnvAwareTextField(
                  controller: controller,
                  targetController: controller.bodyController,
                  label: 'Body (optional)',
                  hint: '{ "key": "value" }',
                  maxLines: 4,
                  isSubmitting: isSubmitting,
                ),
              ],
              if (showForm) ...[
                const SizedBox(height: 12),
                buildSectionHeader(
                  bodyType == BodyType.formData ? 'Form Data' : 'URL-encoded fields',
                  controller.addFormDataRow,
                  addLabel: 'Add field',
                ),
                const SizedBox(height: 8),
                ...List.generate(formDataKeyControllers.length, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: buildKeyValueRow(
                    keyControllers: formDataKeyControllers,
                    valueControllers: formDataValueControllers,
                    index: i,
                    onRemove: () => controller.removeFormDataRow(i),
                    keyHint: 'fieldName',
                    valueHint: 'value',
                    valueEnvAware: true,
                  ),
                )),
              ],
              if (bodyType == BodyType.binary) ...[
                const SizedBox(height: 12),
                Text(
                  'Binary body: use a file path or leave empty. File picker support can be added later.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          );
        }

        Widget buildAuthSection() {
          final authDropdown = AppDropdown<AuthType>(
            label: 'Auth',
            value: authType,
            items: AuthType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.displayName))).toList(),
            enabled: !isSubmitting,
            isExpanded: true,
            onChanged: (v) {
              if (v == null || isSubmitting) return;
              controller.selectedAuthType = v;
            },
          );
          Widget? authFields;
          switch (authType) {
            case AuthType.bearer:
              authFields = _EnvAwareTextField(
                controller: controller,
                targetController: controller.authTokenController,
                label: 'Bearer Token',
                hint: 'Your token or {{variable}}',
                isSubmitting: isSubmitting,
              );
              break;
            case AuthType.basic:
              authFields = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _EnvAwareTextField(
                    controller: controller,
                    targetController: controller.authUsernameController,
                    label: 'Username',
                    hint: 'username',
                    isSubmitting: isSubmitting,
                  ),
                  const SizedBox(height: 12),
                  _EnvAwareTextField(
                    controller: controller,
                    targetController: controller.authPasswordController,
                    label: 'Password',
                    hint: 'password',
                    isSubmitting: isSubmitting,
                  ),
                ],
              );
              break;
            case AuthType.apiKey:
              authFields = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: controller.authApiKeyHeaderController,
                    label: 'Header name',
                    hint: 'X-Api-Key',
                    enabled: !isSubmitting,
                  ),
                  const SizedBox(height: 12),
                  _EnvAwareTextField(
                    controller: controller,
                    targetController: controller.authApiKeyValueController,
                    label: 'Value',
                    hint: 'key or {{variable}}',
                    isSubmitting: isSubmitting,
                  ),
                ],
              );
              break;
            case AuthType.none:
              break;
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              authDropdown,
              if (authFields != null) ...[const SizedBox(height: 12), authFields],
            ],
          );
        }

        Widget buildParamHeader() {
          return buildSectionHeader('Query / Path Parameters (optional)', controller.addParamRow, addLabel: 'Add Param');
        }

        Widget buildParamRow(int index) {
          return buildKeyValueRow(
            keyControllers: paramKeyControllers,
            valueControllers: paramValueControllers,
            index: index,
            onRemove: () => controller.removeParamRow(index),
            keyHint: 'userId',
            valueHint: '123',
            valueEnvAware: true,
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(controller: controller.nameController, label: 'Request Name', hint: 'My API Request', enabled: !isSubmitting),
            const SizedBox(height: 16),
            collectionsAsync.when(
              data: (collections) {
                final allCollections = [
                  if (!collections.any((c) => c.id == 'default'))
                    CollectionModel(id: 'default', name: 'Default', createdAt: DateTime.now(), updatedAt: DateTime.now()),
                  ...collections,
                ];
                return AppDropdown<String>(
                  label: 'Collection',
                  value: controller.selectedCollectionId ?? 'default',
                  items: allCollections
                      .map(
                        (collection) =>
                            DropdownMenuItem(value: collection.id, child: Text(collection.name.isNotEmpty ? collection.name : collection.id)),
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
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            environmentsAsync.when(
              data: (envs) => _EnvironmentSection(controller: controller, environments: envs, isSubmitting: isSubmitting),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            buildMethodAndUrlFields(),
            const SizedBox(height: 16),
            buildHeadersSection(),
            const SizedBox(height: 16),
            buildBodySection(),
            const SizedBox(height: 16),
            buildAuthSection(),
            const SizedBox(height: 16),
            buildParamHeader(),
            const SizedBox(height: 8),
            ...List.generate(paramKeyControllers.length, (index) => Padding(padding: const EdgeInsets.only(bottom: 8), child: buildParamRow(index))),
          ],
        );
      },
    );
  }
}

class _EnvironmentSection extends StatelessWidget {
  const _EnvironmentSection({required this.controller, required this.environments, required this.isSubmitting});

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
            const DropdownMenuItem<String?>(value: null, child: Text('No environment')),
            ...environments.map((env) => DropdownMenuItem<String?>(value: env.name, child: Text(env.name))),
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
                  .map(
                    (entry) => Chip(
                      label: Text(
                        '{{${entry.key}}}',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    ),
                  )
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
      error: (_, _) => AppTextField(
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
