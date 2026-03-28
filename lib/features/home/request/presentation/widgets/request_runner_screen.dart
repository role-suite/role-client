import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:relay/core/constants/data_source_mode.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/models/request_enums.dart';
import 'package:relay/core/services/api_service.dart';
import 'package:relay/core/utils/json.dart';
import 'package:relay/core/utils/extension.dart';
import 'package:relay/core/utils/request_build_helper.dart';
import 'package:relay/features/home/presentation/providers/repository_providers.dart';
import 'package:relay/features/home/collection/presentation/providers/collection_providers.dart';
import 'package:relay/features/home/presentation/providers/data_source_providers.dart';
import 'package:relay/features/home/request/presentation/providers/request_providers.dart';
import 'package:relay/features/home/environment/presentation/providers/environment_providers.dart';

import 'package:relay/core/presentation/widgets/app_button.dart';
import 'package:relay/core/presentation/widgets/app_dropdown.dart';
import 'package:relay/core/presentation/widgets/app_text_field.dart';
import 'package:relay/core/presentation/widgets/method_badge.dart';
import 'package:relay/core/presentation/widgets/variable_highlight_text.dart';

const String _noEnvironmentMenuValue = '__menu_no_environment__';

enum _ResponseBodyViewMode { pretty, raw, preview }

class RequestRunnerPage extends ConsumerStatefulWidget {
  const RequestRunnerPage({super.key, required this.request, this.onDelete, this.startInEditMode = false});

  final ApiRequestModel request;
  final VoidCallback? onDelete;
  final bool startInEditMode;

  @override
  ConsumerState<RequestRunnerPage> createState() => _RequestRunnerPageState();
}

