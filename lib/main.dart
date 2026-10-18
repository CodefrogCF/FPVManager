import 'package:flutter/material.dart';

import 'features/globe/globe_view.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101820),
      ),
      home: const FPVHomeScreen(),
    );
  }
}

class FPVHomeScreen extends StatelessWidget {
  const FPVHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FPVManager',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF101820),
      ),
      body: const GlobeView(),
    );
  }
}
