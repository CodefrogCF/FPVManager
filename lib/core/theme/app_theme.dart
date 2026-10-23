import 'package:flutter/material.dart';

/// Shared Material 3 appearance, using TerraManager's default green accent.
class AppTheme {
  AppTheme._();

  static const accent = Color(0xFF00A331);
  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: accent),
  );
  static final dark = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ),
  );
}