class _RequestRunnerPageState extends ConsumerState<RequestRunnerPage> with SingleTickerProviderStateMixin {
  bool _isSending = false;
  Response<dynamic>? _response;
  DioException? _error;
  Duration? _duration;
  bool _isPermissionError = false;
  _ResponseBodyViewMode _responseBodyViewMode = _ResponseBodyViewMode.pretty;
  late ApiRequestModel _currentRequest;
  bool _isEditing = false;
  bool _isSavingEdits = false;

  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late TextEditingController _bodyController;
  late TextEditingController _requestBodyController;
  final List<TextEditingController> _headerKeyControllers = [];
  final List<TextEditingController> _headerValueControllers = [];
  final List<TextEditingController> _paramKeyControllers = [];
  final List<TextEditingController> _paramValueControllers = [];
  final List<TextEditingController> _formDataKeyControllers = [];
  final List<TextEditingController> _formDataValueControllers = [];
  late HttpMethod _selectedMethod;
  late BodyType _selectedBodyType;
  String? _selectedCollectionId;
  String? _selectedEnvironmentName;
  late final TabController _tabController;
  late final ScrollController _scrollController;
  final GlobalKey _responseSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _currentRequest = widget.request;
    _selectedMethod = _currentRequest.method;
    _selectedBodyType = _currentRequest.bodyType;
    _selectedCollectionId = _currentRequest.collectionId;
    _selectedEnvironmentName = _currentRequest.environmentName;
    _nameController = TextEditingController(text: _currentRequest.name);
    _urlController = TextEditingController(text: _currentRequest.urlTemplate);
    _bodyController = TextEditingController(text: _currentRequest.body ?? '');
    _requestBodyController = TextEditingController(text: _currentRequest.body ?? '');
    _rebuildHeaderControllersFrom(_currentRequest);
    _rebuildParamControllersFrom(_currentRequest);
    _rebuildFormDataControllersFrom(_currentRequest);
    _isEditing = widget.startInEditMode;
    _tabController = TabController(length: 4, vsync: this);
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(covariant RequestRunnerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id || oldWidget.startInEditMode != widget.startInEditMode) {
      setState(() {
        _currentRequest = widget.request;
        _isEditing = widget.startInEditMode;
        _syncEditorsFromCurrentRequest();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _bodyController.dispose();
    _requestBodyController.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    _disposeHeaderControllers();
    _disposeParamControllers();
    _disposeFormDataControllers();
    super.dispose();
  }

  Future<void> _sendRequest() async {
    _focusResponseBodySection();
    setState(() {
      _isSending = true;
      _error = null;
      _response = null;
      _duration = null;
      _isPermissionError = false;
    });

    final envRepository = ref.read(environmentRepositoryProvider);
    final runtimeHeaders = _buildHeadersFromControllers();
    final runtimeFormData = _buildFormDataFieldsFromControllers();
    final rawBodyText = _requestBodyController.text.trim();
    final runtimeUrl = _urlController.text.trim();
    final request = _currentRequest.copyWith(
      method: _selectedMethod,
      urlTemplate: runtimeUrl.isEmpty ? _currentRequest.urlTemplate : runtimeUrl,
      headers: runtimeHeaders,
      formDataFields: runtimeFormData,
      body: rawBodyText.isEmpty ? null : rawBodyText,
      bodyType: _selectedBodyType,
      environmentName: _selectedEnvironmentName,
    );

    // Use request's saved environment if it exists, otherwise use active environment
    EnvironmentModel? environment;
    if (request.environmentName != null) {
      environment = await envRepository.getEnvironmentByName(request.environmentName!);
    }
    environment ??= await envRepository.getActiveEnvironment();

    // Resolve templates using the selected environment
    String resolve(String s) => envRepository.resolveTemplate(s, environment);
    final resolvedUrl = resolve(request.urlTemplate);
    final resolvedQueryParams = <String, String>{for (final entry in request.queryParams.entries) entry.key: resolve(entry.value)};
    final built = RequestBuildHelper.buildForSend(request, resolve, rawBody: _requestBodyController.text);

    debugPrint('==== Relay Request ====');
    debugPrint('Name: ${request.name}');
    debugPrint('Method: ${request.method.name}');
    debugPrint('Request environment: ${request.environmentName}');
    debugPrint('Using environment: ${environment?.name}');
    debugPrint('Resolved URL: $resolvedUrl');
    debugPrint('Resolved headers: ${built.headers}');
    debugPrint('Resolved query params: $resolvedQueryParams');

    final dio = ApiService.instance.dio;

    final stopwatch = Stopwatch()..start();
    try {
      final response = await dio.request<dynamic>(
        resolvedUrl,
        options: Options(method: request.method.name, headers: built.headers.isEmpty ? null : built.headers),
        queryParameters: resolvedQueryParams.isEmpty ? null : resolvedQueryParams,
        data: built.body,
      );
      stopwatch.stop();
      setState(() {
        _response = response;
        _duration = stopwatch.elapsed;
        _responseBodyViewMode = _looksLikeHtmlResponse(response) ? _ResponseBodyViewMode.preview : _ResponseBodyViewMode.pretty;
      });
    } on DioException catch (e) {
      stopwatch.stop();
      debugPrint('DioException while sending request:');
      debugPrint('  type: ${e.type}');
      debugPrint('  message: ${e.message}');
      debugPrint('  error: ${e.error}');
      debugPrint('  status code: ${e.response?.statusCode}');
      debugPrint('  status message: ${e.response?.statusMessage}');

      // Detect macOS-style permission errors (Operation not permitted / errno = 1)
      bool permissionError = false;
      final underlying = e.error;
      if (underlying is SocketException) {
        final osError = underlying.osError;
        final code = osError?.errorCode;
        final message = osError?.message.toLowerCase() ?? '';
        if (code == 1 || message.contains('operation not permitted')) {
          permissionError = true;
        }
      }

      setState(() {
        _error = e;
        _response = e.response;
        _duration = stopwatch.elapsed;
        _isPermissionError = permissionError;
      });
    } catch (e) {
      stopwatch.stop();
      debugPrint('Unexpected error while sending request: $e');
      setState(() {
        _error = DioException(
          requestOptions: RequestOptions(path: resolvedUrl),
          error: e,
        );
        _duration = stopwatch.elapsed;
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = _currentRequest;
    final theme = Theme.of(context);
    final environmentsAsync = ref.watch(environmentsNotifierProvider);
    final envList = environmentsAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            MethodBadge(method: _selectedMethod),
            const SizedBox(width: 12),
            Expanded(child: Text(request.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: const [],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRequestComposerBar(context, environmentsAsync, envList),
                  if (request.description != null && request.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(request.description!, style: theme.textTheme.bodySmall),
                    ),
                  ],
                  if (_isEditing) ...[
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(controller: _scrollController, child: _buildEditForm(context, environmentsAsync)),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Expanded(
                      child: Container(
                        key: _responseSectionKey,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8)),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: TabBar(
                                controller: _tabController,
                                isScrollable: true,
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
                                  Tab(text: 'Request Body'),
                                  Tab(text: 'Request Headers'),
                                  Tab(text: 'Response Body'),
                                  Tab(text: 'Response Headers'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildRequestBodyTab(context, envList),
                                  _buildRequestHeadersTab(context),
                                  _buildResponseBodyTab(context),
                                  _buildResponseHeadersTab(context),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (_response != null || _error != null) _buildMetaInfo(context),
                        const Spacer(),
                        if (_isSending) const SizedBox(width: 160, child: LinearProgressIndicator()),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestComposerBar(BuildContext context, AsyncValue<List<EnvironmentModel>> environmentsAsync, List<EnvironmentModel>? envList) {
    final theme = Theme.of(context);
    final isCompact = MediaQuery.of(context).size.width < 840;

    final methodSelector = SizedBox(
      width: isCompact ? double.infinity : 130,
      child: AppDropdown<HttpMethod>(
        label: 'Method',
        value: _selectedMethod,
        isExpanded: true,
        items: HttpMethod.values.map((method) => DropdownMenuItem(value: method, child: Text(method.name.toUpperCase()))).toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() => _selectedMethod = value);
        },
      ),
    );

    final urlField = AppTextField(
      controller: _urlController,
      label: 'Request URL',
      hint: 'https://api.example.com/endpoint',
      keyboardType: TextInputType.url,
      suffixIcon: _buildEnvVariableInsertButton(context, envList, _urlController, isDisabled: _isSending),
    );

    final actionRow = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        AppButton(label: _isSending ? 'Sending...' : 'Send', icon: Icons.play_arrow, onPressed: _isSending ? null : _sendRequest),
        if (!_isEditing)
          AppButton(
            label: _isSavingEdits ? 'Saving...' : 'Save Changes',
            icon: Icons.save_outlined,
            onPressed: (_isSending || _isSavingEdits) ? null : () => _saveEdits(context),
          ),
        IconButton(
          tooltip: _isEditing ? 'Close editor' : 'Edit request',
          icon: Icon(_isEditing ? Icons.edit_off : Icons.edit),
          onPressed: _toggleEditingMode,
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCompact) ...[
            methodSelector,
            const SizedBox(height: 8),
            urlField,
            const SizedBox(height: 8),
            Row(children: [Expanded(child: actionRow)]),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                methodSelector,
                const SizedBox(width: 10),
                Expanded(child: urlField),
                const SizedBox(width: 10),
                actionRow,
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _buildEnvironmentAction(context, environmentsAsync, _selectedEnvironmentName),
              const SizedBox(width: 8),
              Chip(
                label: Text('Body: ${_selectedBodyType.displayName}'),
                backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              if (widget.onDelete != null) IconButton(tooltip: 'Delete request', icon: const Icon(Icons.delete_outline), onPressed: widget.onDelete),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm(BuildContext context, AsyncValue<List<EnvironmentModel>> environmentsAsync) {
    final theme = Theme.of(context);
    final collectionsAsync = ref.watch(collectionsNotifierProvider);
    final dataSourceState = ref.watch(currentDataSourceStateProvider);
    final isApiMode = dataSourceState?.mode == DataSourceMode.api;
    final envList = environmentsAsync.asData?.value;
    final isCompact = MediaQuery.of(context).size.width < 600;

    Widget buildBodyFields() {
      switch (_selectedBodyType) {
        case BodyType.none:
          return Text('No request body will be sent.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant));
        case BodyType.raw:
          return AppTextField(
            controller: _bodyController,
            label: 'Body (optional)',
            hint: '{ "key": "value" }',
            maxLines: 4,
            suffixIcon: _buildEnvVariableInsertButton(context, envList, _bodyController, isDisabled: _isSavingEdits),
          );
        case BodyType.formData:
        case BodyType.urlEncoded:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isCompact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedBodyType == BodyType.formData ? 'Form Data Fields' : 'URL-encoded Fields', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _isSavingEdits ? null : _handleAddFormDataRow,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Field'),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_selectedBodyType == BodyType.formData ? 'Form Data Fields' : 'URL-encoded Fields', style: theme.textTheme.titleSmall),
                    TextButton.icon(
                      onPressed: _isSavingEdits ? null : _handleAddFormDataRow,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Field'),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              ...List.generate(_formDataKeyControllers.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: isCompact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppTextField(controller: _formDataKeyControllers[index], label: 'Key', hint: 'fieldName'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    controller: _formDataValueControllers[index],
                                    label: 'Value',
                                    hint: 'value',
                                    suffixIcon: _buildEnvVariableInsertButton(
                                      context,
                                      envList,
                                      _formDataValueControllers[index],
                                      isDisabled: _isSavingEdits,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Remove field',
                                  onPressed: _isSavingEdits ? null : () => _handleRemoveFormDataRow(index),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AppTextField(controller: _formDataKeyControllers[index], label: 'Key', hint: 'fieldName'),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AppTextField(
                                controller: _formDataValueControllers[index],
                                label: 'Value',
                                hint: 'value',
                                suffixIcon: _buildEnvVariableInsertButton(
                                  context,
                                  envList,
                                  _formDataValueControllers[index],
                                  isDisabled: _isSavingEdits,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Remove field',
                              onPressed: _isSavingEdits ? null : () => _handleRemoveFormDataRow(index),
                            ),
                          ],
                        ),
                );
              }),
            ],
          );
        case BodyType.binary:
          return Text(
            'Binary body is not fully supported yet. File picker can be added later.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          );
      }
    }

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Request', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            AppTextField(controller: _nameController, label: 'Request Name', hint: 'My API Request'),
            const SizedBox(height: 16),
            collectionsAsync.when(
              data: (collections) {
                final allCollections = [...collections];
                if (!isApiMode && !allCollections.any((c) => c.id == 'default')) {
                  allCollections.insert(0, CollectionModel(id: 'default', name: 'Default', createdAt: DateTime.now(), updatedAt: DateTime.now()));
                }

                if (allCollections.isEmpty) {
                  return const SizedBox.shrink();
                }

                final resolvedSelection = allCollections.any((c) => c.id == _selectedCollectionId) ? _selectedCollectionId : allCollections.first.id;
                if (resolvedSelection != _selectedCollectionId) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() {
                      _selectedCollectionId = resolvedSelection;
                    });
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
                  onChanged: (value) {
                    setState(() {
                      _selectedCollectionId = value;
                    });
                  },
                );
              },
              loading: () => const SizedBox(height: 48, child: Center(child: CircularProgressIndicator())),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            if (isCompact)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppDropdown<HttpMethod>(
                    label: 'Method',
                    value: _selectedMethod,
                    items: HttpMethod.values.map((method) => DropdownMenuItem(value: method, child: Text(method.name))).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedMethod = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _urlController,
                    label: 'URL',
                    hint: 'https://api.example.com/endpoint',
                    keyboardType: TextInputType.url,
                    suffixIcon: _buildEnvVariableInsertButton(context, envList, _urlController, isDisabled: _isSavingEdits),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: AppDropdown<HttpMethod>(
                      label: 'Method',
                      value: _selectedMethod,
                      items: HttpMethod.values.map((method) => DropdownMenuItem(value: method, child: Text(method.name))).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedMethod = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: AppTextField(
                      controller: _urlController,
                      label: 'URL',
                      hint: 'https://api.example.com/endpoint',
                      keyboardType: TextInputType.url,
                      suffixIcon: _buildEnvVariableInsertButton(context, envList, _urlController, isDisabled: _isSavingEdits),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            AppDropdown<BodyType>(
              label: 'Body Type',
              value: _selectedBodyType,
              items: BodyType.values.map((type) => DropdownMenuItem(value: type, child: Text(type.displayName))).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedBodyType = value;
                });
              },
            ),
            const SizedBox(height: 16),
            buildBodyFields(),
            const SizedBox(height: 16),
            environmentsAsync.when(
              data: (envs) {
                if (envs.isEmpty) {
                  return const SizedBox.shrink();
                }
                final selectedEnvironment = _findEnvironmentByName(envs, _selectedEnvironmentName);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Environment', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedEnvironmentName,
                      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('No Environment')),
                        ...envs.map((env) => DropdownMenuItem<String?>(value: env.name, child: Text(env.name))),
                      ],
                      onChanged: _isSavingEdits
                          ? null
                          : (value) {
                              setState(() {
                                _selectedEnvironmentName = value;
                              });
                            },
                    ),
                    if (_selectedEnvironmentName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          selectedEnvironment != null && selectedEnvironment.variables.isNotEmpty
                              ? 'Variables from "$_selectedEnvironmentName" can be inserted as {{variableName}}.'
                              : 'No variables defined for "$_selectedEnvironmentName".',
                          style: theme.textTheme.bodySmall,
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
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            if (isCompact) ...[
              Text('Query / Path Parameters (optional)', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _isSavingEdits ? null : _handleAddParamRow,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Param'),
                ),
              ),
            ] else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Query / Path Parameters (optional)', style: theme.textTheme.titleSmall),
                  TextButton.icon(
                    onPressed: _isSavingEdits ? null : _handleAddParamRow,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Param'),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            ...List.generate(_paramKeyControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: isCompact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTextField(controller: _paramKeyControllers[index], label: 'Key', hint: 'userId'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  controller: _paramValueControllers[index],
                                  label: 'Value',
                                  hint: '123',
                                  suffixIcon: _buildEnvVariableInsertButton(
                                    context,
                                    envList,
                                    _paramValueControllers[index],
                                    isDisabled: _isSavingEdits,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Remove param',
                                onPressed: _isSavingEdits ? null : () => _handleRemoveParamRow(index),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AppTextField(controller: _paramKeyControllers[index], label: 'Key', hint: 'userId'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppTextField(
                              controller: _paramValueControllers[index],
                              label: 'Value',
                              hint: '123',
                              suffixIcon: _buildEnvVariableInsertButton(context, envList, _paramValueControllers[index], isDisabled: _isSavingEdits),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Remove param',
                            onPressed: _isSavingEdits ? null : () => _handleRemoveParamRow(index),
                          ),
                        ],
                      ),
              );
            }),
            const SizedBox(height: 12),
            if (isCompact)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextButton(onPressed: _isSavingEdits ? null : _cancelEditing, child: const Text('Cancel')),
                  const SizedBox(height: 8),
                  AppButton(
                    label: _isSavingEdits ? 'Saving...' : 'Save Changes',
                    icon: Icons.save_outlined,
                    onPressed: _isSavingEdits ? null : () => _saveEdits(context),
                    isFullWidth: true,
                  ),
                ],
              )
            else
              Row(
                children: [
                  TextButton(onPressed: _isSavingEdits ? null : _cancelEditing, child: const Text('Cancel')),
                  const Spacer(),
                  AppButton(
                    label: _isSavingEdits ? 'Saving...' : 'Save Changes',
                    icon: Icons.save_outlined,
                    onPressed: _isSavingEdits ? null : () => _saveEdits(context),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget? _buildEnvVariableInsertButton(
    BuildContext context,
    List<EnvironmentModel>? envs,
    TextEditingController controller, {
    bool isDisabled = false,
  }) {
    if (envs == null) {
      return null;
    }
    return IconButton(
      icon: const Icon(Icons.data_object),
      tooltip: 'Insert environment variable',
      onPressed: isDisabled ? null : () => _insertEnvironmentVariable(context, envs, controller),
    );
  }

  EnvironmentModel? _findEnvironmentByName(List<EnvironmentModel>? envs, String? name) {
    if (envs == null || name == null) {
      return null;
    }
    for (final env in envs) {
      if (env.name == name) {
        return env;
      }
    }
    return null;
  }

  Future<void> _insertEnvironmentVariable(BuildContext context, List<EnvironmentModel> environments, TextEditingController controller) async {
    // Use the request's selected environment instead of the global active environment
    final selectedName = _selectedEnvironmentName;
    final environment = _findEnvironmentByName(environments, selectedName);
    if (environment == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an environment with variables to insert.')));
      return;
    }
    if (environment.variables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Environment "${environment.name}" has no variables yet.')));
      return;
    }

    final entries = environment.variables.entries.toList()..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    final variableKey = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Insert Environment Variable', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Tap a variable to insert its placeholder into the focused field.', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final entry = entries[index];
                      return ListTile(
                        title: Text(entry.key),
                        subtitle: entry.value.isNotEmpty ? Text(entry.value) : null,
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () => Navigator.of(sheetContext).pop(entry.key),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (variableKey == null || variableKey.isEmpty) {
      return;
    }

    final placeholder = '{{${variableKey.trim()}}}';
    final selection = controller.selection;
    final baseText = controller.text;
    final textLength = baseText.length;
    int normalizePosition(int value, int fallback) {
      final raw = value >= 0 ? value : fallback;
      final clamped = raw.clamp(0, textLength);
      return clamped;
    }

    final normalizedStart = normalizePosition(selection.start, textLength);
    final normalizedEnd = normalizePosition(selection.end, normalizedStart);
    final start = normalizedStart <= normalizedEnd ? normalizedStart : normalizedEnd;
    final end = normalizedStart <= normalizedEnd ? normalizedEnd : normalizedStart;
    final newText = baseText.replaceRange(start, end, placeholder);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + placeholder.length),
    );
  }

  void _focusResponseBodySection() {
    _tabController.animateTo(2);
    final context = _responseSectionKey.currentContext;
    if (context == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    });
  }

  Widget _buildEnvironmentAction(BuildContext context, AsyncValue<List<EnvironmentModel>> envsAsync, String? envName) {
    final theme = Theme.of(context);
    final bool hasEnvironment = envName != null && envName.isNotEmpty;
    final Color iconColor = hasEnvironment ? theme.colorScheme.secondary : theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return envsAsync.when(
      data: (envs) => PopupMenuButton<String>(
        tooltip: 'Select environment',
        onSelected: _handleEnvironmentSelection,
        itemBuilder: (context) => _buildEnvironmentMenuItems(envs, envName),
        icon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud, size: 20, color: iconColor),
            const SizedBox(width: 4),
            Text(envName ?? 'No Env', style: theme.textTheme.labelMedium),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
      loading: () => const Padding(
        padding: EdgeInsets.all(8.0),
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  List<PopupMenuEntry<String>> _buildEnvironmentMenuItems(List<EnvironmentModel> envs, String? envName) {
    final items = <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        value: _noEnvironmentMenuValue,
        child: Row(
          children: [
            if (envName == null) const Icon(Icons.check, size: 18) else const SizedBox(width: 18),
            const SizedBox(width: 8),
            const Text('No Environment'),
          ],
        ),
      ),
    ];

    if (envs.isNotEmpty) {
      items.add(const PopupMenuDivider());
      items.addAll(
        envs.map(
          (env) => PopupMenuItem<String>(
            value: env.name,
            child: Row(
              children: [
                if (envName == env.name) const Icon(Icons.check, size: 18) else const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text(env.name),
              ],
            ),
          ),
        ),
      );
    }

    return items;
  }

  void _handleEnvironmentSelection(String name) {
    final selectedName = name == _noEnvironmentMenuValue ? null : name;
    setState(() {
      _selectedEnvironmentName = selectedName;
    });
  }

  void _handleAddHeaderRow() {
    setState(() {
      _headerKeyControllers.add(TextEditingController());
      _headerValueControllers.add(TextEditingController());
    });
  }

  void _handleRemoveHeaderRow(int index) {
    setState(() {
      _headerKeyControllers[index].dispose();
      _headerValueControllers[index].dispose();
      _headerKeyControllers.removeAt(index);
      _headerValueControllers.removeAt(index);
      if (_headerKeyControllers.isEmpty) {
        _headerKeyControllers.add(TextEditingController());
        _headerValueControllers.add(TextEditingController());
      }
    });
  }

  void _handleAddParamRow() {
    setState(() {
      _paramKeyControllers.add(TextEditingController());
      _paramValueControllers.add(TextEditingController());
    });
  }

  void _handleRemoveParamRow(int index) {
    setState(() {
      _paramKeyControllers[index].dispose();
      _paramValueControllers[index].dispose();
      _paramKeyControllers.removeAt(index);
      _paramValueControllers.removeAt(index);
      if (_paramKeyControllers.isEmpty) {
        _paramKeyControllers.add(TextEditingController());
        _paramValueControllers.add(TextEditingController());
      }
    });
  }

  void _handleAddFormDataRow() {
    setState(() {
      _formDataKeyControllers.add(TextEditingController());
      _formDataValueControllers.add(TextEditingController());
    });
  }

  void _handleRemoveFormDataRow(int index) {
    setState(() {
      _formDataKeyControllers[index].dispose();
      _formDataValueControllers[index].dispose();
      _formDataKeyControllers.removeAt(index);
      _formDataValueControllers.removeAt(index);
      if (_formDataKeyControllers.isEmpty) {
        _formDataKeyControllers.add(TextEditingController());
        _formDataValueControllers.add(TextEditingController());
      }
    });
  }

  void _toggleEditingMode() {
    setState(() {
      if (_isEditing) {
        _syncEditorsFromCurrentRequest();
        _isSavingEdits = false;
      }
      _isEditing = !_isEditing;
    });
  }

  void _cancelEditing() {
    setState(() {
      _syncEditorsFromCurrentRequest();
      _isSavingEdits = false;
      _isEditing = false;
    });
  }

  Future<void> _saveEdits(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    if (name.isEmpty || url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name and URL are required to update a request.'), backgroundColor: Colors.orange));
      return;
    }
    final collections = ref.read(collectionsNotifierProvider).asData?.value;
    final candidateCollectionId = (_selectedCollectionId ?? _currentRequest.collectionId).trim();
    var targetCollectionId = candidateCollectionId;
    if (collections != null && collections.isNotEmpty) {
      final exists = collections.any((c) => c.id == candidateCollectionId);
      if (!exists) {
        targetCollectionId = collections.first.id;
      }
    }
    if (targetCollectionId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a valid collection before saving.'), backgroundColor: Colors.orange));
      return;
    }

    final dataSourceState = ref.read(currentDataSourceStateProvider);
    if (dataSourceState?.mode == DataSourceMode.api && int.tryParse(targetCollectionId) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid API collection selected. Re-select a collection and try again.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final params = <String, String>{};
    for (int i = 0; i < _paramKeyControllers.length; i++) {
      final key = _paramKeyControllers[i].text.trim();
      final value = _paramValueControllers[i].text.trim();
      if (key.isNotEmpty) {
        params[key] = value;
      }
    }

    final rawBodyText = _requestBodyController.text.trim().isNotEmpty ? _requestBodyController.text.trim() : _bodyController.text.trim();
    final headers = _buildHeadersFromControllers();
    final formDataFields = _buildFormDataFieldsFromControllers();
    final normalizedBody = switch (_selectedBodyType) {
      BodyType.raw => rawBodyText.isNotEmpty ? rawBodyText : null,
      BodyType.binary => rawBodyText.isNotEmpty ? rawBodyText : null,
      BodyType.none || BodyType.formData || BodyType.urlEncoded => null,
    };
    final normalizedFormData = switch (_selectedBodyType) {
      BodyType.formData || BodyType.urlEncoded => formDataFields,
      BodyType.none || BodyType.raw || BodyType.binary => <String, String>{},
    };
    final updatedRequest = _currentRequest.copyWith(
      name: name,
      method: _selectedMethod,
      urlTemplate: url,
      headers: headers,
      queryParams: params,
      body: normalizedBody,
      bodyType: _selectedBodyType,
      formDataFields: normalizedFormData,
      collectionId: targetCollectionId,
      environmentName: _selectedEnvironmentName,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _isSavingEdits = true;
    });

    try {
      await ref.read(requestsNotifierProvider.notifier).updateRequest(updatedRequest);
      if (!mounted) return;
      setState(() {
        _currentRequest = updatedRequest;
        _isEditing = false;
        _isSavingEdits = false;
      });
      _syncEditorsFromCurrentRequest();
      messenger.showSnackBar(SnackBar(content: Text('Request "${updatedRequest.name}" updated successfully'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSavingEdits = false;
      });
      messenger.showSnackBar(SnackBar(content: Text('Failed to update request: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _buildMetaInfo(BuildContext context) {
    final statusCode = _response?.statusCode;
    final statusText = _response?.statusMessage;

    final durationText = _duration != null ? '${_duration!.inMilliseconds} ms' : '--';
    final sizeText = _response != null ? _formatBytes(_estimateResponseSizeInBytes(_response!.data)) : '--';
    final statusValue = statusCode != null ? '$statusCode ${statusText ?? ''}'.trim() : '--';
    final statusColor = statusCode == null
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : (statusCode >= 200 && statusCode < 300 ? Colors.green : Colors.orange);

    Widget metricChip(String label, String value, {Color? valueColor}) {
      final theme = Theme.of(context);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8)),
        ),
        child: RichText(
          text: TextSpan(
            style: theme.textTheme.bodySmall,
            children: [
              TextSpan(
                text: '$label: ',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              TextSpan(
                text: value,
                style: TextStyle(fontWeight: FontWeight.w700, color: valueColor ?? theme.colorScheme.onSurface),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        metricChip('Status', statusValue, valueColor: statusColor),
        metricChip('Time', durationText),
        metricChip('Size', sizeText),
      ],
    );
  }

  Widget _buildRequestBodyTab(BuildContext context, List<EnvironmentModel>? envs) {
    switch (_selectedBodyType) {
      case BodyType.none:
        return _buildStatusPanel(context, 'No request body (Body Type: None).');
      case BodyType.raw:
        final insertButton = _buildEnvVariableInsertButton(context, envs, _requestBodyController, isDisabled: _isSending);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (insertButton != null) ...[Align(alignment: Alignment.centerRight, child: insertButton), const SizedBox(height: 8)],
            Expanded(
              child: _buildPanelContainer(
                context,
                TextField(
                  controller: _requestBodyController,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: const InputDecoration.collapsed(hintText: 'Enter request body (JSON, raw text, etc.)'),
                ),
              ),
            ),
          ],
        );
      case BodyType.formData:
      case BodyType.urlEncoded:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isSending ? null : _handleAddFormDataRow,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Field'),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildPanelContainer(
                context,
                ListView.builder(
                  itemCount: _formDataKeyControllers.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AppTextField(controller: _formDataKeyControllers[index], label: 'Key', hint: 'fieldName', enabled: !_isSending),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppTextField(
                              controller: _formDataValueControllers[index],
                              label: 'Value',
                              hint: 'value',
                              enabled: !_isSending,
                              suffixIcon: _buildEnvVariableInsertButton(context, envs, _formDataValueControllers[index], isDisabled: _isSending),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Remove field',
                            onPressed: _isSending ? null : () => _handleRemoveFormDataRow(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      case BodyType.binary:
        return _buildPanelContainer(
          context,
          AppTextField(controller: _requestBodyController, label: 'Binary file path', hint: '/path/to/file.bin', enabled: !_isSending),
        );
    }
  }

  Widget _buildRequestHeadersTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _isSending ? null : _handleAddHeaderRow,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Header'),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildPanelContainer(
            context,
            ListView.builder(
              itemCount: _headerKeyControllers.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppTextField(controller: _headerKeyControllers[index], label: 'Key', hint: 'Content-Type', enabled: !_isSending),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppTextField(
                          controller: _headerValueControllers[index],
                          label: 'Value',
                          hint: 'application/json',
                          enabled: !_isSending,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove header',
                        onPressed: _isSending ? null : () => _handleRemoveHeaderRow(index),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResponseBodyTab(BuildContext context) {
    if (_isSending) {
      return _buildStatusPanel(context, 'Sending request...');
    }

    if (_error != null && _response == null) {
      final baseError = _error!.message ?? _error!.error?.toString() ?? _error.toString();
      if (_isPermissionError) {
        return _buildPermissionErrorPanel(context, baseError);
      }
      return _buildStatusPanel(context, 'Error: $baseError', color: Theme.of(context).colorScheme.error);
    }

    if (_response == null) {
      return _buildStatusPanel(context, 'Send the request to see the response.', color: Theme.of(context).colorScheme.onSurfaceVariant);
    }

    final response = _response!;
    final isHtml = _looksLikeHtmlResponse(response);
    final rawBody = _extractResponseBodyAsString();
    final prettyBody = _prettifyContent(response.data);

    final effectiveMode = _responseBodyViewMode == _ResponseBodyViewMode.preview && !isHtml ? _ResponseBodyViewMode.pretty : _responseBodyViewMode;

    Widget content;
    switch (effectiveMode) {
      case _ResponseBodyViewMode.pretty:
        final rendered = prettyBody.isEmpty ? (rawBody ?? '') : prettyBody;
        content = _buildMonospacePanel(context, rendered.isEmpty ? 'No response body' : rendered, selectable: true);
      case _ResponseBodyViewMode.raw:
        final rendered = rawBody ?? prettyBody;
        content = _buildMonospacePanel(context, rendered.isEmpty ? 'No response body' : rendered, selectable: true);
      case _ResponseBodyViewMode.preview:
        if (isHtml && rawBody != null && rawBody.trim().isNotEmpty) {
          content = _buildHtmlPanel(context, rawBody);
        } else {
          content = _buildStatusPanel(
            context,
            'Preview is available for HTML responses only.',
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );
        }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildResponseBodyModeSwitcher(context, canPreview: isHtml),
        const SizedBox(height: 8),
        Expanded(child: content),
      ],
    );
  }

  Widget _buildResponseHeadersTab(BuildContext context) {
    if (_isSending) {
      return _buildStatusPanel(context, 'Sending request...');
    }

    if (_error != null && _response == null) {
      final baseError = _error!.message ?? _error!.error?.toString() ?? _error.toString();
      if (_isPermissionError) {
        return _buildPermissionErrorPanel(context, baseError);
      }
      return _buildStatusPanel(context, 'Error: $baseError', color: Theme.of(context).colorScheme.error);
    }

    if (_response == null) {
      return _buildStatusPanel(context, 'Send the request to see the response headers.', color: Theme.of(context).colorScheme.onSurfaceVariant);
    }

    final headers = _response!.headers.map.map((key, values) => MapEntry(key, values.join(', ')));
    final content = headers.isEmpty ? 'No response headers' : _prettifyMap(headers);
    return _buildMonospacePanel(context, content, selectable: true);
  }

  Widget _buildResponseBodyModeSwitcher(BuildContext context, {required bool canPreview}) {
    final selected = {_responseBodyViewMode};
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<_ResponseBodyViewMode>(
        segments: [
          const ButtonSegment<_ResponseBodyViewMode>(value: _ResponseBodyViewMode.pretty, label: Text('Pretty')),
          const ButtonSegment<_ResponseBodyViewMode>(value: _ResponseBodyViewMode.raw, label: Text('Raw')),
          ButtonSegment<_ResponseBodyViewMode>(value: _ResponseBodyViewMode.preview, enabled: canPreview, label: const Text('Preview')),
        ],
        selected: selected,
        onSelectionChanged: (modes) {
          if (modes.isEmpty) return;
          final mode = modes.first;
          setState(() {
            _responseBodyViewMode = mode;
          });
        },
        showSelectedIcon: false,
      ),
    );
  }

  bool _looksLikeHtmlResponse(Response<dynamic> response) {
    final contentType = response.headers.value('content-type')?.toLowerCase() ?? '';
    if (contentType.contains('text/html') || contentType.contains('application/xhtml')) {
      return true;
    }

    final body = _extractResponseBodyAsString();
    if (body == null) {
      return false;
    }

    final snippet = body.trimLeft().toLowerCase();
    if (snippet.isEmpty) {
      return false;
    }

    return snippet.startsWith('<!doctype html') || snippet.startsWith('<html') || (snippet.contains('<html') && snippet.contains('</html>'));
  }

  int _estimateResponseSizeInBytes(dynamic data) {
    if (data == null) return 0;
    if (data is List<int>) return data.length;
    if (data is String) return utf8.encode(data).length;
    try {
      return utf8.encode(jsonEncode(data)).length;
    } catch (_) {
      return utf8.encode(data.toString()).length;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  Widget _buildPermissionErrorPanel(BuildContext context, String baseError) {
    final theme = Theme.of(context);
    return _buildPanelContainer(
      context,
      SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Network access is blocked by the operating system (permission error).',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(baseError, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            const SizedBox(height: 8),
            Text(
              'On macOS, please:\n'
              '- Ensure any firewall or security tool allows this app to access the network.\n'
              '- If using a VPN or proxy, verify it permits outbound HTTPS connections.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPanel(BuildContext context, String message, {Color? color}) {
    final theme = Theme.of(context);
    return _buildPanelContainer(
      context,
      SingleChildScrollView(
        child: Text(message, style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ),
    );
  }

  Widget _buildMonospacePanel(BuildContext context, String content, {bool selectable = false}) {
    return _buildPanelContainer(
      context,
      SingleChildScrollView(
        child: VariableHighlightText(
          text: content,
          style: const TextStyle(fontFamily: 'monospace'),
          selectable: selectable,
        ),
      ),
    );
  }

  Widget _buildPanelContainer(BuildContext context, Widget child) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: child,
    );
  }

  Widget _buildHtmlPanel(BuildContext context, String html) {
    final theme = Theme.of(context);
    final hasTableTag = RegExp(r'<\s*table[\s>]', caseSensitive: false).hasMatch(html);
    return _buildPanelContainer(
      context,
      SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasTableTag)
              Text(
                'HTML preview is unavailable for responses containing table markup. Use Raw to inspect the response body.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            else
              HtmlWidget(html, textStyle: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text('Raw HTML', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SelectableText(html, style: const TextStyle(fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }

  String? _extractResponseBodyAsString() {
    final data = _response?.data;
    if (data == null) {
      return null;
    }

    if (data is String) {
      return data;
    }

    if (data is List<int>) {
      try {
        return utf8.decode(data);
      } catch (_) {
        return String.fromCharCodes(data);
      }
    }

    return null;
  }

  String _prettifyContent(dynamic data) {
    return JsonUtils.pretty(data);
  }

  String _prettifyMap(Map data) {
    return JsonUtils.pretty(data);
  }

  Map<String, String> _buildHeadersFromControllers() {
    final headers = <String, String>{};
    for (int i = 0; i < _headerKeyControllers.length; i++) {
      final key = _headerKeyControllers[i].text.trim();
      final value = _headerValueControllers[i].text.trim();
      if (key.isNotEmpty) {
        headers[key] = value;
      }
    }
    return headers;
  }

  Map<String, String> _buildFormDataFieldsFromControllers() {
    final fields = <String, String>{};
    for (int i = 0; i < _formDataKeyControllers.length; i++) {
      final key = _formDataKeyControllers[i].text.trim();
      final value = _formDataValueControllers[i].text.trim();
      if (key.isNotEmpty) {
        fields[key] = value;
      }
    }
    return fields;
  }

  void _rebuildHeaderControllersFrom(ApiRequestModel request) {
    _disposeHeaderControllers();
    if (request.headers.isEmpty) {
      _headerKeyControllers.add(TextEditingController());
      _headerValueControllers.add(TextEditingController());
      return;
    }

    request.headers.forEach((key, value) {
      _headerKeyControllers.add(TextEditingController(text: key));
      _headerValueControllers.add(TextEditingController(text: value));
    });
  }

  void _rebuildParamControllersFrom(ApiRequestModel request) {
    _disposeParamControllers();
    if (request.queryParams.isEmpty) {
      _paramKeyControllers.add(TextEditingController());
      _paramValueControllers.add(TextEditingController());
      return;
    }

    request.queryParams.forEach((key, value) {
      _paramKeyControllers.add(TextEditingController(text: key));
      _paramValueControllers.add(TextEditingController(text: value));
    });
  }

  void _rebuildFormDataControllersFrom(ApiRequestModel request) {
    _disposeFormDataControllers();
    if (request.formDataFields.isEmpty) {
      _formDataKeyControllers.add(TextEditingController());
      _formDataValueControllers.add(TextEditingController());
      return;
    }

    request.formDataFields.forEach((key, value) {
      _formDataKeyControllers.add(TextEditingController(text: key));
      _formDataValueControllers.add(TextEditingController(text: value));
    });
  }

  void _disposeParamControllers() {
    for (final controller in _paramKeyControllers) {
      controller.dispose();
    }
    for (final controller in _paramValueControllers) {
      controller.dispose();
    }
    _paramKeyControllers.clear();
    _paramValueControllers.clear();
  }

  void _disposeHeaderControllers() {
    for (final controller in _headerKeyControllers) {
      controller.dispose();
    }
    for (final controller in _headerValueControllers) {
      controller.dispose();
    }
    _headerKeyControllers.clear();
    _headerValueControllers.clear();
  }

  void _disposeFormDataControllers() {
    for (final controller in _formDataKeyControllers) {
      controller.dispose();
    }
    for (final controller in _formDataValueControllers) {
      controller.dispose();
    }
    _formDataKeyControllers.clear();
    _formDataValueControllers.clear();
  }

  void _syncEditorsFromCurrentRequest() {
    _nameController.text = _currentRequest.name;
    _urlController.text = _currentRequest.urlTemplate;
    _bodyController.text = _currentRequest.body ?? '';
    _requestBodyController.text = _currentRequest.body ?? '';
    _selectedMethod = _currentRequest.method;
    _selectedBodyType = _currentRequest.bodyType;
    _selectedCollectionId = _currentRequest.collectionId;
    _selectedEnvironmentName = _currentRequest.environmentName;
    _rebuildHeaderControllersFrom(_currentRequest);
    _rebuildParamControllersFrom(_currentRequest);
    _rebuildFormDataControllersFrom(_currentRequest);
  }
}
