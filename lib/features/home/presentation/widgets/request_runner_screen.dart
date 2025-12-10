import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/models/collection_model.dart';
import 'package:relay/core/services/api_service.dart';
import 'package:relay/core/utils/json.dart';
import 'package:relay/core/utils/extension.dart';
import 'package:relay/features/home/presentation/providers/repository_providers.dart';
import 'package:relay/features/home/presentation/providers/collection_providers.dart';
import 'package:relay/features/home/presentation/providers/request_providers.dart';
import 'package:relay/features/home/presentation/providers/environment_providers.dart';

import '../../../../core/presentation/widgets/app_button.dart';
import '../../../../core/presentation/widgets/app_dropdown.dart';
import '../../../../core/presentation/widgets/app_text_field.dart';
import '../../../../core/presentation/widgets/method_badge.dart';

const String _noEnvironmentMenuValue = '__menu_no_environment__';

class RequestRunnerPage extends ConsumerStatefulWidget {
  const RequestRunnerPage({
    super.key,
    required this.request,
    this.onDelete,
    this.startInEditMode = false,
  });

  final ApiRequestModel request;
  final VoidCallback? onDelete;
  final bool startInEditMode;

  @override
  ConsumerState<RequestRunnerPage> createState() => _RequestRunnerPageState();
}

