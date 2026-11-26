import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

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
    this.diagnosticOverlay,
    this.captureMode = false,
    this.onExitCapture,
  });
  final Widget globe, navigation, actions, selection;
  final Widget? sidePanel, diagnosticOverlay;
  final bool captureMode;
  final VoidCallback? onExitCapture;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth > constraints.maxHeight ||
          constraints.maxWidth >= 840;
      return Stack(
        children: [
          Positioned.fill(child: globe),
          if (!captureMode)
            Positioned(
              top: 8,
              left: 8,
              child: MapFloatingSurface(intercept: true, child: navigation),
            ),
          if (!captureMode)
            Positioned(
              top: 8,
              right: 8,
              child: MapFloatingSurface(intercept: true, child: actions),
            ),
          if (!captureMode)
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
          if (!captureMode && diagnosticOverlay != null)
            Positioned(
              top: 120,
              left: 8,
              child: IgnorePointer(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: math.min(
                      310.0,
                      math.max(0.0, constraints.maxWidth - 16),
                    ),
                    maxHeight: math.max(0.0, constraints.maxHeight - 155),
                  ),
                  child: diagnosticOverlay!,
                ),
              ),
            ),
          // An invisible 64px top-left hotspot keeps the view truly clean.
          // Keyboard/controller input remains with Cesium; tap restores UI.
          if (captureMode && onExitCapture != null)
            Positioned(
              top: 0,
              left: 0,
              child: PointerInterceptor(
                intercepting: true,
                child: Semantics(
                  label: 'Restore simulation controls',
                  button: true,
                  child: GestureDetector(
                    key: const ValueKey('capture-mode-restore-hotspot'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onExitCapture,
                    child: const SizedBox(width: 64, height: 64),
                  ),
                ),
              ),
            ),
          if (!captureMode && sidePanel != null)
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
