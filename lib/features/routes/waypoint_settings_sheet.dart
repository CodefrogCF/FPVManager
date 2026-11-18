import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import '../../core/geo/altitude_service.dart';
import '../../core/geo/geo_coordinate_service.dart';
import '../../core/models/flight_route.dart';
import 'route_editor_controller.dart';

Future<void> showWaypointSettings(
  BuildContext context,
  RouteEditorController editor,
) async {
  final point = editor.selected;
  if (point == null) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _WaypointSettings(editor: editor, point: point),
  );
}

class _WaypointSettings extends StatefulWidget {
  const _WaypointSettings({required this.editor, required this.point});
  final RouteEditorController editor;
  final EditableWaypoint point;
  @override
  State<_WaypointSettings> createState() => _WaypointSettingsState();
}

class _WaypointSettingsState extends State<_WaypointSettings> {
  bool _applyAll = false;
  final _form = GlobalKey<FormState>();
  late String _mode = switch (widget.point.height) {
    AglWaypointHeight() => 'agl',
    AbsoluteWaypointHeight(:final elevation) => elevation.reference.name,
    null => 'none',
  };
  late final _height = TextEditingController(
    text: widget.point.height?.meters.toString() ?? '',
  );
  late final _speed = TextEditingController(
    text: widget.point.speedMetersPerSecond?.toString() ?? '',
  );
  double? _number(String? value) =>
      double.tryParse((value ?? '').trim().replaceAll(',', '.'));
  @override
  void dispose() {
    _height.dispose();
    _speed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.localizedWithArgs("Waypoint {0}", [
                widget.editor.points.indexOf(widget.point) + 1,
              ], (l10n, value) => l10n.routesWaypoint2315aa1f(value(0))),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _mode,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.localized(
                  "Height reference",
                  (l10n) => l10n.routesHeightReferenceec9764fc,
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: 'none',
                  child: Text(
                    context.localized(
                      "Height not specified",
                      (l10n) => l10n.routesHeightNotSpecifiedfec716ae,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'agl',
                  child: Text(
                    context.localized(
                      "Above terrain (AGL)",
                      (l10n) => l10n.routesAboveTerrainAgle2867f26,
                    ),
                  ),
                ),
                for (final r in VerticalReference.values)
                  DropdownMenuItem(value: r.name, child: Text(r.label)),
              ],
              onChanged: (v) => setState(() => _mode = v!),
            ),
            if (_mode != 'none')
              TextFormField(
                controller: _height,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'Height (m)'),
                validator: (v) {
                  final n = _number(v);
                  return n == null ||
                          !n.isFinite ||
                          n.abs() > 100000 ||
                          (_mode == 'agl' && n < 0)
                      ? 'Use a height within +/-100000 m; AGL must be nonnegative.'
                      : null;
                },
              ),
            TextFormField(
              controller: _speed,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: context.localized(
                  "Outgoing airspeed (m/s)",
                  (l10n) => l10n.routesOutgoingAirspeedMS43d6115b,
                ),
                helperText: context.localized(
                  "Empty means unknown. Applies to the next segment.",
                  (l10n) => l10n.routesEmptyMeansUnknownApplies42bd9aa3,
                ),
              ),
              validator: (v) {
                if (v!.trim().isEmpty) return null;
                final n = _number(v);
                return n == null || !n.isFinite || n <= 0 || n > 200
                    ? 'Use greater than 0 to 200 m/s.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            Text(
              context.localized(
                "Terrain uses WGS84 ellipsoid heights. Other absolute references are preserved, but cannot yet be converted for the 3D view or clearance calculation. A * marker shows a 30 m AGL preview only.",
                (l10n) => l10n.commonTerrainUsesWgsEllipsoid7e8c1f46,
              ),
            ),
            const SizedBox(height: 16),
            if (widget.editor.points.length > 1)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.localized(
                    "Apply height and speed to all waypoints",
                    (l10n) => l10n.routesApplyHeightAndSpeed4746e071,
                  ),
                ),
                subtitle: Text(
                  context.localized(
                    "Replaces existing height and speed settings for this draft. Undo is available.",
                    (l10n) => l10n.routesReplacesExistingHeightAndbb3345ca,
                  ),
                ),
                value: _applyAll,
                onChanged: (v) => setState(() => _applyAll = v!),
              ),
            FilledButton(
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                final WaypointHeight? height = _mode == 'none'
                    ? null
                    : _mode == 'agl'
                    ? AglWaypointHeight(
                        AboveGroundHeight(_number(_height.text)!),
                      )
                    : AbsoluteWaypointHeight(
                        ReferencedElevation(
                          meters: _number(_height.text)!,
                          reference: VerticalReference.values.byName(_mode),
                        ),
                      );
                if (_applyAll) {
                  widget.editor.configureAllWaypoints(
                    height: height,
                    speedMetersPerSecond: _number(_speed.text),
                  );
                } else {
                  widget.editor.configurePoint(
                    widget.point.key,
                    height: height,
                    speedMetersPerSecond: _number(_speed.text),
                  );
                }
                Navigator.pop(context);
              },
              child: Text(
                context.localized(
                  "Apply waypoint settings",
                  (l10n) => l10n.routesApplyWaypointSettingsd66af84a,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
