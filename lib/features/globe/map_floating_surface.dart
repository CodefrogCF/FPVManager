import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import 'desktop_globe_interaction_mode.dart';

/// Bounded, readable map chrome. No blur pass over the continuously drawn globe.
class MapFloatingSurface extends StatelessWidget {
  const MapFloatingSurface({
    super.key,
    required this.child,
    this.intercept = false,
  });
  final Widget child;
  final bool intercept;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // The painted area is an interactive boundary even between buttons.
    // Outside the widget's laid-out rectangle no hit target is installed.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {},
      child: PointerInterceptor(
        intercepting: intercept,
        child: Material(
          color: colors.surface.withValues(
            alpha: colors.brightness == Brightness.dark ? .86 : .9,
          ),
          surfaceTintColor: Colors.transparent,
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: .2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: colors.outlineVariant.withValues(alpha: .6),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }
}

/// Short screens use a side panel, leaving the centre of the map visible.
Future<T?> showMapPanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  // Override only in tests; desktop Windows uses non-modal map panels.
  bool? nonModal,
}) {
  final media = MediaQuery.of(context);
  final useNonModal = nonModal ?? desktopGlobeInteractionEnabled;
  if (useNonModal) {
    return Navigator.of(context, rootNavigator: true).push<T>(
      _WindowsMapPanelRoute<T>(
        duration: media.disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 180),
        builder: builder,
      ),
    );
  }
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: .18),
    transitionDuration: media.disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _mapPanelLayout(context, builder),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// A non-opaque route without a full-window modal barrier.  Unlike
/// `showGeneralDialog`, it leaves pointer events outside the bounded panel
/// available to the Windows WebView2 texture.  Navigator.pop(context) inside
/// existing sheet widgets continues to work normally.
class _WindowsMapPanelRoute<T> extends PageRouteBuilder<T> {
  _WindowsMapPanelRoute({
    required Duration duration,
    required WidgetBuilder builder,
  }) : super(
         opaque: false,
         requestFocus: false,
         transitionDuration: duration,
         reverseTransitionDuration: duration,
         pageBuilder: (context, animation, secondaryAnimation) =>
             _mapPanelLayout(context, builder, desktop: true),
         transitionsBuilder: (context, animation, secondaryAnimation, child) =>
             FadeTransition(opacity: animation, child: child),
       );

  @override
  Widget buildModalBarrier() => const SizedBox.shrink();
}

Widget _mapPanelLayout(
  BuildContext context,
  WidgetBuilder builder, {
  bool desktop = false,
}) {
  final constraints = MediaQuery.sizeOf(context);
  final side =
      desktop ||
      constraints.width >= 840 ||
      (constraints.width > constraints.height && constraints.height < 600);
  final insets = MediaQuery.viewInsetsOf(context);
  return SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + insets.bottom),
      child: Align(
        alignment: side ? Alignment.centerRight : Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: side ? 1 : .84,
          child: SizedBox(
            key: const ValueKey('floating-map-panel'),
            width: desktop
                ? (constraints.width - 72.0)
                      .clamp(0.0, constraints.width < 900 ? 360.0 : 390.0)
                      .toDouble()
                : side
                ? (constraints.width < 900 ? 360.0 : 390.0)
                : 560.0,
            child: MapFloatingSurface(child: builder(context)),
          ),
        ),
      ),
    ),
  );
}
