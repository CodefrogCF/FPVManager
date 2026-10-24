import 'package:flutter/widgets.dart';

/// Local overlays such as drawers are not Navigator routes. Their host can
/// suspend iframe input without recreating the globe or its renderer session.
class GlobeInputScope extends InheritedWidget {
  const GlobeInputScope({
    super.key,
    required this.enabled,
    required super.child,
  });

  final bool enabled;

  static bool enabledOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlobeInputScope>()?.enabled ??
      true;

  @override
  bool updateShouldNotify(GlobeInputScope oldWidget) =>
      enabled != oldWidget.enabled;
}
