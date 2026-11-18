import 'package:flutter/foundation.dart';

import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../core/database/fpv_database.dart';
import '../../core/database/repositories/flight_plan_repository.dart';
import '../../core/models/local_csv_file.dart';
import '../../core/models/route_planning_settings.dart';
import '../../core/models/flight_route.dart';
import '../routes/analysis/route_analysis.dart';
import 'telemetry_log.dart';
import 'telemetry_repository.dart';

class TelemetryTab extends StatefulWidget {
  const TelemetryTab({
    super.key,
    required this.repository,
    this.pickFile = pickLocalCsv,
  });
  final TelemetryRepository repository;
  final Future<({String name, Uint8List bytes})?> Function() pickFile;
  @override
  State<TelemetryTab> createState() => _TelemetryTabState();
}

class _TelemetryTabState extends State<TelemetryTab> {
  late final _logs = widget.repository.watch();
  bool _busy = false, _loading = false;
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _loading = true;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.localizedWithArgs("Telemetry: {0}", [
                e,
              ], (l10n, value) => l10n.telemetryTelemetry9ac39ce5(value(0))),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _loading = false;
        });
      }
    }
  }

  Future<void> _import() async {
    final file = await widget.pickFile();
    if (file == null) return;
    final log = await compute(decodeTelemetry, file.bytes);
    final db = widget.repository.database,
        drones = await db.select(db.drones).get(),
        plans = await db.select(db.flightPlans).get();
    if (!mounted) return;
    setState(() => _loading = false);
    final association = await showDialog<(int?, int?)>(
      context: context,
      builder: (_) => _ImportPreview(
        name: file.name,
        log: log,
        drones: drones,
        plans: plans,
      ),
    );
    if (association == null || !mounted) return;
    setState(() => _loading = true);
    await widget.repository.import(
      file.name,
      file.bytes,
      droneId: association.$1,
      planId: association.$2,
    );
  }

  Future<void> _open(int id) async {
    final row = await widget.repository.get(id),
        log = await compute(decodeTelemetry, row.rawBytes);
    if (!mounted) return;
    setState(() => _loading = false);
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _TelemetryDetails(
          repository: widget.repository,
          row: row,
          log: log,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        context.localized(
          "Import one continuous flight. Raw CSV stays in the local database. No telemetry is uploaded.",
          (l10n) => l10n.telemetryImportOneContinuousFlight94f89be2,
        ),
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: _busy ? null : () => _run(_import),
        icon: const Icon(Icons.file_open_outlined),
        label: Text(
          context.localized(
            "Import telemetry CSV",
            (l10n) => l10n.telemetryImportTelemetryCsveb2d1023,
          ),
        ),
      ),
      ExpansionTile(
        title: Text(
          context.localized(
            "Supported formats",
            (l10n) => l10n.telemetrySupportedFormatsdf1bdc5f,
          ),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: SelectableText(
              context.localized(
                "FPVManager CSV v1: time_s,airspeed_m_s,voltage_v,current_a (groundspeed_m_s is also accepted).\nEdgeTX: Date, Time, GSpd(kmh/km/h/m/s/kts), Curr(A), VFAS(V) or Bat(V).\nUse a single voltage and speed column. UTF-8, decimal dot, 2–20000 rows, up to 4 MiB, gaps ≤30 s. Missing measurements are rejected. See docs/preflight.md for an example.",
                (l10n) => l10n.commonFpvmanagerCsvVTime07c740c7,
              ),
            ),
          ),
        ],
      ),
      if (_loading) const LinearProgressIndicator(),
      StreamBuilder(
        key: const ValueKey('telemetry-library'),
        stream: _logs,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(
              context.localized(
                "Local telemetry unavailable. Reopen this screen to retry.",
                (l10n) => l10n.telemetryLocalTelemetryUnavailableReopencb8a0598,
              ),
            );
          }
          if (!snapshot.hasData) return const LinearProgressIndicator();
          return Column(
            children: [
              for (final row in snapshot.data!)
                ListTile(
                  leading: const Icon(Icons.insights),
                  title: Text(row.fileName),
                  subtitle: Text(
                    context.localizedWithArgs(
                      "Imported {0}",
                      [row.importedAt.toLocal()],
                      (l10n, value) => l10n.telemetryImportedbd3c3768(value(0)),
                    ),
                  ),
                  onTap: _busy ? null : () => _run(() => _open(row.id)),
                  trailing: IconButton(
                    tooltip: context.localized(
                      "Delete local telemetry",
                      (l10n) => l10n.telemetryDeleteLocalTelemetryfa6452e1,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            setState(() => _loading = false);
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(
                                  context.localized(
                                    "Delete raw telemetry?",
                                    (l10n) => l10n
                                        .telemetryDeleteRawTelemetryad6e4046,
                                  ),
                                ),
                                content: Text(row.fileName),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text(
                                      context.localized(
                                        "Cancel",
                                        (l10n) => l10n.commonCancel77dfd213,
                                      ),
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text(
                                      context.localized(
                                        "Delete",
                                        (l10n) => l10n.commonDeletef6fdbe48,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              await widget.repository.delete(row.id);
                            }
                          }),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}

Widget _measurements(BuildContext context, TelemetryLog log) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      context.localizedWithArgs('{0} · {1} samples', [
        log.format,
        log.samples.length,
      ], (l10n, value) => l10n.telemetrySamples49577d36(value(0), value(1))),
    ),
    Text(
      context.localizedWithArgs('Recorded duration: {0} s', [
        log.duration.toStringAsFixed(1),
      ], (l10n, value) => l10n.telemetryRecordedDurationSe198ddeb(value(0))),
    ),
    Text(
      context.translate(
        log.isAirspeed
            ? 'Average airspeed: {0} m/s · maximum {1} m/s'
            : 'Average ground speed: {0} m/s · maximum {1} m/s',
        [log.averageSpeed.toStringAsFixed(2), log.maxSpeed.toStringAsFixed(2)],
      ),
    ),
    Text(
      context.localizedWithArgs(
        'Measured energy: {0} Wh · average power {1} W',
        [log.energyWh.toStringAsFixed(3), log.averagePower.toStringAsFixed(1)],
        (l10n, value) =>
            l10n.telemetryMeasuredEnergyWhAverage9acf6860(value(0), value(1)),
      ),
    ),
    Text(
      context.localized(
        'Duration includes all recorded idle/hover time. Trim the log to one flight before importing.',
        (l10n) => l10n.telemetryDurationIncludesAllRecordedb1545492,
      ),
    ),
  ],
);

class _ImportPreview extends StatefulWidget {
  const _ImportPreview({
    required this.name,
    required this.log,
    required this.drones,
    required this.plans,
  });
  final String name;
  final TelemetryLog log;
  final List<Drone> drones;
  final List<FlightPlan> plans;
  @override
  State<_ImportPreview> createState() => _ImportPreviewState();
}

class _ImportPreviewState extends State<_ImportPreview> {
  int? _drone, _plan;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      context.localized(
        "Import telemetry locally?",
        (l10n) => l10n.telemetryImportTelemetryLocallyf7626443,
      ),
    ),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.name),
            _measurements(context, widget.log),
            DropdownButtonFormField<int>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Drone'),
              items: [
                DropdownMenuItem<int>(
                  child: Text(
                    context.localized(
                      "Unassigned",
                      (l10n) => l10n.telemetryUnassignede57016ed,
                    ),
                  ),
                ),
                for (final d in widget.drones)
                  DropdownMenuItem(value: d.id, child: Text(d.name)),
              ],
              onChanged: (v) => _drone = v,
            ),
            DropdownButtonFormField<int>(
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.localized(
                  "Flight plan for comparison",
                  (l10n) => l10n.telemetryFlightPlanForComparison6e3eb9d5,
                ),
              ),
              items: [
                DropdownMenuItem<int>(
                  child: Text(
                    context.localized(
                      "Unassigned",
                      (l10n) => l10n.telemetryUnassignede57016ed,
                    ),
                  ),
                ),
                for (final p in widget.plans)
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) => _plan = v,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(
          context.localized("Cancel", (l10n) => l10n.commonCancel77dfd213),
        ),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, (_drone, _plan)),
        child: Text(
          context.localized(
            "Import locally",
            (l10n) => l10n.commonImportLocallycfc01f3f,
          ),
        ),
      ),
    ],
  );
}

