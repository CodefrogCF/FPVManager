import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/licensing/bundled_licenses.dart';
import 'core/localization/app_localizations.dart';
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

class FPVManagerApp extends StatefulWidget {
  const FPVManagerApp({super.key});

  @override
  State<FPVManagerApp> createState() => _FPVManagerAppState();
}

class _FPVManagerAppState extends State<FPVManagerApp> {
  static final _routeObserver = AppLifecycleRouteObserver();
  AppLanguage _language = AppLanguage.german;

  void _setLanguage(AppLanguage language) {
    if (language == _language) return;
    setState(() => _language = language);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FPVManager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      locale: _language.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorObservers: [if (AppLifecycleProbe.enabled) _routeObserver],
      home: FPVHomeScreen(onLanguageChanged: _setLanguage),
    );
  }
}
