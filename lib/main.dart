import 'package:flutter/material.dart';

import 'core/licensing/bundled_licenses.dart';
import 'core/performance/app_lifecycle_probe.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
export 'features/home/home_screen.dart' show FPVHomeScreen;

void main() {
  AppLifecycleProbe.start();
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledLicenses();
  if (AppLifecycleProbe.enabled) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLifecycleProbe.record('first-flutter-frame');
    });
  }
  runApp(const FPVManagerApp());
}

class FPVManagerApp extends StatelessWidget {
  const FPVManagerApp({super.key});

  static final _routeObserver = AppLifecycleRouteObserver();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FPVManager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      navigatorObservers: [if (AppLifecycleProbe.enabled) _routeObserver],
      home: const FPVHomeScreen(),
    );
  }
}
