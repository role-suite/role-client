import 'package:flutter/material.dart';
import 'package:relay/core/models/api_request_model.dart';
import 'package:relay/core/models/environment_model.dart';
import 'package:relay/core/models/request_enums.dart';
import 'package:relay/core/utils/uuid.dart';

import '../../../../core/utils/extension.dart';

class RequestFormController extends ChangeNotifier {
  RequestFormController({String? initialCollectionId, String? initialEnvironmentName, ApiRequestModel? initialRequest}) {
    _nameController = TextEditingController(text: initialRequest?.name ?? '');
    _urlController = TextEditingController(text: initialRequest?.urlTemplate ?? '');
    _bodyController = TextEditingController(text: initialRequest?.body ?? '');
    _selectedMethod = initialRequest?.method ?? HttpMethod.get;
    _selectedCollectionId = initialRequest?.collectionId ?? initialCollectionId ?? 'default';
    _selectedEnvironmentName = initialRequest?.environmentName ?? initialEnvironmentName;
    _selectedBodyType = initialRequest?.bodyType ?? BodyType.raw;
    _selectedAuthType = initialRequest?.authType ?? AuthType.none;

    final headers = initialRequest?.headers ?? {};
    if (headers.isNotEmpty) {
      for (final e in headers.entries) {
        addHeaderRow(key: e.key, value: e.value);
      }
    } else {
      addHeaderRow();
    }

    final params = initialRequest?.queryParams ?? {};
    if (params.isNotEmpty) {
      for (final e in params.entries) {
        addParamRow(key: e.key, value: e.value);
      }
    } else {
      addParamRow();
    }

    final formData = initialRequest?.formDataFields ?? {};
    if (formData.isNotEmpty) {
      for (final e in formData.entries) {
        addFormDataRow(key: e.key, value: e.value);
      }
    } else {
      addFormDataRow();
    }

    final authConfig = initialRequest?.authConfig ?? {};
    _authTokenController = TextEditingController(text: authConfig[AuthConfigKeys.token] ?? '');
    _authUsernameController = TextEditingController(text: authConfig[AuthConfigKeys.username] ?? '');
    _authPasswordController = TextEditingController(text: authConfig[AuthConfigKeys.password] ?? '');
    _authApiKeyHeaderController = TextEditingController(text: authConfig[AuthConfigKeys.key] ?? 'X-Api-Key');
    _authApiKeyValueController = TextEditingController(text: authConfig[AuthConfigKeys.value] ?? '');
  }

  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _bodyController;
  late final TextEditingController _authTokenController;
  late final TextEditingController _authUsernameController;
  late final TextEditingController _authPasswordController;
  late final TextEditingController _authApiKeyHeaderController;
  late final TextEditingController _authApiKeyValueController;

  final List<TextEditingController> _headerKeyControllers = [];
  final List<TextEditingController> _headerValueControllers = [];
  final List<TextEditingController> _paramKeyControllers = [];
  final List<TextEditingController> _paramValueControllers = [];
  final List<TextEditingController> _formDataKeyControllers = [];
  final List<TextEditingController> _formDataValueControllers = [];

  late HttpMethod _selectedMethod;
  String? _selectedCollectionId;
  String? _selectedEnvironmentName;
  BodyType _selectedBodyType = BodyType.raw;
  AuthType _selectedAuthType = AuthType.none;

  TextEditingController get nameController => _nameController;
  TextEditingController get urlController => _urlController;
  TextEditingController get bodyController => _bodyController;
  TextEditingController get authTokenController => _authTokenController;
  TextEditingController get authUsernameController => _authUsernameController;
  TextEditingController get authPasswordController => _authPasswordController;
  TextEditingController get authApiKeyHeaderController => _authApiKeyHeaderController;
  TextEditingController get authApiKeyValueController => _authApiKeyValueController;

  List<TextEditingController> get headerKeyControllers => List.unmodifiable(_headerKeyControllers);
  List<TextEditingController> get headerValueControllers => List.unmodifiable(_headerValueControllers);
  List<TextEditingController> get paramKeyControllers => List.unmodifiable(_paramKeyControllers);
  List<TextEditingController> get paramValueControllers => List.unmodifiable(_paramValueControllers);
  List<TextEditingController> get formDataKeyControllers => List.unmodifiable(_formDataKeyControllers);
  List<TextEditingController> get formDataValueControllers => List.unmodifiable(_formDataValueControllers);

  HttpMethod get selectedMethod => _selectedMethod;
  String? get selectedCollectionId => _selectedCollectionId;
  String? get selectedEnvironmentName => _selectedEnvironmentName;
  BodyType get selectedBodyType => _selectedBodyType;
  AuthType get selectedAuthType => _selectedAuthType;

  set selectedMethod(HttpMethod method) {
    if (_selectedMethod == method) return;
    _selectedMethod = method;
    notifyListeners();
  }

  set selectedCollectionId(String? id) {
    if (_selectedCollectionId == id) return;
    _selectedCollectionId = id;
    notifyListeners();
  }

  set selectedEnvironmentName(String? name) {
    if (_selectedEnvironmentName == name) return;
    _selectedEnvironmentName = name;
    notifyListeners();
  }

  set selectedBodyType(BodyType value) {
    if (_selectedBodyType == value) return;
    _selectedBodyType = value;
    notifyListeners();
  }

  set selectedAuthType(AuthType value) {
    if (_selectedAuthType == value) return;
    _selectedAuthType = value;
    notifyListeners();
  }

  void addHeaderRow({String key = '', String value = ''}) {
    _headerKeyControllers.add(TextEditingController(text: key));
    _headerValueControllers.add(TextEditingController(text: value));
    notifyListeners();
  }

