import 'package:flutter/material.dart';

/// A consistent button widget used throughout the app
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final button = _buildButton(context);

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }

  Widget _buildButton(BuildContext context) {
    final buttonStyle = _getButtonStyle(context);
    final textStyle = _getTextStyle(context);
    final padding = _getPadding();
    final height = _getHeight();

    if (variant == AppButtonVariant.text) {
      return TextButton(onPressed: isLoading ? null : onPressed, style: buttonStyle, child: _buildContent(context, textStyle, padding, height));
    } else if (variant == AppButtonVariant.outlined) {
      return OutlinedButton(onPressed: isLoading ? null : onPressed, style: buttonStyle, child: _buildContent(context, textStyle, padding, height));
    } else {
      return ElevatedButton(onPressed: isLoading ? null : onPressed, style: buttonStyle, child: _buildContent(context, textStyle, padding, height));
    }
  }

  Widget _buildContent(BuildContext context, TextStyle? textStyle, EdgeInsetsGeometry padding, double? height) {
    if (isLoading) {
      return SizedBox(
        height: height,
        child: Padding(
          padding: padding,
          child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    final contentColor = _getContentColor(context);
    final resolvedTextStyle = (textStyle ?? Theme.of(context).textTheme.labelLarge)?.copyWith(color: contentColor);

    final children = <Widget>[];
    if (icon != null) {
      children.add(Icon(icon, size: _getIconSize(), color: contentColor));
      children.add(const SizedBox(width: 8));
    }
    children.add(Text(label, style: resolvedTextStyle));

    return Padding(
      padding: padding,
      child: height != null
          ? SizedBox(
              height: height,
              child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: children),
            )
          : Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: children),
    );
  }

  ButtonStyle _getButtonStyle(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    switch (variant) {
      case AppButtonVariant.primary:
        return ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary);
      case AppButtonVariant.secondary:
        return ElevatedButton.styleFrom(backgroundColor: colorScheme.secondary, foregroundColor: colorScheme.onSecondary);
      case AppButtonVariant.danger:
        return ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white);
      case AppButtonVariant.outlined:
        return OutlinedButton.styleFrom(foregroundColor: colorScheme.primary);
      case AppButtonVariant.text:
        return TextButton.styleFrom(foregroundColor: colorScheme.primary);
    }
  }

  TextStyle? _getTextStyle(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    switch (size) {
      case AppButtonSize.small:
        return textTheme.labelMedium;
      case AppButtonSize.medium:
        return textTheme.labelLarge;
      case AppButtonSize.large:
        return textTheme.titleMedium;
    }
  }

  Color _getContentColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (variant) {
      case AppButtonVariant.primary:
        return colorScheme.onPrimary;
      case AppButtonVariant.secondary:
        return colorScheme.onSecondary;
      case AppButtonVariant.danger:
        return Colors.white;
      case AppButtonVariant.outlined:
      case AppButtonVariant.text:
        return colorScheme.primary;
    }
  }

  EdgeInsetsGeometry _getPadding() {
    switch (size) {
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
      case AppButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 14);
    }
  }

  double? _getHeight() {
    switch (size) {
      case AppButtonSize.small:
        return 28;
      case AppButtonSize.medium:
        return 34;
      case AppButtonSize.large:
        return 42;
    }
  }

  double _getIconSize() {
    switch (size) {
      case AppButtonSize.small:
        return 16;
      case AppButtonSize.medium:
        return 18;
      case AppButtonSize.large:
        return 20;
    }
  }
}

enum AppButtonVariant { primary, secondary, danger, outlined, text }

enum AppButtonSize { small, medium, large }
