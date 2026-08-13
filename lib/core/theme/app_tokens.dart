import 'package:flutter/widgets.dart';

/// Spacing, radius, and sizing tokens for a dense, tool-grade UI —
/// deliberately smaller than Material defaults.
abstract class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract class AppRadius {
  static const sm = 3.0;
  static const md = 4.0;
  static const lg = 6.0;

  static final smRadius = BorderRadius.circular(sm);
  static final mdRadius = BorderRadius.circular(md);
  static final lgRadius = BorderRadius.circular(lg);
}

abstract class AppSizes {
  static const controlHeight = 30.0;
  static const controlHeightSm = 24.0;
  static const iconRailWidth = 48.0;
  static const sidebarWidthDefault = 260.0;
  static const sidebarWidthMin = 200.0;
  static const sidebarWidthMax = 420.0;
  static const inspectorWidth = 280.0;
  static const topBarHeight = 44.0;
  static const tabStripHeight = 34.0;
  static const statusBarHeight = 26.0;
  static const borderWidth = 1.0;
}
