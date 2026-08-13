import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import 'app_button.dart';

class KeyValueRow {
  KeyValueRow({required this.key, required this.value, this.enabled = true});

  String key;
  String value;
  bool enabled;
}

/// An editable key/value table (headers, query params, form fields) with a
/// trailing empty row that grows the list as soon as you type into it.
class KeyValueEditor extends StatefulWidget {
  const KeyValueEditor({super.key, required this.initial, required this.onChanged, this.keyHint = 'Key', this.valueHint = 'Value'});

  final Map<String, String> initial;
  final ValueChanged<Map<String, String>> onChanged;
  final String keyHint;
  final String valueHint;

  @override
  State<KeyValueEditor> createState() => _KeyValueEditorState();
}

class _KeyValueEditorState extends State<KeyValueEditor> {
  final List<KeyValueRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _rows.addAll(widget.initial.entries.map((e) => KeyValueRow(key: e.key, value: e.value)));
    _ensureTrailingRow();
  }

  void _emit() {
    final map = <String, String>{};
    for (final row in _rows) {
      if (row.enabled && row.key.isNotEmpty) map[row.key] = row.value;
    }
    widget.onChanged(map);
  }

  void _ensureTrailingRow() {
    if (_rows.isEmpty || _rows.last.key.isNotEmpty || _rows.last.value.isNotEmpty) {
      _rows.add(KeyValueRow(key: '', value: ''));
    }
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
                  onChanged: (v) {
                    setState(() => _rows[i].enabled = v ?? true);
                    _emit();
                  },
                ),
                Expanded(
                  child: _RowField(
                    hint: widget.keyHint,
                    initialValue: _rows[i].key,
                    onChanged: (v) {
                      setState(() {
                        _rows[i].key = v;
                        _ensureTrailingRow();
                      });
                      _emit();
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _RowField(
                    hint: widget.valueHint,
                    initialValue: _rows[i].value,
                    onChanged: (v) {
                      setState(() {
                        _rows[i].value = v;
                        _ensureTrailingRow();
                      });
                      _emit();
                    },
                  ),
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
  const _RowField({required this.hint, required this.initialValue, required this.onChanged});

  final String hint;
  final String initialValue;
  final ValueChanged<String> onChanged;

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
        style: context.type.monoSmall.copyWith(color: context.colors.textPrimary),
        decoration: InputDecoration(hintText: widget.hint, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
        onChanged: widget.onChanged,
      ),
    );
  }
}
