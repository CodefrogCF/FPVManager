import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import '../../core/models/flight_route.dart';
import '../../core/geo/geo_coordinate_service.dart';
import '../airspace/airspace_check_sheet.dart';
import 'route_editor_controller.dart';
import 'waypoint_settings_sheet.dart';

enum _PointAction { settings, move, delete }

class RouteEditorToolbar extends StatelessWidget {
  const RouteEditorToolbar({
    super.key,
    required this.editor,
    required this.onAnalysis,
    required this.onFrame,
  });
  final RouteEditorController editor;
  final VoidCallback? onAnalysis, onFrame;
  String _height(WaypointHeight? h) => switch (h) {
    AglWaypointHeight() => '${h.meters.toStringAsFixed(0)} m AGL',
    AbsoluteWaypointHeight(:final elevation) =>
      '${h.meters.toStringAsFixed(0)} m ${elevation.reference.label}',
    null => 'height unknown *',
  };
  @override
  Widget build(BuildContext context) {
    final point = editor.selected;
    return SafeArea(
      top: false,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed:
                          editor.points.isEmpty ||
                              editor.saving ||
                              editor.loadFailed
                          ? null
                          : () => _points(context),
                      child: Text(
                        context.localizedWithArgs(
                          "{0} waypoints",
                          [editor.points.length],
                          (l10n, value) =>
                              l10n.routesWaypointsbc27edbc(value(0)),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.localized(
                      "Route analysis",
                      (l10n) => l10n.routesRouteAnalysise04589ed,
                    ),
                    onPressed: onAnalysis,
                    icon: const Icon(Icons.insights),
                  ),
                  IconButton(
                    tooltip: context.localized(
                      "Check route airspace",
                      (l10n) => l10n.routesCheckRouteAirspaced4d383e6,
                    ),
                    onPressed:
                        !editor.saving &&
                            !editor.loadFailed &&
                            editor.points.isNotEmpty
                        ? () => showAirspaceCheck(
                            context,
                            controller: editor.globe,
                            name: editor.name,
                            positions: [
                              for (final p in editor.points) p.position,
                            ],
                            route: true,
                          )
                        : null,
                    icon: const Icon(Icons.shield_outlined),
                  ),
                  IconButton(
                    tooltip: context.localized(
                      "Undo waypoint change",
                      (l10n) => l10n.routesUndoWaypointChange8a12e7bc,
                    ),
                    onPressed: editor.canUndo ? editor.undo : null,
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    tooltip: context.localized(
                      "Show entire route",
                      (l10n) => l10n.routesShowEntireRoute7e936417,
                    ),
                    onPressed: onFrame,
                    icon: const Icon(Icons.fit_screen),
                  ),
                ],
              ),
              if (point != null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.localizedWithArgs(
                          "Waypoint {0} · {1} · {2} m/s",
                          [
                            editor.points.indexOf(point) + 1,
                            _height(point.height),
                            point.speedMetersPerSecond?.toStringAsFixed(1) ??
                                "?",
                          ],
                          (l10n, value) => l10n.routesWaypointMS5220bb0f(
                            value(0),
                            value(1),
                            value(2),
                          ),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    PopupMenuButton<_PointAction>(
                      tooltip: context.localized(
                        "Waypoint actions",
                        (l10n) => l10n.routesWaypointActionsf5f1d082,
                      ),
                      enabled: !editor.saving && !editor.loadFailed,
                      onSelected: (action) {
                        switch (action) {
                          case _PointAction.settings:
                            showWaypointSettings(context, editor);
                          case _PointAction.move:
                            editor.toggleMove();
                          case _PointAction.delete:
                            editor.deletePoint(point.key);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: _PointAction.settings,
                          child: Text(
                            context.localized(
                              "Height & speed",
                              (l10n) => l10n.routesHeightSpeedd20ac922,
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: _PointAction.move,
                          child: Text(
                            editor.moveId == null
                                ? context.localized(
                                    "Move point",
                                    (l10n) => l10n.routesMovePoint4cfb85e2,
                                  )
                                : context.localized(
                                    "Cancel move",
                                    (l10n) => l10n.routesCancelMove23385b79,
                                  ),
                          ),
                        ),
                        PopupMenuItem(
                          value: _PointAction.delete,
                          child: Text(
                            context.localized(
                              "Delete point",
                              (l10n) => l10n.routesDeletePoint24dc6e65,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              Text(
                editor.moveId != null
                    ? context.localized(
                        "Click the new position on the map.",
                        (l10n) => l10n.routesClickTheNewPosition88166db4,
                      )
                    : editor.hasRouteWarnings
                    ? context.localized(
                        "Red segments: terrain / reserve estimates · Open analysis",
                        (l10n) => l10n.routesRedSegmentsTerrainReservefbd059b9,
                      )
                    : context.localized(
                        "Tap map to add · Select a waypoint to edit",
                        (l10n) => l10n.routesTapMapToAdddf97da9f,
                      ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (editor.points.any(
                (p) =>
                    p.height == null ||
                    (p.height is AbsoluteWaypointHeight &&
                        (p.height as AbsoluteWaypointHeight)
                                .elevation
                                .reference !=
                            VerticalReference.wgs84Ellipsoid),
              ))
                Text(
                  context.localized(
                    "* = 30 m AGL preview only",
                    (l10n) => l10n.routesMAglPreviewOnly1b6aeb60,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _points(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: FractionallySizedBox(
        heightFactor: .7,
        child: Column(
          children: [
            ListTile(
              title: Text(
                context.localized(
                  "Waypoints",
                  (l10n) => l10n.routesWaypoints8de9ac08,
                ),
              ),
              trailing: IconButton(
                tooltip: context.localized(
                  "Close",
                  (l10n) => l10n.commonClosebbfa773e,
                ),
                onPressed: () => Navigator.pop(sheetContext),
                icon: const Icon(Icons.close),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: editor.points.length,
                itemBuilder: (_, i) {
                  final p = editor.points[i];
                  final role = i == 0
                      ? 'Takeoff'
                      : i == editor.points.length - 1
                      ? 'Destination'
                      : 'Intermediate';
                  return ListTile(
                    title: Text('${i + 1} · $role'),
                    subtitle: Text(
                      '${_height(p.height)} · ${p.speedMetersPerSecond?.toStringAsFixed(1) ?? "?"} m/s',
                    ),
                    trailing: const Icon(Icons.tune),
                    onTap: () {
                      editor.select(p.key);
                      Navigator.pop(sheetContext);
                      showWaypointSettings(context, editor);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
