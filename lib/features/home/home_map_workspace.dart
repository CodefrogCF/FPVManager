import 'package:flutter/material.dart';

import 'dart:math' as math;

import '../globe/map_floating_surface.dart';

/// Keeps one globe mounted across selections, rotation and opened tools.
class HomeMapWorkspace extends StatelessWidget {
  const HomeMapWorkspace({
    super.key,
    required this.globe,
    required this.navigation,
    required this.actions,
    required this.selection,
    this.sidePanel,
  });
  final Widget globe, navigation, actions, selection;
  final Widget? sidePanel;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth > constraints.maxHeight ||
          constraints.maxWidth >= 840;
      return Stack(
        children: [
          Positioned.fill(child: globe),
          Positioned(
            top: 8,
            left: 8,
            child: MapFloatingSurface(intercept: true, child: navigation),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: MapFloatingSurface(intercept: true, child: actions),
          ),
          Positioned(
            left: wide ? null : 8,
            right: 8,
            bottom: 52,
            width: wide ? 360 : null,
            child: ConstrainedBox(
              key: const ValueKey('map-selection-overlay'),
              constraints: BoxConstraints(
                maxHeight: wide
                    ? math.max(
                        0,
                        math.min(
                          constraints.maxHeight * .66,
                          constraints.maxHeight - 180,
                        ),
                      )
                    : constraints.maxHeight * .46,
              ),
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                removeBottom: true,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    cardTheme: const CardThemeData(
                      color: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      elevation: 0,
                      margin: EdgeInsets.zero,
                    ),
                  ),
                  child: selection,
                ),
              ),
            ),
          ),
          if (sidePanel != null)
            Positioned(
              top: 8,
              bottom: 8,
              left: 8,
              width: math.max(
                0.0,
                math.min(320.0, constraints.maxWidth - 72.0),
              ),
              child: KeyedSubtree(
                key: const ValueKey('desktop-navigation-panel'),
                child: sidePanel!,
              ),
            ),
        ],
      );
    },
  );
}
