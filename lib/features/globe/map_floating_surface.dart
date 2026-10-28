import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

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
    return PointerInterceptor(
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
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: .6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// Short screens use a side panel, leaving the centre of the map visible.
Future<T?> showMapPanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final media = MediaQuery.of(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: .18),
    transitionDuration: media.disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) => LayoutBuilder(
      builder: (context, constraints) {
        final side =
            constraints.maxWidth >= 840 ||
            constraints.maxWidth > constraints.maxHeight &&
                constraints.maxHeight < 600;
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
                  width: side ? (constraints.maxWidth < 900 ? 360 : 390) : 560,
                  child: MapFloatingSurface(child: builder(context)),
                ),
              ),
            ),
          ),
        );
      },
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}
