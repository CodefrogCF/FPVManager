import 'package:flutter/material.dart';

import '../waypoint_settings_sheet.dart';
import 'route_analysis_controller.dart';
import 'route_profile_chart.dart';
import 'route_planning_settings_sheet.dart';

Future<void> showRouteAnalysis(
  BuildContext context,
  RouteAnalysisController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _RouteAnalysisSheet(controller: controller),
);

String _meters(double? n) =>
    n == null ? 'Unknown' : '${n.toStringAsFixed(1)} m';
String _duration(double? n) =>
    n == null ? 'Unknown' : '${(n / 60).toStringAsFixed(1)} min';
String _wh(double? n) => n == null ? 'Unknown' : '${n.toStringAsFixed(2)} Wh';

class _RouteAnalysisSheet extends StatefulWidget {
  const _RouteAnalysisSheet({required this.controller});
  final RouteAnalysisController controller;
  @override
  State<_RouteAnalysisSheet> createState() => _RouteAnalysisSheetState();
}

class _RouteAnalysisSheetState extends State<_RouteAnalysisSheet> {
  RouteAnalysisController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    if (c.result == null) c.calculate();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FractionallySizedBox(
      heightFactor: .92,
      child: DefaultTabController(
        length: 3,
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Route analysis',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Planning assumptions',
                    icon: const Icon(Icons.tune),
                    onPressed: c.loading
                        ? null
                        : () => showRoutePlanningSettings(context, c.editor),
                  ),
                  IconButton(
                    tooltip: 'Recalculate route',
                    icon: const Icon(Icons.refresh),
                    onPressed: c.loading ? null : c.calculate,
                  ),
                  IconButton(
                    tooltip: 'Close analysis',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              if (c.loading) ...[
                LinearProgressIndicator(
                  value: c.totalSamples == 0
                      ? null
                      : c.completedSamples / c.totalSamples,
                ),
                Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Terrain samples ${c.completedSamples}/${c.totalSamples}',
                      ),
                    ),
                    TextButton(
                      onPressed: c.cancel,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
              if (c.error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    c.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const TabBar(
                tabs: [
                  Tab(text: 'Profile'),
                  Tab(text: 'Flight'),
                  Tab(text: 'Energy'),
                ],
              ),
              Expanded(
                child: c.result == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: c.loading
                              ? const Text('Calculating route…')
                              : FilledButton.icon(
                                  onPressed: c.calculate,
                                  icon: const Icon(Icons.calculate_outlined),
                                  label: const Text('Calculate current route'),
                                ),
                        ),
                      )
                    : TabBarView(
                        children: [
                          _profile(context),
                          _flight(context),
                          _energy(context),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _profile(BuildContext context) {
    final r = c.result!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (c.terrainError != null)
          Text(
            c.terrainError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        Text(
          'Terrain sampling: ${c.samplingMethods.isEmpty ? "unavailable" : c.samplingMethods.join(", ")}. WGS84 ellipsoid heights.',
        ),
        if (r.profile.any((p) => p.ground != null || p.altitude != null))
          RouteProfileChart(analysis: r),
        _metric(
          'Minimum sampled terrain clearance',
          _meters(r.minimumClearance),
        ),
        _metric(
          'Total climb / descent',
          '${_meters(r.climb)} / ${_meters(r.descent)}',
        ),
        if (!r.completeClearance)
          const Text(
            'Clearance is incomplete: set a height for every waypoint. Absolute heights need WGS84 ellipsoid reference; other datums cannot be converted here.',
          ),
        const SizedBox(height: 12),
        Text(
          '${r.profile.length} terrain samples, at most 50 m apart horizontally. Heights interpolate linearly between waypoints; AGL applies at waypoints and does not imply terrain following.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Terrain samples do not prove continuous clearance. Small features between samples, elevation-model errors, cables, trees and other unknown obstacles can be missed. Verify the route on site and with current official information.',
        ),
        const Text(
          'Red map segments indicate sampled terrain clearance below the configured minimum or insufficient conservative battery reserve for the selected pack.',
        ),
      ],
    );
  }

  Widget _flight(BuildContext context) {
    final r = c.result!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _metric('Horizontal distance', _meters(r.horizontalDistance)),
        _metric('Three-dimensional distance', _meters(r.spatialDistance)),
        _metric('Estimated flight duration', _duration(r.seconds)),
        _metric(
          'Total climb / descent',
          '${_meters(r.climb)} / ${_meters(r.descent)}',
        ),
        Text(
          c.editor.planning.useWind
              ? 'Steady wind assumption: ${c.editor.planning.windSpeed} m/s from ${c.editor.planning.windFromDegrees}° true. Crosswind compensation is included; an unachievable track remains unknown.'
              : 'Wind is excluded. Enable a manual wind assumption in Planning assumptions.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Approximate great-circle distances and constant airspeed per segment. No acceleration, hovering, manoeuvre time or gusts are included. The aircraft must be able to achieve the planned speed and climb rate.',
        ),
        for (final s in r.segments)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Segment ${s.index + 1} → ${s.index + 2}'),
            subtitle: Text(
              '${_meters(s.horizontal)} horizontal · ${_meters(s.spatial)} 3D\nAirspeed ${s.speed?.toStringAsFixed(1) ?? "unknown"} m/s · ${_duration(s.seconds)} · clearance ${_meters(s.minimumClearance)}',
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () {
              c.editor.select(c.editor.points[s.index].key);
              showWaypointSettings(context, c.editor);
            },
          ),
      ],
    );
  }

  Widget _energy(BuildContext context) {
    final energy = c.energy!;
    final selected = c.batteries
        .where((b) => b.battery.id == c.selectedBatteryId)
        .firstOrNull;
    final settings = c.editor.planning;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _metric('Estimated outbound energy', _wh(energy.totalWh)),
        if (!c.result!.completeClearance)
          const Text(
            'Terrain clearance remains unknown. The energy budget does not establish route safety.',
          ),
        if (settings.includeReturn &&
            energy.available &&
            !energy.returnAvailable)
          Text(
            'Return energy is unknown; no complete feasibility estimate is available.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (energy.problem != null)
          Text(
            energy.problem!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        Text('Power curve source: ${settings.curveSource}'),
        Text(
          'Optimistic ×${settings.optimisticFactor} · conservative ×${settings.conservativeFactor} · reserve ${settings.reservePercent}% of nominal capacity.',
        ),
        Text(
          settings.includeReturn
              ? 'Return to takeoff is included by retracing the planned path, with wind recalculated in reverse.'
              : 'Return flight is excluded from the budget.',
        ),
        const Text(
          'The same configured takeoff mass is used for alternative packs. Adjust it for the installed battery.',
        ),
        const SizedBox(height: 12),
        if (c.editor.equipmentError != null) Text(c.editor.equipmentError!),
        if (c.batteries.isEmpty)
          const Text(
            'Assign an individual battery in Route equipment to compare capacity and reserve. Capacities of alternative packs are never added.',
          ),
        if (c.batteries.isNotEmpty)
          DropdownButtonFormField<int>(
            key: ValueKey(c.selectedBatteryId),
            initialValue: c.selectedBatteryId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Battery to inspect and highlight',
            ),
            items: [
              for (final b in c.batteries)
                DropdownMenuItem(
                  value: b.battery.id,
                  child: Text(b.battery.name),
                ),
            ],
            onChanged: c.selectBattery,
          ),
        if (selected != null) ...[
          _metric('Available at recorded charge', _wh(selected.availableWh)),
          _metric('Usable after reserve', _wh(selected.budgetWh)),
          _metric('Optimistic requirement', _wh(selected.optimisticWh)),
          _metric('Conservative requirement', _wh(selected.conservativeWh)),
          _metric(
            'Approximate outbound consumption',
            energy.approximateMah(selected.battery.nominalVoltageVolts) == null
                ? 'Unknown (nominal voltage required)'
                : '${energy.approximateMah(selected.battery.nominalVoltageVolts)!.toStringAsFixed(0)} mAh',
          ),
          Text(selected.status),
          if (selected.criticalSegments.isNotEmpty)
            Text(
              'Critical conservative segments: ${selected.criticalSegments.map((i) => "${i + 1} → ${i + 2}").join(", ")}',
            ),
          Text(
            'Recorded charge: ${selected.battery.chargePercent?.toStringAsFixed(0) ?? "unknown"}% · pack status: ${selected.battery.availability}.',
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'Estimates are not guarantees. Scenarios scale consumption; they are not statistical confidence intervals. Validate the model against measured flights. Battery condition, temperature and voltage sag can reduce usable energy.',
        ),
        const Text(
          'The level-flight power curve is interpolated without extrapolation and scaled by mass^1.5. Climb work is added with the configured efficiency; descent has no energy recovery.',
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => showRoutePlanningSettings(context, c.editor),
          icon: const Icon(Icons.tune),
          label: const Text('Edit planning assumptions'),
        ),
      ],
    );
  }

  Widget _metric(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Wrap(
      spacing: 12,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