  void removeHeaderRow(int index) {
    if (index < 0 || index >= _headerKeyControllers.length) return;
    _headerKeyControllers[index].dispose();
    _headerValueControllers[index].dispose();
    _headerKeyControllers.removeAt(index);
    _headerValueControllers.removeAt(index);
    if (_headerKeyControllers.isEmpty) {
      addHeaderRow();
    }
    notifyListeners();
  }

  Map<String, String> buildHeaders() {
    final map = <String, String>{};
    for (int i = 0; i < _headerKeyControllers.length; i++) {
      final k = _headerKeyControllers[i].text.trim();
      final v = _headerValueControllers[i].text.trim();
      if (k.isNotEmpty) map[k] = v;
    }
    return map;
  }

  void addParamRow({String key = '', String value = ''}) {
    _paramKeyControllers.add(TextEditingController(text: key));
    _paramValueControllers.add(TextEditingController(text: value));
    notifyListeners();
  }

  void removeParamRow(int index) {
    if (index < 0 || index >= _paramKeyControllers.length) return;
    _paramKeyControllers[index].dispose();
    _paramValueControllers[index].dispose();
    _paramKeyControllers.removeAt(index);
    _paramValueControllers.removeAt(index);
    if (_paramKeyControllers.isEmpty) {
      addParamRow();
      return;
    }
    notifyListeners();
  }

  void addFormDataRow({String key = '', String value = ''}) {
    _formDataKeyControllers.add(TextEditingController(text: key));
    _formDataValueControllers.add(TextEditingController(text: value));
    notifyListeners();
  }

  void removeFormDataRow(int index) {
    if (index < 0 || index >= _formDataKeyControllers.length) return;
    _formDataKeyControllers[index].dispose();
    _formDataValueControllers[index].dispose();
    _formDataKeyControllers.removeAt(index);
    _formDataValueControllers.removeAt(index);
    if (_formDataKeyControllers.isEmpty) {
      addFormDataRow();
    }
    notifyListeners();
  }

  Map<String, String> buildFormDataFields() {
    final map = <String, String>{};
    for (int i = 0; i < _formDataKeyControllers.length; i++) {
      final k = _formDataKeyControllers[i].text.trim();
      final v = _formDataValueControllers[i].text.trim();
      if (k.isNotEmpty) map[k] = v;
    }
    return map;
  }

  Map<String, String> buildAuthConfig() {
    switch (_selectedAuthType) {
      case AuthType.none:
        return {};
      case AuthType.bearer:
        final t = _authTokenController.text.trim();
        return t.isEmpty ? {} : {AuthConfigKeys.token: t};
      case AuthType.basic:
        final u = _authUsernameController.text.trim();
        final p = _authPasswordController.text.trim();
        final map = <String, String>{};
        if (u.isNotEmpty) map[AuthConfigKeys.username] = u;
        if (p.isNotEmpty) map[AuthConfigKeys.password] = p;
        return map;
      case AuthType.apiKey:
        final header = _authApiKeyHeaderController.text.trim();
        final value = _authApiKeyValueController.text.trim();
        if (header.isEmpty) return {};
        return {AuthConfigKeys.key: header, AuthConfigKeys.value: value};
    }
  }

  Map<String, String> buildParams() {
    final params = <String, String>{};
    for (int i = 0; i < _paramKeyControllers.length; i++) {
      final key = _paramKeyControllers[i].text.trim();
      final value = _paramValueControllers[i].text.trim();
      if (key.isNotEmpty) {
        params[key] = value;
      }
    }
    return params;
  }

  String? validateRequiredFields() {
    if (_nameController.text.trim().isEmpty || _urlController.text.trim().isEmpty) {
      return 'Please fill in all required fields';
    }
    return null;
  }

  ApiRequestModel buildRequest() {
    final now = DateTime.now();
    final body = _bodyController.text.trim();
    final formDataFields = buildFormDataFields();
    return ApiRequestModel(
      id: UuidUtils.generate(),
      name: _nameController.text.trim(),
      method: _selectedMethod,
      urlTemplate: _urlController.text.trim(),
      headers: buildHeaders(),
      queryParams: buildParams(),
      body: body.isEmpty ? null : body,
      bodyType: _selectedBodyType,
      formDataFields: formDataFields,
      authType: _selectedAuthType,
      authConfig: buildAuthConfig(),
      collectionId: _selectedCollectionId ?? 'default',
      environmentName: _selectedEnvironmentName,
      createdAt: now,
      updatedAt: now,
    );
  }

  EnvironmentModel? findEnvironmentByName(List<EnvironmentModel> envs, String? name) {
    if (name == null) return null;
    for (final env in envs) {
      if (env.name == name) {
        return env;
      }
    }
    return null;
  }

  Future<void> insertVariableIntoController(BuildContext context, List<EnvironmentModel> environments, TextEditingController controller) async {
    final environment = findEnvironmentByName(environments, _selectedEnvironmentName);
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
      builder: (dialogContext) {
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
                        onTap: () => Navigator.of(dialogContext).pop(entry.key),
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

    if (variableKey == null || variableKey.isEmpty) return;

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

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _bodyController.dispose();
    _authTokenController.dispose();
    _authUsernameController.dispose();
    _authPasswordController.dispose();
    _authApiKeyHeaderController.dispose();
    _authApiKeyValueController.dispose();
    for (final c in _headerKeyControllers) c.dispose();
    for (final c in _headerValueControllers) c.dispose();
    for (final c in _paramKeyControllers) c.dispose();
    for (final c in _paramValueControllers) c.dispose();
    for (final c in _formDataKeyControllers) c.dispose();
    for (final c in _formDataValueControllers) c.dispose();
    super.dispose();
  }
}
