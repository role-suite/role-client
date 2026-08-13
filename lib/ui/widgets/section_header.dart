import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.sm, AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label.toUpperCase(), style: context.type.sectionHeader)),
          ?trailing,
        ],
      ),
    );
  }
}
