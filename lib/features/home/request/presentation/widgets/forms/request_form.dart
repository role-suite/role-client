import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/models/request_enums.dart';
import 'package:relay/features/home/presentation/providers/providers.dart';
import 'package:relay/core/presentation/widgets/app_dropdown.dart';
import 'package:relay/core/presentation/widgets/app_text_field.dart';
import 'package:relay/core/utils/extension.dart';
import '../../controllers/request_form_controller.dart';
import '../key_value_editor.dart';

class RequestForm extends ConsumerWidget {
  const RequestForm({super.key, required this.controller, required this.isSubmitting});

  final RequestFormController controller;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(collectionsNotifierProvider);
    final environmentsAsync = ref.watch(environmentsNotifierProvider);
    final environments = environmentsAsync.asData?.value;
    final isCompact = MediaQuery.of(context).size.width < 600;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
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

          final urlField = EnvAwareTextField(
            controller: controller,
            environments: environments,
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

        Widget buildBodySection() {
          final bodyType = controller.selectedBodyType;
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
                EnvAwareTextField(
                  controller: controller,
                  environments: environments,
                  targetController: controller.bodyController,
                  label: 'Body (optional)',
                  hint: '{ "key": "value" }',
                  maxLines: 4,
                  isSubmitting: isSubmitting,
                ),
              ],
              if (showForm) ...[
                const SizedBox(height: 12),
                KeyValueRowsSection(
                  title: bodyType == BodyType.formData ? 'Form Data' : 'URL-encoded fields',
                  addLabel: 'Add field',
                  keyControllers: controller.formDataKeyControllers,
                  valueControllers: controller.formDataValueControllers,
                  keyHint: 'fieldName',
                  valueHint: 'value',
                  onAdd: controller.addFormDataRow,
                  onRemove: controller.removeFormDataRow,
                  controller: controller,
                  environments: environments,
                  isSubmitting: isSubmitting,
                ),
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
          final authType = controller.selectedAuthType;
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
              authFields = EnvAwareTextField(
                controller: controller,
                environments: environments,
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
                  EnvAwareTextField(
                    controller: controller,
                    environments: environments,
                    targetController: controller.authUsernameController,
                    label: 'Username',
                    hint: 'username',
                    isSubmitting: isSubmitting,
                  ),
                  const SizedBox(height: 12),
                  EnvAwareTextField(
                    controller: controller,
                    environments: environments,
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
                  AppTextField(controller: controller.authApiKeyHeaderController, label: 'Header name', hint: 'X-Api-Key', enabled: !isSubmitting),
                  const SizedBox(height: 12),
                  EnvAwareTextField(
                    controller: controller,
                    environments: environments,
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

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(controller: controller.nameController, label: 'Request Name', hint: 'My API Request', enabled: !isSubmitting),
            const SizedBox(height: 16),
            collectionsAsync.when(
              data: (collections) {
                final allCollections = [...collections];
                if (allCollections.isEmpty) {
                  return const SizedBox.shrink();
                }

                final currentSelection = controller.selectedCollectionId;
                final resolvedSelection = allCollections.any((c) => c.id == currentSelection) ? currentSelection : allCollections.first.id;
                if (resolvedSelection != currentSelection) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    controller.selectedCollectionId = resolvedSelection;
                  });
                }

                return AppDropdown<String>(
                  label: 'Collection',
                  value: resolvedSelection,
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
            KeyValueRowsSection(
              title: 'Headers (optional)',
              addLabel: 'Add Header',
              keyControllers: controller.headerKeyControllers,
              valueControllers: controller.headerValueControllers,
              keyHint: 'Content-Type',
              valueHint: 'application/json',
              onAdd: controller.addHeaderRow,
              onRemove: controller.removeHeaderRow,
              controller: controller,
              environments: environments,
              isSubmitting: isSubmitting,
            ),
            const SizedBox(height: 16),
            buildBodySection(),
            const SizedBox(height: 16),
            buildAuthSection(),
            const SizedBox(height: 16),
            KeyValueRowsSection(
              title: 'Query / Path Parameters (optional)',
              addLabel: 'Add Param',
              keyControllers: controller.paramKeyControllers,
              valueControllers: controller.paramValueControllers,
              keyHint: 'userId',
              valueHint: '123',
              onAdd: controller.addParamRow,
              onRemove: controller.removeParamRow,
              controller: controller,
              environments: environments,
              isSubmitting: isSubmitting,
            ),
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
