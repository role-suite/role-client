import 'package:flutter/material.dart';
import 'package:relay/core/model/api_request_model.dart';
import 'package:relay/core/model/environment_model.dart';
import 'package:relay/core/util/uuid.dart';

import '../../../../core/util/extension.dart';

class RequestFormController extends ChangeNotifier {
  RequestFormController({
    String? initialCollectionId,
    String? initialEnvironmentName,
    ApiRequestModel? initialRequest,
  }) {
    _nameController = TextEditingController(text: initialRequest?.name ?? '');
    _urlController = TextEditingController(text: initialRequest?.urlTemplate ?? '');
    _bodyController = TextEditingController(text: initialRequest?.body ?? '');
    _selectedMethod = initialRequest?.method ?? HttpMethod.get;
    _selectedCollectionId = initialRequest?.collectionId ?? initialCollectionId ?? 'default';
    _selectedEnvironmentName = initialEnvironmentName;

    final params = initialRequest?.queryParams ?? {};
    if (params.isNotEmpty) {
      params.forEach((key, value) {
        addParamRow(key: key, value: value);
      });
    } else {
      addParamRow();
    }
  }

  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _bodyController;

  final List<TextEditingController> _paramKeyControllers = [];
  final List<TextEditingController> _paramValueControllers = [];

  late HttpMethod _selectedMethod;
  String? _selectedCollectionId;
  String? _selectedEnvironmentName;

  TextEditingController get nameController => _nameController;
  TextEditingController get urlController => _urlController;
  TextEditingController get bodyController => _bodyController;

  List<TextEditingController> get paramKeyControllers => List.unmodifiable(_paramKeyControllers);
  List<TextEditingController> get paramValueControllers => List.unmodifiable(_paramValueControllers);

  HttpMethod get selectedMethod => _selectedMethod;
  String? get selectedCollectionId => _selectedCollectionId;
  String? get selectedEnvironmentName => _selectedEnvironmentName;

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
    return ApiRequestModel(
      id: UuidUtils.generate(),
      name: _nameController.text.trim(),
      method: _selectedMethod,
      urlTemplate: _urlController.text.trim(),
      queryParams: buildParams(),
      body: _bodyController.text.trim().isNotEmpty ? _bodyController.text.trim() : null,
      collectionId: _selectedCollectionId ?? 'default',
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

  Future<void> insertVariableIntoController(
    BuildContext context,
    List<EnvironmentModel> environments,
    TextEditingController controller,
  ) async {
    final environment = findEnvironmentByName(environments, _selectedEnvironmentName);
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
      builder: (dialogContext) {
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
    for (final controller in _paramKeyControllers) {
      controller.dispose();
    }
    for (final controller in _paramValueControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

