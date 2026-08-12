import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/models/request_enums.dart';
import 'package:relay/core/presentation/widgets/app_button.dart';
import 'package:relay/core/presentation/widgets/app_dropdown.dart';
import 'package:relay/core/presentation/widgets/app_text_field.dart';
import 'package:relay/core/presentation/widgets/method_badge.dart';
import 'package:relay/core/utils/extension.dart';
import 'package:relay/features/home/presentation/providers/providers.dart';
import '../controllers/request_form_controller.dart';
import 'key_value_editor.dart';

/// A standard REST-client style request editor: a name/method/URL bar
/// followed by Params/Headers/Body/Auth tabs, driven by a single
/// [RequestFormController]. Used both for viewing/running an existing
/// request and for editing it in place — fields are always editable.
class RequestEditor extends ConsumerStatefulWidget {
  const RequestEditor({
    super.key,
    required this.controller,
    required this.isSending,
    required this.isSaving,
    required this.onSend,
    required this.onSave,
    this.onDelete,
  });

  final RequestFormController controller;
  final bool isSending;
  final bool isSaving;
  final VoidCallback onSend;
  final VoidCallback onSave;
  final VoidCallback? onDelete;

  @override
  ConsumerState<RequestEditor> createState() => _RequestEditorState();
}

class _RequestEditorState extends ConsumerState<RequestEditor> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  void _handleTabChanged() {
    if (!mounted) return;
    if (_tabController.indexIsChanging) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final collectionsAsync = ref.watch(collectionsNotifierProvider);
    final environmentsAsync = ref.watch(environmentsNotifierProvider);
    final environments = environmentsAsync.asData?.value;
    final isBusy = widget.isSending || widget.isSaving;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(controller: widget.controller.nameController, label: 'Request Name', hint: 'My API Request', enabled: !isBusy),
                ),
                if (widget.onDelete != null) ...[
                  const SizedBox(width: 8),
                  IconButton(tooltip: 'Delete request', icon: const Icon(Icons.delete_outline), onPressed: widget.onDelete),
                ],
              ],
            ),
            const SizedBox(height: 10),
            _buildMethodAndUrlBar(context, environments),
            const SizedBox(height: 10),
            collectionsAsync.when(
              data: (collections) => _buildCollectionAndEnvironmentRow(context, collections, environmentsAsync.asData?.value ?? const []),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: MediaQuery.of(context).size.width < 600,
                    dividerColor: Colors.transparent,
                    labelColor: theme.colorScheme.primary,
                    indicator: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.75)),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                    tabs: const [
                      Tab(text: 'Params'),
                      Tab(text: 'Headers'),
                      Tab(text: 'Body'),
                      Tab(text: 'Auth'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildTabContent(context, environments, isBusy),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppButton(label: widget.isSending ? 'Sending...' : 'Send', icon: Icons.play_arrow, onPressed: isBusy ? null : widget.onSend),
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: widget.isSaving ? 'Saving...' : 'Save',
                  icon: Icons.save_outlined,
                  variant: AppButtonVariant.outlined,
                  onPressed: isBusy ? null : widget.onSave,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMethodAndUrlBar(BuildContext context, List<EnvironmentModel>? environments) {
    final isBusy = widget.isSending || widget.isSaving;
    final isCompact = MediaQuery.of(context).size.width < 840;
    final methodColor = MethodBadge.colorFor(widget.controller.selectedMethod);

    final methodField = SizedBox(
      width: isCompact ? double.infinity : 130,
      child: DropdownButtonFormField<HttpMethod>(
        initialValue: widget.controller.selectedMethod,
        isExpanded: true,
        decoration: InputDecoration(
          filled: true,
          fillColor: methodColor.withValues(alpha: 0.12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: methodColor.withValues(alpha: 0.4))),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: methodColor.withValues(alpha: 0.4)),
          ),
        ),
        items: HttpMethod.values
            .map(
              (method) => DropdownMenuItem(
                value: method,
                child: Text(method.name.toUpperCase(), style: TextStyle(color: MethodBadge.colorFor(method), fontWeight: FontWeight.w700)),
              ),
            )
            .toList(),
        onChanged: isBusy ? null : (value) => setState(() => widget.controller.selectedMethod = value ?? widget.controller.selectedMethod),
      ),
    );

    final urlField = EnvAwareTextField(
      controller: widget.controller,
      environments: environments,
      targetController: widget.controller.urlController,
      label: 'URL',
      hint: 'https://api.example.com/endpoint',
      keyboardType: TextInputType.url,
      isSubmitting: isBusy,
    );

    if (isCompact) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [methodField, const SizedBox(height: 8), urlField]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [methodField, const SizedBox(width: 10), Expanded(child: urlField)],
    );
  }

  Widget _buildCollectionAndEnvironmentRow(BuildContext context, List<CollectionModel> collections, List<EnvironmentModel> environments) {
    final isBusy = widget.isSending || widget.isSaving;
    final resolvedCollection = collections.any((c) => c.id == widget.controller.selectedCollectionId)
        ? widget.controller.selectedCollectionId
        : (collections.isNotEmpty ? collections.first.id : null);
    if (resolvedCollection != widget.controller.selectedCollectionId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.selectedCollectionId = resolvedCollection;
      });
    }

    final collectionField = collections.isEmpty
        ? const SizedBox.shrink()
        : AppDropdown<String>(
            label: 'Collection',
            value: resolvedCollection,
            items: collections
                .map((collection) => DropdownMenuItem(value: collection.id, child: Text(collection.name.isNotEmpty ? collection.name : collection.id)))
                .toList(),
            enabled: !isBusy,
            isExpanded: true,
            onChanged: (value) => setState(() => widget.controller.selectedCollectionId = value),
          );

    final environmentField = AppDropdown<String?>(
      label: 'Environment',
      value: widget.controller.selectedEnvironmentName,
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('No Environment')),
        ...environments.map((env) => DropdownMenuItem<String?>(value: env.name, child: Text(env.name))),
      ],
      enabled: !isBusy,
      isExpanded: true,
      onChanged: (value) => setState(() => widget.controller.selectedEnvironmentName = value),
    );

    final isCompact = MediaQuery.of(context).size.width < 600;
    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [collectionField, const SizedBox(height: 8), environmentField],
      );
    }
    return Row(
      children: [
        Expanded(child: collectionField),
        const SizedBox(width: 8),
        Expanded(child: environmentField),
      ],
    );
  }

  Widget _buildTabContent(BuildContext context, List<EnvironmentModel>? environments, bool isBusy) {
    final controller = widget.controller;
    return IndexedStack(
      index: _tabController.index,
      children: [
        KeyValueRowsSection(
          title: 'Query / Path Parameters',
          addLabel: 'Add Param',
          keyControllers: controller.paramKeyControllers,
          valueControllers: controller.paramValueControllers,
          keyHint: 'userId',
          valueHint: '123',
          onAdd: controller.addParamRow,
          onRemove: controller.removeParamRow,
          controller: controller,
          environments: environments,
          isSubmitting: isBusy,
        ),
        KeyValueRowsSection(
          title: 'Headers',
          addLabel: 'Add Header',
          keyControllers: controller.headerKeyControllers,
          valueControllers: controller.headerValueControllers,
          keyHint: 'Content-Type',
          valueHint: 'application/json',
          onAdd: controller.addHeaderRow,
          onRemove: controller.removeHeaderRow,
          controller: controller,
          environments: environments,
          isSubmitting: isBusy,
        ),
        _buildBodyTab(context, environments, isBusy),
        _buildAuthTab(context, environments, isBusy),
      ],
    );
  }

  Widget _buildBodyTab(BuildContext context, List<EnvironmentModel>? environments, bool isBusy) {
    final controller = widget.controller;
    final bodyType = controller.selectedBodyType;
    final bodyTypeDropdown = AppDropdown<BodyType>(
      label: 'Body type',
      value: bodyType,
      items: BodyType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.displayName))).toList(),
      enabled: !isBusy,
      isExpanded: true,
      onChanged: (v) => setState(() => controller.selectedBodyType = v ?? bodyType),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        bodyTypeDropdown,
        if (bodyType == BodyType.raw) ...[
          const SizedBox(height: 12),
          EnvAwareTextField(
            controller: controller,
            environments: environments,
            targetController: controller.bodyController,
            label: 'Body (optional)',
            hint: '{ "key": "value" }',
            maxLines: 8,
            isSubmitting: isBusy,
          ),
        ],
        if (bodyType == BodyType.formData || bodyType == BodyType.urlEncoded) ...[
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
            isSubmitting: isBusy,
          ),
        ],
        if (bodyType == BodyType.binary) ...[
          const SizedBox(height: 12),
          Text(
            'Binary body: use a file path or leave empty. File picker support can be added later.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
        if (bodyType == BodyType.none) ...[
          const SizedBox(height: 12),
          Text('No request body will be sent.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ],
    );
  }

  Widget _buildAuthTab(BuildContext context, List<EnvironmentModel>? environments, bool isBusy) {
    final controller = widget.controller;
    final authType = controller.selectedAuthType;
    final authDropdown = AppDropdown<AuthType>(
      label: 'Auth',
      value: authType,
      items: AuthType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.displayName))).toList(),
      enabled: !isBusy,
      isExpanded: true,
      onChanged: (v) => setState(() => controller.selectedAuthType = v ?? authType),
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
          isSubmitting: isBusy,
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
              isSubmitting: isBusy,
            ),
            const SizedBox(height: 12),
            EnvAwareTextField(
              controller: controller,
              environments: environments,
              targetController: controller.authPasswordController,
              label: 'Password',
              hint: 'password',
              isSubmitting: isBusy,
            ),
          ],
        );
        break;
      case AuthType.apiKey:
        authFields = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(controller: controller.authApiKeyHeaderController, label: 'Header name', hint: 'X-Api-Key', enabled: !isBusy),
            const SizedBox(height: 12),
            EnvAwareTextField(
              controller: controller,
              environments: environments,
              targetController: controller.authApiKeyValueController,
              label: 'Value',
              hint: 'key or {{variable}}',
              isSubmitting: isBusy,
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
}
