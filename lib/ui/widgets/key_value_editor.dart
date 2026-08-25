import 'package:flutter/material.dart';

import '../../core/models/key_value_entry.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import 'app_button.dart';

/// An editable key/value table (headers, query params, url-encoded fields)
/// with a trailing empty row that grows the list as soon as you type into
/// it. Rows are emitted in order, including disabled and duplicate-key rows
/// — the whole point of [KeyValueEntry] over a `Map<String, String>`.
class KeyValueEditor extends StatefulWidget {
  const KeyValueEditor({
    super.key,
    required this.initial,
    required this.onChanged,
    this.keyHint = 'Key',
    this.valueHint = 'Value',
    this.enabled = true,
  });

  final List<KeyValueEntry> initial;
  final ValueChanged<List<KeyValueEntry>> onChanged;
  final String keyHint;
  final String valueHint;
  final bool enabled;

  @override
  State<KeyValueEditor> createState() => _KeyValueEditorState();
}

class _KeyValueEditorState extends State<KeyValueEditor> {
  final List<KeyValueEntry> _rows = [];

  @override
  void initState() {
    super.initState();
    _rows.addAll(widget.initial);
    _ensureTrailingRow();
  }

  void _emit() {
    widget.onChanged(_rows.where((r) => r.key.isNotEmpty).toList());
  }

  void _ensureTrailingRow() {
    if (_rows.isEmpty || _rows.last.key.isNotEmpty || _rows.last.value.isNotEmpty) {
      _rows.add(const KeyValueEntry(key: '', value: ''));
    }
  }

  void _updateRow(int index, KeyValueEntry next) {
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
                  onChanged: widget.enabled ? (v) => _updateRow(i, _rows[i].copyWith(enabled: v ?? true)) : null,
                ),
                Expanded(
                  child: _RowField(
                    hint: widget.keyHint,
                    initialValue: _rows[i].key,
                    enabled: widget.enabled,
                    onChanged: (v) => _updateRow(i, _rows[i].copyWith(key: v)),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _RowField(
                    hint: widget.valueHint,
                    initialValue: _rows[i].value,
                    enabled: widget.enabled,
                    onChanged: (v) => _updateRow(i, _rows[i].copyWith(value: v)),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                AppIconButton(
                  icon: Icons.close,
                  tooltip: 'Remove',
                  onPressed: !widget.enabled || _rows.length == 1
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
  const _RowField({required this.hint, required this.initialValue, required this.onChanged, required this.enabled});

  final String hint;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final bool enabled;

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
        enabled: widget.enabled,
        style: context.type.monoSmall.copyWith(color: context.colors.textPrimary),
        decoration: InputDecoration(hintText: widget.hint, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
        onChanged: widget.onChanged,
      ),
    );
  }
}