class _TelemetryDetails extends StatefulWidget {
  const _TelemetryDetails({
    required this.repository,
    required this.row,
    required this.log,
  });
  final TelemetryRepository repository;
  final TelemetryFlight row;
  final TelemetryLog log;
  @override
  State<_TelemetryDetails> createState() => _TelemetryDetailsState();
}

class _TelemetryDetailsState extends State<_TelemetryDetails> {
  bool _stillAir = false, _busy = false;
  String? _error;
  late Future<_ComparisonData?> _comparison = _load();
  Future<_ComparisonData?> _load() async {
    final id = widget.row.planId;
    if (id == null) return null;
    final db = widget.repository.database,
        route = await FlightPlanRepository(db).getRoute(id);
    if (route == null) return null;
    final droneId = widget.row.droneId ?? route.plan.droneId;
    final drone = droneId == null
        ? null
        : await (db.select(
            db.drones,
          )..where((t) => t.id.equals(droneId))).getSingleOrNull();
    final settings = RoutePlanningSettings.decode(route.plan.planningJson);
    double? duration, speed;
    if (route.waypoints.length >= 2) {
      final points = route.waypoints
          .map(
            (p) => RouteWaypointInput(
              position: p.position,
              height: p.height,
              speedMetersPerSecond: p.speedMetersPerSecond,
            ),
          )
          .toList();
      final analyzed = RouteAnalysis.calculate(
        points,
        RouteSamplingPlan.create(points),
        null,
        settings,
      );
      duration = analyzed.seconds;
      if (duration != null && duration > 0) {
        speed = widget.log.isAirspeed
            ? analyzed.segments.fold<double>(
                    0,
                    (sum, s) => sum + (s.speed ?? 0) * s.seconds!,
                  ) /
                  duration
            : analyzed.horizontalDistance / duration;
      }
    }
    return _ComparisonData(
      route.plan.planningJson,
      settings,
      drone?.takeoffWeightGrams,
      duration,
      speed,
      droneId != null &&
          route.plan.droneId != null &&
          droneId != route.plan.droneId,
      route.plan.droneId,
      settings.flightMassGrams == null ? droneId : null,
    );
  }

