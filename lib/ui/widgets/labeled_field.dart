import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';

class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.type.label),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}

/// A dense, theme-matching dropdown.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({super.key, required this.value, required this.items, required this.itemLabel, required this.onChanged});

  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: AppSizes.controlHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(color: colors.surfaceSunken, borderRadius: AppRadius.smRadius, border: Border.all(color: colors.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          icon: Icon(Icons.expand_more, size: 16, color: colors.textMuted),
          dropdownColor: colors.surfaceRaised,
          style: context.type.body,
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(itemLabel(item)))).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
