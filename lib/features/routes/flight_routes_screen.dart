import 'package:flutter/material.dart';

import '../../core/database/fpv_database.dart';
import '../../core/database/repositories/flight_plan_repository.dart';
import 'route_editor_screen.dart';
import '../../core/database/repositories/user_preferences_repository.dart';
import '../obstacles/swiss_obstacle_provider.dart';
import '../../core/osint/osint_provider.dart';
import '../../core/models/route_transfer.dart';
import '../../core/models/flight_route.dart';
import '../../core/models/route_planning_settings.dart';
import '../../core/models/recorded_route_track.dart';
import 'transfer/route_file_service.dart';
import '../spots/data/spot_repository.dart';

String _recordingSummary(RecordedRouteTrack track) {
  final speed = track.samples
      .map((s) => s.groundSpeedMetersPerSecond)
      .whereType<double>();
  final knownAgl = track.samples.where((s) => s.aglMeters != null).length;
  final speedText = speed.isEmpty
      ? 'speed unknown'
      : '${speed.reduce((a, b) => a < b ? a : b).toStringAsFixed(1)}–'
            '${speed.reduce((a, b) => a > b ? a : b).toStringAsFixed(1)} m/s (3D ground speed)';
  return 'Simulated recording · ${track.samples.length} timed samples · '
      'AGL $knownAgl/${track.samples.length} available · $speedText · '
      '${track.startedAtUtc.toLocal().toString().substring(0, 16)}';
}

class FlightRoutesScreen extends StatefulWidget {
  const FlightRoutesScreen({
    super.key,
    required this.repository,
    this.obstacleProvider,
    this.uasProvider,
    this.preferencesRepository,
    this.routeFiles = const RouteFileService(),
    this.spots,
    this.cachedMaps = false,
  });
  final FlightPlanRepository repository;
  final SwissObstacleProvider? obstacleProvider;
  final OsintProvider<Map<String, dynamic>>? uasProvider;
  final UserPreferencesRepository? preferencesRepository;
  final RouteFileService routeFiles;
  final SpotRepository? spots;
  final bool cachedMaps;
  @override
  State<FlightRoutesScreen> createState() => _FlightRoutesScreenState();
}

class _FlightRoutesScreenState extends State<FlightRoutesScreen> {
  bool _transferring = false;
  bool _working = false;

  Future<void> _import() async {
    if (_transferring) return;
    setState(() {
      _transferring = true;
      _working = true;
    });
    try {
      final preview = await widget.routeFiles.pickRoutes();
      if (!mounted || preview == null) return;
      setState(() => _working = false);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Import ${preview.routes.length} routes?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New local copies are created. Existing routes and equipment assignments are preserved.',
                ),
                for (final route in preview.routes)
                  Text('${route.name} · ${route.points.length} waypoints'),
                for (final warning in preview.warnings)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(warning),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Review coordinates and height references before planning a flight.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Import locally'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => _working = true);
      final ids = await widget.repository.importRoutes(preview.routes);
      if (mounted) _message('${ids.length} routes imported locally');
    } catch (error) {
      if (mounted) {
        _message(
          error is FormatException
              ? error.message
              : 'Unable to import routes. No routes were replaced.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _transferring = false;
          _working = false;
        });
      }
    }
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
  Future<void> _export(int id, RouteFileFormat format) async {
    if (_transferring) return;
    setState(() {
      _transferring = true;
      _working = true;
    });
    try {
      final route = await widget.repository.getRoute(id);
      if (!mounted) return;
      if (route == null) throw StateError('Route no longer exists');
      final done = await widget.routeFiles.exportRoute(
        ImportedRoute(route.plan.name, [
          for (final p in route.waypoints)
            RouteWaypointInput(
              position: p.position,
              height: p.height,
              speedMetersPerSecond: p.speedMetersPerSecond,
            ),
        ], recordedTrack: route.recordedTrack),
        format,
      );
      if (mounted && done) {
        _message('Route export handed to your selected destination');
      }
    } catch (error) {
      if (mounted) {
        _message(
          error is FormatException
              ? error.message
              : 'Unable to export this route. Please retry.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _transferring = false;
          _working = false;
        });
      }
    }
  }

  late Stream<List<FlightPlan>> _routes = widget.repository.watchFlightPlans();
  Future<void> _open([int? id]) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => RouteEditorScreen(
        repository: widget.repository,
        spots: widget.spots,
        cachedMaps: widget.cachedMaps,
        routeId: id,
        obstacleProvider: widget.obstacleProvider,
        uasProvider: widget.uasProvider,
        preferencesRepository: widget.preferencesRepository,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Flight routes'),
      actions: [
        IconButton(
          tooltip: 'Import routes',
          onPressed: _transferring ? null : _import,
          icon: const Icon(Icons.file_upload_outlined),
        ),
      ],
      bottom: _working
          ? const PreferredSize(
              preferredSize: Size.fromHeight(3),
              child: LinearProgressIndicator(),
            )
          : null,
    ),
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
            final recorded = RoutePlanningSettings.decode(route.planningJson)
                .recordedTrack;
            return ListTile(
              leading: const Icon(Icons.route_outlined),
              title: Text(route.name),
              subtitle: Text(
                recorded == null
                    ? 'Stored on this device'
                    : _recordingSummary(recorded),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Simulate flight: ${route.name}',
                    icon: const Icon(Icons.play_circle_outline),
                    onPressed: _transferring
                        ? null
                        : () => Navigator.of(context).pop(route.id),
                  ),
                  PopupMenuButton<RouteFileFormat>(
                    tooltip: 'Export ${route.name}',
                    enabled: !_transferring,
                    onSelected: (format) => _export(route.id, format),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: RouteFileFormat.geoJson,
                        child: Text('Export GeoJSON'),
                      ),
                      PopupMenuItem(
                        value: RouteFileFormat.gpx,
                        child: Text('Export GPX'),
                      ),
                    ],
                  ),
                ],
              ),
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
