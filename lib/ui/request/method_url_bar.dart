import 'package:flutter/material.dart';

import '../../core/models/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';
import '../widgets/widgets.dart';

class MethodUrlBar extends StatelessWidget {
  const MethodUrlBar({
    super.key,
    required this.method,
    required this.url,
    required this.onMethodChanged,
    required this.onUrlChanged,
    required this.onSend,
    this.sending = false,
  });

  final HttpMethod method;
  final String url;
  final ValueChanged<HttpMethod> onMethodChanged;
  final ValueChanged<String> onUrlChanged;
  final VoidCallback? onSend;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            height: AppSizes.controlHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(color: colors.surfaceSunken, borderRadius: AppRadius.smRadius, border: Border.all(color: colors.border)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<HttpMethod>(
                value: method,
                isDense: true,
                icon: Icon(Icons.expand_more, size: 16, color: colors.textMuted),
                dropdownColor: colors.surfaceRaised,
                items: HttpMethod.values
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(
                          m.label,
                          style: context.type.monoStrong.copyWith(color: AppColors.methodColor(m, dark: isDark), fontSize: 12.5),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (m) {
                  if (m != null) onMethodChanged(m);
                },
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SizedBox(
              height: AppSizes.controlHeight,
              child: TextFormField(
                initialValue: url,
                style: context.type.mono.copyWith(fontSize: 13),
                decoration: const InputDecoration(hintText: 'https://api.example.com/{{path}}', isDense: true),
                onChanged: onUrlChanged,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton(
            label: sending ? 'Sending…' : 'Send',
            icon: sending ? null : Icons.send,
            variant: AppButtonVariant.primary,
            onPressed: sending ? null : onSend,
          ),
        ],
      ),
    );
  }
}
