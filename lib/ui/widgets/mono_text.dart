import 'package:flutter/material.dart';

import '../../core/theme/role_theme.dart';

class MonoText extends StatelessWidget {
  const MonoText(this.text, {super.key, this.style, this.small = false});

  final String text;
  final TextStyle? style;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final base = small ? context.type.monoSmall : context.type.mono;
    return SelectableText(text, style: base.merge(style));
  }
}
