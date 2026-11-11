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
                        context.translate("{0} waypoints", [
                          editor.points.length,
                        ]),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.translate("Route analysis"),
                    onPressed: onAnalysis,
                    icon: const Icon(Icons.insights),
                  ),
                  IconButton(
                    tooltip: context.translate("Check route airspace"),
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
                    tooltip: context.translate("Undo waypoint change"),
                    onPressed: editor.canUndo ? editor.undo : null,
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    tooltip: context.translate("Show entire route"),
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
                        context.translate("Waypoint {0} · {1} · {2} m/s", [
                          editor.points.indexOf(point) + 1,
                          _height(point.height),
                          point.speedMetersPerSecond?.toStringAsFixed(1) ?? "?",
                        ]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    PopupMenuButton<_PointAction>(
                      tooltip: context.translate("Waypoint actions"),
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
                          child: Text(context.translate("Height & speed")),
                        ),
                        PopupMenuItem(
                          value: _PointAction.move,
                          child: Text(
                            editor.moveId == null
                                ? context.translate("Move point")
                                : context.translate("Cancel move"),
                          ),
                        ),
                        PopupMenuItem(
                          value: _PointAction.delete,
                          child: Text(context.translate("Delete point")),
                        ),
                      ],
                    ),
                  ],
                ),
              Text(
                editor.moveId != null
                    ? context.translate("Click the new position on the map.")
                    : editor.hasRouteWarnings
                    ? context.translate(
                        "Red segments: terrain / reserve estimates · Open analysis",
                      )
                    : context.translate(
                        "Tap map to add · Select a waypoint to edit",
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
                  context.translate("* = 30 m AGL preview only"),
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
              title: Text(context.translate("Waypoints")),
              trailing: IconButton(
                tooltip: context.translate("Close"),
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