class _RequestRunnerPageState extends ConsumerState<RequestRunnerPage>
    with SingleTickerProviderStateMixin {
  bool _isSending = false;
  Response<dynamic>? _response;
  DioException? _error;
  Duration? _duration;
  bool _isPermissionError = false;
  late ApiRequestModel _currentRequest;
  bool _isEditing = false;
  bool _isSavingEdits = false;

  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late TextEditingController _bodyController;
  late TextEditingController _requestBodyController;
  final List<TextEditingController> _paramKeyControllers = [];
  final List<TextEditingController> _paramValueControllers = [];
  late HttpMethod _selectedMethod;
  String? _selectedCollectionId;
  late final TabController _tabController;
  late final ScrollController _scrollController;
  final GlobalKey _responseSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _currentRequest = widget.request;
    _selectedMethod = _currentRequest.method;
    _selectedCollectionId = _currentRequest.collectionId;
    _nameController = TextEditingController(text: _currentRequest.name);
    _urlController = TextEditingController(text: _currentRequest.urlTemplate);
    _bodyController = TextEditingController(text: _currentRequest.body ?? '');
    _requestBodyController = TextEditingController(text: _currentRequest.body ?? '');
    _rebuildParamControllersFrom(_currentRequest);
    _isEditing = widget.startInEditMode;
    _tabController = TabController(length: 4, vsync: this);
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(covariant RequestRunnerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id ||
        oldWidget.startInEditMode != widget.startInEditMode) {
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
    _disposeParamControllers();
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
    final activeEnv = await envRepository.getActiveEnvironment();
    final request = _currentRequest;

    // Resolve templates using the active environment
    final resolvedUrl = envRepository.resolveTemplate(request.urlTemplate, activeEnv);
    final resolvedHeaders = <String, String>{
      for (final entry in request.headers.entries)
        entry.key: envRepository.resolveTemplate(entry.value, activeEnv),
    };
    final resolvedQueryParams = <String, String>{
      for (final entry in request.queryParams.entries)
        entry.key: envRepository.resolveTemplate(entry.value, activeEnv),
    };
    final runtimeBody = _requestBodyController.text;
    final resolvedBody = runtimeBody.trim().isNotEmpty
        ? envRepository.resolveTemplate(runtimeBody, activeEnv)
        : null;

    // Debug logging for easier troubleshooting
    debugPrint('==== Relay Request ====');
    debugPrint('Name: ${request.name}');
    debugPrint('Method: ${request.method.name}');
    debugPrint('Active environment: ${activeEnv?.name}');
    debugPrint('Resolved URL: $resolvedUrl');
    debugPrint('Resolved headers: $resolvedHeaders');
    debugPrint('Resolved query params: $resolvedQueryParams');
    debugPrint('Resolved body: $resolvedBody');

    final dio = ApiService.instance.dio;

    final stopwatch = Stopwatch()..start();
    try {
      final response = await dio.request<dynamic>(
        resolvedUrl,
        options: Options(
          method: request.method.name,
          headers: resolvedHeaders.isEmpty ? null : resolvedHeaders,
        ),
        queryParameters: resolvedQueryParams.isEmpty ? null : resolvedQueryParams,
        data: resolvedBody,
      );
      stopwatch.stop();
      setState(() {
        _response = response;
        _duration = stopwatch.elapsed;
      });
    } on DioException catch (e) {
      stopwatch.stop();
      debugPrint('DioException while sending request:');
      debugPrint('  type: ${e.type}');
      debugPrint('  message: ${e.message}');
      debugPrint('  error: ${e.error}');
      debugPrint('  status code: ${e.response?.statusCode}');
      debugPrint('  status message: ${e.response?.statusMessage}');
      debugPrint('  data: ${e.response?.data}');

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
    final activeEnvName = ref.watch(activeEnvironmentNameProvider);
    final envList = environmentsAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            MethodBadge(method: request.method),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                request.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          _buildEnvironmentAction(context, environmentsAsync, activeEnvName),
          const SizedBox(width: 8),
          if (widget.onDelete != null)
            IconButton(
              tooltip: 'Delete request',
              icon: const Icon(Icons.delete_outline),
              onPressed: widget.onDelete,
            ),
          IconButton(
            tooltip: _isEditing ? 'Close editor' : 'Edit request',
            icon: Icon(_isEditing ? Icons.edit_off : Icons.edit),
            onPressed: _toggleEditingMode,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: SingleChildScrollView(
                  controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // URL
                    Text(
                      request.urlTemplate,
                      style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 8),
                    if (request.description != null && request.description!.isNotEmpty) ...[
                      Text(
                        request.description!,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_isEditing) ...[
                      _buildEditForm(context),
                      const SizedBox(height: 24),
                    ],
                    // Request/response details combined into a single tab controller
                    Column(
                      key: _responseSectionKey,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          labelColor: theme.colorScheme.primary,
                          indicatorColor: theme.colorScheme.primary,
                          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                          tabs: const [
                            Tab(text: 'Request Body'),
                            Tab(text: 'Request Headers'),
                            Tab(text: 'Response Body'),
                            Tab(text: 'Response Headers'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 320,
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
                  const SizedBox(height: 24),
                    // Send button + meta
                    Row(
                      children: [
                        AppButton(
                          label: _isSending ? 'Sending...' : 'Send',
                          icon: Icons.play_arrow,
                          onPressed: _isSending ? null : _sendRequest,
                        ),
                        const SizedBox(width: 16),
                        if (_response != null || _error != null)
                          _buildMetaInfo(context),
                        const Spacer(),
                        if (_isSending) const SizedBox(width: 120, child: LinearProgressIndicator()),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditForm(BuildContext context) {
    final theme = Theme.of(context);
    final collectionsAsync = ref.watch(collectionsNotifierProvider);
    final environmentsAsync = ref.watch(environmentsNotifierProvider);
    final selectedEnvName = ref.watch(activeEnvironmentNameProvider);
    final envList = environmentsAsync.asData?.value;
    final isCompact = MediaQuery.of(context).size.width < 600;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Request',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _nameController,
              label: 'Request Name',
              hint: 'My API Request',
            ),
            const SizedBox(height: 16),
            collectionsAsync.when(
              data: (collections) {
                final allCollections = [...collections];
                if (!allCollections.any((c) => c.id == 'default')) {
                  allCollections.insert(
                    0,
                    CollectionModel(
                      id: 'default',
                      name: 'Default',
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );
                }

                return AppDropdown<String>(
                  label: 'Collection',
                  value: _selectedCollectionId ?? 'default',
                  items: allCollections
                      .map(
                        (collection) => DropdownMenuItem(
                          value: collection.id,
                          child: Text(collection.name.isNotEmpty ? collection.name : collection.id),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCollectionId = value;
                    });
                  },
                );
              },
              loading: () => const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            if (isCompact)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppDropdown<HttpMethod>(
                    label: 'Method',
                    value: _selectedMethod,
                    items: HttpMethod.values
                        .map(
                          (method) => DropdownMenuItem(
                            value: method,
                            child: Text(method.name),
                          ),
                        )
                        .toList(),
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
                    suffixIcon: _buildEnvVariableInsertButton(
                      context,
                      envList,
                      _urlController,
                      isDisabled: _isSavingEdits,
                    ),
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
                      items: HttpMethod.values
                          .map(
                            (method) => DropdownMenuItem(
                              value: method,
                              child: Text(method.name),
                            ),
                          )
                          .toList(),
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
                      suffixIcon: _buildEnvVariableInsertButton(
                        context,
                        envList,
                        _urlController,
                        isDisabled: _isSavingEdits,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _bodyController,
              label: 'Body (optional)',
              hint: '{ "key": "value" }',
              maxLines: 4,
              suffixIcon: _buildEnvVariableInsertButton(
                context,
                envList,
                _bodyController,
                isDisabled: _isSavingEdits,
              ),
            ),
            const SizedBox(height: 16),
            environmentsAsync.when(
              data: (envs) {
                if (envs.isEmpty) {
                  return const SizedBox.shrink();
                }
                final selectedEnvironment = _findEnvironmentByName(envs, selectedEnvName);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Environment',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      value: selectedEnvName,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No Environment'),
                        ),
                        ...envs.map(
                          (env) => DropdownMenuItem<String?>(
                            value: env.name,
                            child: Text(env.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        ref.read(activeEnvironmentNameProvider.notifier).state = value;
                        ref.read(activeEnvironmentNotifierProvider.notifier).setActiveEnvironment(value);
                      },
                    ),
                    if (selectedEnvName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          selectedEnvironment != null && selectedEnvironment.variables.isNotEmpty
                              ? 'Variables from "$selectedEnvName" can be inserted as {{variableName}}.'
                              : 'No variables defined for "$selectedEnvName".',
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
                              .map((entry) => Chip(label: Text('{{${entry.key}}}')))
                              .toList(),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            if (isCompact) ...[
              Text(
                'Query / Path Parameters (optional)',
                style: theme.textTheme.titleSmall,
              ),
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
                  Text(
                    'Query / Path Parameters (optional)',
                    style: theme.textTheme.titleSmall,
                  ),
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
                          AppTextField(
                            controller: _paramKeyControllers[index],
                            label: 'Key',
                            hint: 'userId',
                          ),
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
                            child: AppTextField(
                              controller: _paramKeyControllers[index],
                              label: 'Key',
                              hint: 'userId',
                            ),
                          ),
                          const SizedBox(width: 8),
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
              );
            }),
            const SizedBox(height: 12),
            if (isCompact)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextButton(
                    onPressed: _isSavingEdits ? null : _cancelEditing,
                    child: const Text('Cancel'),
                  ),
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
                  TextButton(
                    onPressed: _isSavingEdits ? null : _cancelEditing,
                    child: const Text('Cancel'),
                  ),
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

  EnvironmentModel? _findEnvironmentByName(
    List<EnvironmentModel>? envs,
    String? name,
  ) {
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

  Future<void> _insertEnvironmentVariable(
    BuildContext context,
    List<EnvironmentModel> environments,
    TextEditingController controller,
  ) async {
    final selectedName = ref.read(activeEnvironmentNameProvider);
    final environment = _findEnvironmentByName(environments, selectedName);
    if (environment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an environment with variables to insert.'),
        ),
      );
      return;
    }
    if (environment.variables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Environment "${environment.name}" has no variables yet.'),
        ),
      );
      return;
    }

    final entries = environment.variables.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    final variableKey = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Insert Environment Variable',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap a variable to insert its placeholder into the focused field.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
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
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Widget _buildEnvironmentAction(
    BuildContext context,
    AsyncValue<List<EnvironmentModel>> envsAsync,
    String? activeEnvName,
  ) {
    final theme = Theme.of(context);
    return envsAsync.when(
      data: (envs) => PopupMenuButton<String>(
        tooltip: 'Select environment',
        onSelected: _handleEnvironmentSelection,
        itemBuilder: (context) => _buildEnvironmentMenuItems(envs, activeEnvName),
        icon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud, size: 20),
            const SizedBox(width: 4),
            Text(
              activeEnvName ?? 'No Env',
              style: theme.textTheme.labelMedium,
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
      loading: () => const Padding(
        padding: EdgeInsets.all(8.0),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  List<PopupMenuEntry<String>> _buildEnvironmentMenuItems(
    List<EnvironmentModel> envs,
    String? activeEnvName,
  ) {
    final items = <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        value: _noEnvironmentMenuValue,
        child: Row(
          children: [
            if (activeEnvName == null)
              const Icon(Icons.check, size: 18)
            else
              const SizedBox(width: 18),
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
                if (activeEnvName == env.name)
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
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
    ref.read(activeEnvironmentNameProvider.notifier).state = selectedName;
    ref.read(activeEnvironmentNotifierProvider.notifier).setActiveEnvironment(selectedName);
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
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    if (name.isEmpty || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name and URL are required to update a request.'),
          backgroundColor: Colors.orange,
        ),
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

    final bodyText = _bodyController.text.trim();
    final updatedRequest = _currentRequest.copyWith(
      name: name,
      method: _selectedMethod,
      urlTemplate: url,
      queryParams: params,
      body: bodyText.isNotEmpty ? bodyText : null,
      collectionId: _selectedCollectionId ?? 'default',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request "${updatedRequest.name}" updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSavingEdits = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildMetaInfo(BuildContext context) {
    final statusCode = _response?.statusCode;
    final statusText = _response?.statusMessage;

    final durationText = _duration != null
        ? '${_duration!.inMilliseconds} ms'
        : null;

    return Row(
      children: [
        if (statusCode != null) ...[
          Text(
            '$statusCode ${statusText ?? ''}'.trim(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: statusCode >= 200 && statusCode < 300
                      ? Colors.green
                      : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: 12),
        ],
        if (durationText != null)
          Text(
            durationText,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _buildRequestBodyTab(
    BuildContext context,
    List<EnvironmentModel>? envs,
  ) {
    final insertButton = _buildEnvVariableInsertButton(
      context,
      envs,
      _requestBodyController,
      isDisabled: _isSending,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (insertButton != null) ...[
          Align(
            alignment: Alignment.centerRight,
            child: insertButton,
          ),
          const SizedBox(height: 8),
        ],
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
              decoration: const InputDecoration.collapsed(
                hintText: 'Enter request body (JSON, raw text, etc.)',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestHeadersTab(BuildContext context) {
    final headers = _currentRequest.headers;
    final content = headers.isEmpty ? 'No request headers' : _prettifyMap(headers);
    return _buildMonospacePanel(context, content);
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
      return _buildStatusPanel(
        context,
        'Error: $baseError',
        color: Theme.of(context).colorScheme.error,
      );
    }

    if (_response == null) {
      return _buildStatusPanel(
        context,
        'Send the request to see the response.',
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
    }

    final isHtml = _isHtmlResponseBody();
    final rawBody = _extractResponseBodyAsString();
    if (isHtml && rawBody != null && rawBody.trim().isNotEmpty) {
      return _buildHtmlPanel(context, rawBody);
    }

    final bodyText = _prettifyContent(_response!.data);
    final content = bodyText.isEmpty ? 'No response body' : bodyText;
    return _buildMonospacePanel(context, content);
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
      return _buildStatusPanel(
        context,
        'Error: $baseError',
        color: Theme.of(context).colorScheme.error,
      );
    }

    if (_response == null) {
      return _buildStatusPanel(
        context,
        'Send the request to see the response headers.',
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
    }

    final headers = _response!.headers.map.map(
      (key, values) => MapEntry(key, values.join(', ')),
    );
    final content = headers.isEmpty ? 'No response headers' : _prettifyMap(headers);
    return _buildMonospacePanel(context, content);
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
              style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              baseError,
              style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
            ),
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
        child: Text(
          message,
          style: theme.textTheme.bodySmall?.copyWith(color: color),
        ),
      ),
    );
  }

  Widget _buildMonospacePanel(BuildContext context, String content) {
    return _buildPanelContainer(
      context,
      SingleChildScrollView(
        child: SelectableText(
          content,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
      ),
    );
  }

  Widget _buildPanelContainer(BuildContext context, Widget child) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
      ),
      child: child,
    );
  }

  Widget _buildHtmlPanel(BuildContext context, String html) {
    final theme = Theme.of(context);
    return _buildPanelContainer(
      context,
      SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HtmlWidget(
              html,
              textStyle: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Divider(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
            const SizedBox(height: 8),
            Text(
              'Raw HTML',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SelectableText(
              html,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  bool _isHtmlResponseBody() {
    if (_response == null) {
      return false;
    }

    final contentType = _response!.headers.value('content-type')?.toLowerCase() ?? '';
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

    return snippet.startsWith('<!doctype html') ||
        snippet.startsWith('<html') ||
        (snippet.contains('<html') && snippet.contains('</html>'));
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

  void _syncEditorsFromCurrentRequest() {
    _nameController.text = _currentRequest.name;
    _urlController.text = _currentRequest.urlTemplate;
    _bodyController.text = _currentRequest.body ?? '';
    _requestBodyController.text = _currentRequest.body ?? '';
    _selectedMethod = _currentRequest.method;
    _selectedCollectionId = _currentRequest.collectionId;
    _rebuildParamControllersFrom(_currentRequest);
  }
}


