import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
export 'features/home/home_screen.dart' show FPVHomeScreen;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FPVManagerApp());
}

class FPVManagerApp extends StatelessWidget {
  const FPVManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FPVManager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const FPVHomeScreen(),
    );
  }
}
