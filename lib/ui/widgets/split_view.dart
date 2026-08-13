import 'package:flutter/material.dart';

import '../../core/theme/role_theme.dart';

/// A vertically-stacked pane pair with a draggable divider between them —
/// used for the request/response split in a request tab.
class SplitView extends StatefulWidget {
  const SplitView({super.key, required this.top, required this.bottom, this.initialTopFraction = 0.45, this.minFraction = 0.15});

  final Widget top;
  final Widget bottom;
  final double initialTopFraction;
  final double minFraction;

  @override
  State<SplitView> createState() => _SplitViewState();
}

class _SplitViewState extends State<SplitView> {
  late double _topFraction = widget.initialTopFraction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final topHeight = constraints.maxHeight * _topFraction;
        return Column(
          children: [
            SizedBox(height: topHeight, child: widget.top),
            MouseRegion(
              cursor: SystemMouseCursors.resizeUpDown,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: (details) {
                  setState(() {
                    final next = _topFraction + details.delta.dy / constraints.maxHeight;
                    _topFraction = next.clamp(widget.minFraction, 1 - widget.minFraction);
                  });
                },
                child: Container(
                  height: 6,
                  alignment: Alignment.center,
                  color: Colors.transparent,
                  child: Container(height: 1, color: colors.border),
                ),
              ),
            ),
            Expanded(child: widget.bottom),
          ],
        );
      },
    );
  }
}
