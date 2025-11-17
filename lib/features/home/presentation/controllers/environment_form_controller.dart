import 'package:flutter/material.dart';
import 'package:relay/core/model/environment_model.dart';

class EnvironmentFormController extends ChangeNotifier {
  EnvironmentFormController({EnvironmentModel? initialEnvironment})
      : _isEdit = initialEnvironment != null {
    _nameController = TextEditingController(text: initialEnvironment?.name ?? '');

    if (initialEnvironment != null && initialEnvironment.variables.isNotEmpty) {
      initialEnvironment.variables.forEach((key, value) {
        addVariableRow(key: key, value: value);
      });
    }

    if (_variableKeyControllers.isEmpty) {
      addVariableRow();
    }
  }

  late final TextEditingController _nameController;
  final List<TextEditingController> _variableKeyControllers = [];
  final List<TextEditingController> _variableValueControllers = [];
  final bool _isEdit;

  TextEditingController get nameController => _nameController;
  bool get isEdit => _isEdit;
  List<TextEditingController> get variableKeyControllers => List.unmodifiable(_variableKeyControllers);
  List<TextEditingController> get variableValueControllers => List.unmodifiable(_variableValueControllers);

  void addVariableRow({String key = '', String value = ''}) {
    _variableKeyControllers.add(TextEditingController(text: key));
    _variableValueControllers.add(TextEditingController(text: value));
    notifyListeners();
  }

  void removeVariableRow(int index) {
    if (index < 0 || index >= _variableKeyControllers.length) return;
    _variableKeyControllers[index].dispose();
    _variableValueControllers[index].dispose();
    _variableKeyControllers.removeAt(index);
    _variableValueControllers.removeAt(index);
    if (_variableKeyControllers.isEmpty) {
      addVariableRow();
      return;
    }
    notifyListeners();
  }

  Map<String, String> buildVariables() {
    final vars = <String, String>{};
    for (int i = 0; i < _variableKeyControllers.length; i++) {
      final key = _variableKeyControllers[i].text.trim();
      final value = _variableValueControllers[i].text.trim();
      if (key.isNotEmpty) {
        vars[key] = value;
      }
    }
    return vars;
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final controller in _variableKeyControllers) {
      controller.dispose();
    }
    for (final controller in _variableValueControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

