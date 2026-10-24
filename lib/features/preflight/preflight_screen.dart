import 'package:flutter/material.dart';

import '../../core/database/fpv_database.dart';
import '../telemetry/telemetry_repository.dart';
import '../telemetry/telemetry_tab.dart';
import 'checklists_tab.dart';
import 'preflight_repository.dart';

class PreflightScreen extends StatelessWidget {
  const PreflightScreen({super.key, required this.database});
  final FpvDatabase database;
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Preflight & Telemetry'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Checklists'),
            Tab(text: 'Telemetry'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          ChecklistsTab(repository: PreflightRepository(database)),
          TelemetryTab(repository: TelemetryRepository(database)),
        ],
      ),
    ),
  );
}