  Future<void> _apply(
    _ComparisonData data,
    TelemetryComparison comparison,
  ) async {
    final factor = comparison.factor!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          context.localized(
            "Apply route calibration?",
            (l10n) => l10n.telemetryApplyRouteCalibration5c654485,
          ),
        ),
        content: Text(
          context.localizedWithArgs(
            "Scale this saved route’s power curve by {0}. This is a level-flight approximation over the logged speed profile; climbs, wind, aggressive maneuvers and battery/sensor errors can distort it. The original CSV remains stored. Other routes and drone specifications are unchanged.",
            [factor.toStringAsFixed(3)],
            (l10n, value) => l10n.commonScaleThisSavedRoutes1968fc72(value(0)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              context.localized("Cancel", (l10n) => l10n.commonCancel77dfd213),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.localized(
                "Apply to this route",
                (l10n) => l10n.telemetryApplyToThisRoute1635cca9,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.calibrate(
        planId: widget.row.planId!,
        expectedPlanning: data.encoded,
        expectedRouteDroneId: data.routeDroneId,
        massDroneId: data.massDroneId,
        expectedDroneMass: data.mass,
        calibrated: data.settings.calibrated(
          factor,
          'Telemetry #${widget.row.id}: level-flight fit ${factor.toStringAsFixed(3)}${_stillAir ? ", still-air assumption" : ""}',
        ),
      );
      if (mounted) {
        setState(() {
          _comparison = _load();
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.row.fileName)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _measurements(context, widget.log),
        const Divider(),
        Text(
          context.localized(
            "Model comparison",
            (l10n) => l10n.telemetryModelComparisondaa80a44,
          ),
          style: TextStyle(fontSize: 20),
        ),
        Text(
          context.localized(
            "The route power curve is evaluated at every recorded speed with its mass correction. Energy uses trapezoidal integration of voltage × current. No climb or maneuver correction is inferred.",
            (l10n) => l10n.telemetryTheRoutePowerCurvee9b27f2a,
          ),
        ),
        if (!widget.log.isAirspeed)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              context.localized(
                "Use ground speed as airspeed",
                (l10n) => l10n.telemetryUseGroundSpeedAs5bb04e27,
              ),
            ),
            subtitle: Text(
              context.localized(
                "Approximation for a still-air recording only",
                (l10n) => l10n.telemetryApproximationForAStill90100705,
              ),
            ),
            value: _stillAir,
            onChanged: _busy ? null : (v) => setState(() => _stillAir = v),
          ),
        FutureBuilder(
          future: _comparison,
          builder: (_, s) {
            if (s.hasError) {
              return Text(
                context.localized(
                  "Route comparison unavailable. Check the saved route inputs.",
                  (l10n) =>
                      l10n.telemetryRouteComparisonUnavailableCheck13192917,
                ),
              );
            }
            if (s.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            final data = s.data;
            if (data == null) {
              return Text(
                context.localized(
                  "No associated flight plan is available. Associate a plan when importing to compare its model.",
                  (l10n) => l10n.telemetryNoAssociatedFlightPlan5a0a6161,
                ),
              );
            }
            final result = widget.log.compare(
              data.settings,
              droneMass: data.mass,
              assumeStillAir: _stillAir,
            );
            String difference(double? planned, double measured, String unit) =>
                planned == null
                ? 'Unknown (complete route heights/speeds are required)'
                : '${planned.toStringAsFixed(2)} $unit predicted · ${(measured - planned).toStringAsFixed(2)} $unit measured − predicted';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.localizedWithArgs(
                    "Saved outbound route duration: {0}",
                    [difference(data.duration, widget.log.duration, "s")],
                    (l10n, value) => l10n
                        .telemetrySavedOutboundRouteDuration18b87ca4(value(0)),
                  ),
                ),
                Text(
                  context.localizedWithArgs(
                    "Saved outbound route mean {0} speed: {1}",
                    [
                      widget.log.isAirspeed ? "air" : "horizontal ground",
                      difference(data.speed, widget.log.averageSpeed, "m/s"),
                    ],
                    (l10n, value) =>
                        l10n.telemetrySavedOutboundRouteMean0818ac58(
                          value(0),
                          value(1),
                        ),
                  ),
                ),
                Text(
                  context.localized(
                    "Route comparisons assume the recording covers the same outbound path. Return flights and idle time are not automatically removed.",
                    (l10n) => l10n.telemetryRouteComparisonsAssumeThed64d19cc,
                  ),
                ),
                if (data.mismatch)
                  Text(
                    context.localized(
                      "Different drones are associated with the log and route. Calibration is disabled.",
                      (l10n) =>
                          l10n.telemetryDifferentDronesAreAssociated17ab6eae,
                    ),
                  ),
                if (result.problem != null)
                  Text(result.problem!)
                else ...[
                  Text(
                    context.localizedWithArgs(
                      "Model energy over recorded speeds: {0} Wh",
                      [result.predictedWh!.toStringAsFixed(3)],
                      (l10n, value) => l10n
                          .telemetryModelEnergyOverRecorded6bf1955f(value(0)),
                    ),
                  ),
                  Text(
                    context.localizedWithArgs(
                      "Measured − modeled: {0} Wh ({1}%)",
                      [
                        result.differenceWh!.toStringAsFixed(3),
                        ((result.factor! - 1) * 100).toStringAsFixed(1),
                      ],
                      (l10n, value) => l10n.telemetryMeasuredModeledWhae99a8d2(
                        value(0),
                        value(1),
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: !_busy && result.canCalibrate && !data.mismatch
                        ? () => _apply(data, result)
                        : null,
                    child: Text(
                      context.localized(
                        "Preview & apply calibration",
                        (l10n) => l10n.telemetryPreviewApplyCalibrationa8b7db04,
                      ),
                    ),
                  ),
                  if (!result.canCalibrate)
                    Text(
                      context.localized(
                        "Calibration outside 0.25–4× is not applied. Check units, sensors and flight conditions.",
                        (l10n) => l10n.commonCalibrationOutsideIsNot45f5bb20,
                      ),
                    ),
                ],
              ],
            );
          },
        ),
        if (_error != null) Text(_error!),
      ],
    ),
  );
}

class _ComparisonData {
  const _ComparisonData(
    this.encoded,
    this.settings,
    this.mass,
    this.duration,
    this.speed,
    this.mismatch,
    this.routeDroneId,
    this.massDroneId,
  );
  final String encoded;
  final RoutePlanningSettings settings;
  final double? mass, duration, speed;
  final bool mismatch;
  final int? routeDroneId, massDroneId;
}
