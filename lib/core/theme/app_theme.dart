import 'package:flutter/material.dart';

/// Shared Material 3 appearance, using TerraManager's default green accent.
class AppTheme {
  AppTheme._();

  static const accent = Color(0xFF00A331);
  // WebView2 is an external GPU texture. Windows' default zoom transition
  // snapshots the outgoing page using an offscreen raster context; that can
  // crash Flutter while resolving the live WebView texture. Animate the live
  // page instead, including when returning from a full-screen tool.
  static final _pageTransitions = PageTransitionsTheme(
    builders: {
      ...const PageTransitionsTheme().builders,
      TargetPlatform.windows: const ZoomPageTransitionsBuilder(
        allowSnapshotting: false,
      ),
    },
  );
  static final light = ThemeData(
    useMaterial3: true,
    pageTransitionsTheme: _pageTransitions,
    colorScheme: ColorScheme.fromSeed(seedColor: accent),
  );
  static final dark = ThemeData(
    useMaterial3: true,
    pageTransitionsTheme: _pageTransitions,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ),
  );
}
