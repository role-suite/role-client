import 'package:flutter/material.dart';

import '../../core/models/assertion.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/id.dart';
import 'app_button.dart';
import 'labeled_field.dart';

/// One row per assertion — type, optional target (header name / JSON path),
/// expected value, enabled toggle, remove — plus an "Add assertion" button.
/// Follows the same row-list editing shape as [KeyValueEditor].
class AssertionsEditor extends StatefulWidget {
  const AssertionsEditor({super.key, required this.initial, required this.onChanged, this.enabled = true});

  final List<Assertion> initial;
  final ValueChanged<List<Assertion>> onChanged;
  final bool enabled;

  @override
  State<AssertionsEditor> createState() => _AssertionsEditorState();
}

class _AssertionsEditorState extends State<AssertionsEditor> {
  final List<Assertion> _assertions = [];

  @override
  void initState() {
    super.initState();
    _assertions.addAll(widget.initial);
  }

  void _emit() => widget.onChanged(_assertions);

  void _update(int index, Assertion next) {
    setState(() => _assertions[index] = next);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_assertions.isEmpty) Text('No assertions yet — add one to check the response automatically.', style: context.type.caption),
        for (var i = 0; i < _assertions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                border: Border.all(color: colors.border),
                borderRadius: AppRadius.smRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _assertions[i].enabled,
                        visualDensity: VisualDensity.compact,
                        onChanged: widget.enabled ? (v) => _update(i, _assertions[i].copyWith(enabled: v ?? true)) : null,
                      ),
                      Expanded(
                        child: AppDropdown<AssertionType>(
                          value: _assertions[i].type,
                          items: AssertionType.values,
                          itemLabel: (t) => t.label,
                          onChanged: widget.enabled ? (t) => _update(i, _assertions[i].copyWith(type: t)) : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      AppIconButton(
                        icon: Icons.close,
                        tooltip: 'Remove assertion',
                        onPressed: widget.enabled
                            ? () {
                                setState(() => _assertions.removeAt(i));
                                _emit();
                              }
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      if (_assertions[i].type.needsTarget) ...[
                        Expanded(
                          child: _AssertionField(
                            hint: _assertions[i].type == AssertionType.headerEquals ? 'Header name' : 'JSON path (e.g. data.id)',
                            initialValue: _assertions[i].target ?? '',
                            enabled: widget.enabled,
                            onChanged: (v) => _update(i, _assertions[i].copyWith(target: v)),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      Expanded(
                        child: _AssertionField(
                          hint: 'Expected value',
                          initialValue: _assertions[i].expected,
                          enabled: widget.enabled,
                          onChanged: (v) => _update(i, _assertions[i].copyWith(expected: v)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        AppButton(
          label: 'Add assertion',
          icon: Icons.add,
          variant: AppButtonVariant.secondary,
          dense: true,
          onPressed: widget.enabled
              ? () {
                  setState(() => _assertions.add(Assertion(id: generateId('assert'), type: AssertionType.statusEquals, expected: '200')));
                  _emit();
                }
              : null,
        ),
      ],
    );
  }
}

class _AssertionField extends StatefulWidget {
  const _AssertionField({required this.hint, required this.initialValue, required this.enabled, required this.onChanged});

  final String hint;
  final String initialValue;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  State<_AssertionField> createState() => _AssertionFieldState();
}

class _AssertionFieldState extends State<_AssertionField> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.controlHeightSm + 4,
      child: TextField(
        controller: _controller,
        enabled: widget.enabled,
        style: context.type.monoSmall.copyWith(color: context.colors.textPrimary),
        decoration: InputDecoration(hintText: widget.hint, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
        onChanged: widget.onChanged,
      ),
    );
  }
}
