import 'package:flutter/widgets.dart';

abstract class Breakpoints {
  static const desktop = 900.0;
}

bool isDesktop(BuildContext context) => MediaQuery.sizeOf(context).width >= Breakpoints.desktop;
