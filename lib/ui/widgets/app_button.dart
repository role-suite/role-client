import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/role_theme.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.secondary,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disabled = onPressed == null;

    Color bg;
    Color fg;
    Color? border;
    switch (variant) {
      case AppButtonVariant.primary:
        bg = colors.accent;
        fg = colors.onAccent;
        border = null;
      case AppButtonVariant.secondary:
        bg = colors.surfaceRaised;
        fg = colors.textPrimary;
        border = colors.border;
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = colors.textSecondary;
        border = null;
      case AppButtonVariant.danger:
        bg = colors.danger;
        fg = colors.onAccent;
        border = null;
    }

    if (disabled) {
      fg = colors.textMuted;
      bg = variant == AppButtonVariant.ghost ? bg : colors.surfaceSunken;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.smRadius,
        child: Container(
          height: dense ? AppSizes.controlHeightSm : AppSizes.controlHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(color: bg, borderRadius: AppRadius.smRadius, border: border != null ? Border.all(color: border) : null),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: AppSpacing.xs)],
              Text(label, style: context.type.bodyStrong.copyWith(color: fg, fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({super.key, required this.icon, this.onPressed, this.tooltip, this.size = 14, this.active = false});

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final button = Material(
      color: active ? colors.surfaceRaised : Colors.transparent,
      borderRadius: AppRadius.smRadius,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.smRadius,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: size, color: onPressed == null ? colors.textMuted : colors.textSecondary),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: button) : button;
  }
}
