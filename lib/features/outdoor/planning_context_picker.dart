import 'package:drift/drift.dart' show OrderingTerm;

import '../../core/localization/app_localizations.dart';

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
      title: Text(
        context.localized(
          "Bezug wählen",
          (l10n) => l10n.outdoorBezugWaehlendcf73635,
        ),
      ),
      children: [
        if (selected != null)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'map'),
            child: Text(
              context.localized(
                "Ausgewählter Kartenpunkt",
                (l10n) => l10n.outdoorAusgewaehlterKartenpunktd902892e,
              ),
            ),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'search'),
          child: Text(
            context.localized(
              "Ort oder Koordinaten suchen",
              (l10n) => l10n.commonOrtOderKoordinatenSuchen6904cb89,
            ),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'spot'),
          child: Text(
            context.localized(
              "Gespeicherter Ort",
              (l10n) => l10n.outdoorGespeicherterOrt25ce06f0,
            ),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'flight'),
          child: Text(
            context.localized(
              "Gespeicherte Flugroute",
              (l10n) => l10n.outdoorGespeicherteFlugroutede6dec82,
            ),
          ),
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
      title: Text(
        context.localized(
          "Flugroute auswählen · letzte 100",
          (l10n) => l10n.outdoorFlugrouteAuswaehlenLetzteeb04100f,
        ),
      ),
      children: [
        for (final p in plans)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, p.id),
            child: Text(p.name),
          ),
        if (plans.isEmpty)
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              context.localized(
                "Noch keine Flugrouten gespeichert",
                (l10n) => l10n.outdoorNochKeineFlugroutenGespeichertc7aeb7bc,
              ),
            ),
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
