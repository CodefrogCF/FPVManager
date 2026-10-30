import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';

import '../../core/database/fpv_database.dart';
import '../../core/database/repositories/flight_plan_repository.dart';
import '../home/coordinates_dialog.dart';
import '../mobility/destination_search.dart';
import '../mobility/road_routing.dart';
import '../spots/data/spot_repository.dart';
import '../spots/spots_screen.dart';

Future<List<MobilityPoint>?> choosePlanningContext(
  BuildContext context, {
  required FpvDatabase database,
  required SpotRepository spots,
  required FlightPlanRepository flights,
  MobilityPoint? selected,
}) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Bezug wählen'),
      children: [
        if (selected != null)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'map'),
            child: const Text('Ausgewählter Kartenpunkt'),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'search'),
          child: const Text('Ort oder Koordinaten suchen'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'spot'),
          child: const Text('Gespeicherter Ort'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'flight'),
          child: const Text('Gespeicherte Flugroute'),
        ),
      ],
    ),
  );
  if (!context.mounted || choice == null) return null;
  if (choice == 'map') return [selected!];
  if (choice == 'search') {
    final destination = await showDialog<RoadDestination>(
      context: context,
      builder: (_) => const CoordinatesDialog(),
    );
    return destination == null ? null : [destination.point];
  }
  if (choice == 'spot') {
    final spot = await Navigator.push<Spot>(
      context,
      MaterialPageRoute(
        builder: (_) => SpotsScreen(repository: spots, title: 'Ort auswählen'),
      ),
    );
    return spot == null ? null : [MobilityPoint(spot.latitude, spot.longitude)];
  }
  final plans =
      await (database.select(database.flightPlans)
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(100))
          .get();
  if (!context.mounted) return null;
  final id = await showDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Flugroute auswählen · letzte 100'),
      children: [
        for (final p in plans)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, p.id),
            child: Text(p.name),
          ),
        if (plans.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Noch keine Flugrouten gespeichert'),
          ),
      ],
    ),
  );
  if (id == null) return null;
  final route = await flights.getRoute(id);
  if (route == null || route.waypoints.isEmpty) return null;
  return route.waypoints
      .map((p) => MobilityPoint(p.position.latitude, p.position.longitude))
      .toList();
}
