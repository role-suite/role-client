import 'package:flutter/material.dart';

import '../../core/models/environment_variable.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import 'app_button.dart';

/// An editable environment-variable table: enable toggle, key, value (with a
/// secret mask/reveal toggle), remove — plus a trailing empty row that grows
/// the list as soon as you type into it. `position` is re-derived from row
/// order on every emit.
class EnvironmentVariableEditor extends StatefulWidget {
  const EnvironmentVariableEditor({super.key, required this.initial, required this.onChanged});

  final List<EnvironmentVariable> initial;
  final ValueChanged<List<EnvironmentVariable>> onChanged;

  @override
  State<EnvironmentVariableEditor> createState() => _EnvironmentVariableEditorState();
}

class _EnvironmentVariableEditorState extends State<EnvironmentVariableEditor> {
  final List<EnvironmentVariable> _rows = [];
  final Set<int> _revealed = {};

  @override
  void initState() {
    super.initState();
    _rows.addAll(widget.initial);
    _ensureTrailingRow();
  }

  void _emit() {
    final entries = <EnvironmentVariable>[];
    var position = 0;
    for (final row in _rows) {
      if (row.key.isEmpty) continue;
      entries.add(row.copyWith(position: position++));
    }
    widget.onChanged(entries);
  }

  void _ensureTrailingRow() {
    if (_rows.isEmpty || _rows.last.key.isNotEmpty || _rows.last.value.isNotEmpty) {
      _rows.add(const EnvironmentVariable(key: '', value: ''));
    }
  }

  void _updateRow(int index, EnvironmentVariable next) {
    setState(() {
      _rows[index] = next;
      _ensureTrailingRow();
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                Checkbox(
                  value: _rows[i].enabled,
                  visualDensity: VisualDensity.compact,
                  onChanged: (v) => _updateRow(i, _rows[i].copyWith(enabled: v ?? true)),
                ),
                Expanded(
                  child: _RowField(
                    hint: 'Variable',
                    initialValue: _rows[i].key,
                    onChanged: (v) => _updateRow(i, _rows[i].copyWith(key: v)),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _RowField(
                    hint: 'Value',
                    initialValue: _rows[i].value,
                    obscure: _rows[i].isSecret && !_revealed.contains(i),
                    onChanged: (v) => _updateRow(i, _rows[i].copyWith(value: v)),
                  ),
                ),
                AppIconButton(
                  icon: _rows[i].isSecret ? Icons.lock_outline : Icons.lock_open_outlined,
                  tooltip: _rows[i].isSecret ? 'Secret' : 'Mark as secret',
                  onPressed: () => _updateRow(i, _rows[i].copyWith(isSecret: !_rows[i].isSecret)),
                ),
                if (_rows[i].isSecret)
                  AppIconButton(
                    icon: _revealed.contains(i) ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    tooltip: _revealed.contains(i) ? 'Hide value' : 'Reveal value',
                    onPressed: () => setState(() => _revealed.contains(i) ? _revealed.remove(i) : _revealed.add(i)),
                  ),
                const SizedBox(width: AppSpacing.xs),
                AppIconButton(
                  icon: Icons.close,
                  tooltip: 'Remove',
                  onPressed: _rows.length == 1
                      ? null
                      : () {
                          setState(() => _rows.removeAt(i));
                          _emit();
                        },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RowField extends StatefulWidget {
  const _RowField({required this.hint, required this.initialValue, required this.onChanged, this.obscure = false});

  final String hint;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final bool obscure;

  @override
  State<_RowField> createState() => _RowFieldState();
}

class _RowFieldState extends State<_RowField> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.controlHeightSm + 4,
      child: TextField(
        controller: _controller,
        obscureText: widget.obscure,
        style: context.type.monoSmall.copyWith(color: context.colors.textPrimary),
        decoration: InputDecoration(hintText: widget.hint, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
        onChanged: widget.onChanged,
      ),
    );
  }
}
