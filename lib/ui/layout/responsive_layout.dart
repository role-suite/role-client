import 'package:flutter/material.dart';

class AppBreakpoints {
  static const double mobile = 0;      // implicit
  static const double tablet = 600;
  static const double desktop = 1024;
}

/// A responsive builder that picks a widget based on screen width.
///
/// Usage:
/// ```dart
/// return ResponsiveLayout(
///   mobile: (_) => const MobileHomeView(),
///   tablet: (_) => const TabletHomeView(),
///   desktop: (_) => const DesktopHomeView(),
/// );
/// ```
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    WidgetBuilder? tablet,
    WidgetBuilder? desktop,
  })  : tablet = tablet ?? mobile,
        desktop = desktop ?? tablet ?? mobile;

  final WidgetBuilder mobile;
  final WidgetBuilder tablet;
  final WidgetBuilder desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width >= AppBreakpoints.desktop) {
          return desktop(context);
        } else if (width >= AppBreakpoints.tablet) {
          return tablet(context);
        } else {
          return mobile(context);
        }
      },
    );
  }
}
