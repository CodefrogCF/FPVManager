import 'package:flutter/material.dart';

import '../../core/database/fpv_database.dart';
import '../../core/database/repositories/flight_plan_repository.dart';
import 'route_editor_screen.dart';
import '../../core/database/repositories/user_preferences_repository.dart';
import '../obstacles/swiss_obstacle_provider.dart';
import '../../core/osint/osint_provider.dart';

class FlightRoutesScreen extends StatefulWidget {
  const FlightRoutesScreen({
    super.key,
    required this.repository,
    this.obstacleProvider,
    this.uasProvider,
    this.preferencesRepository,
  });
  final FlightPlanRepository repository;
  final SwissObstacleProvider? obstacleProvider;
  final OsintProvider<Map<String, dynamic>>? uasProvider;
  final UserPreferencesRepository? preferencesRepository;
  @override
  State<FlightRoutesScreen> createState() => _FlightRoutesScreenState();
}

class _FlightRoutesScreenState extends State<FlightRoutesScreen> {
  late Stream<List<FlightPlan>> _routes = widget.repository.watchFlightPlans();
  Future<void> _open([int? id]) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => RouteEditorScreen(
        repository: widget.repository,
        routeId: id,
        obstacleProvider: widget.obstacleProvider,
        uasProvider: widget.uasProvider,
        preferencesRepository: widget.preferencesRepository,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Flight routes')),
    body: StreamBuilder<List<FlightPlan>>(
      stream: _routes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load saved routes.'),
                TextButton(
                  onPressed: () => setState(
                    () => _routes = widget.repository.watchFlightPlans(),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No saved flight routes yet. Create a route and place waypoints on the map.',
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final route = snapshot.data![index];
            return ListTile(
              leading: const Icon(Icons.route_outlined),
              title: Text(route.name),
              subtitle: const Text('Stored on this device'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(route.id),
            );
          },
        );
      },
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _open,
      icon: const Icon(Icons.add),
      label: const Text('New route'),
    ),
  );
}
