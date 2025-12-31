import 'package:flutter/material.dart';

/// A clean, reusable app-wide AppBar.
///
/// Example:
/// ```dart
/// return AppAppBar(
///   title: 'Home',
///   actions: [IconButton(icon: Icon(Icons.search), onPressed: () {})],
/// );
/// ```
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppAppBar({super.key, this.title, this.centerTitle = true, this.actions, this.leading, this.elevation = 0, this.backgroundColor});

  final String? title;
  final bool centerTitle;
  final List<Widget>? actions;
  final Widget? leading;
  final double elevation;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title != null ? Text(title!) : null,
      centerTitle: centerTitle,
      actions: actions,
      elevation: elevation,
      leading: leading,
      backgroundColor: backgroundColor,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
