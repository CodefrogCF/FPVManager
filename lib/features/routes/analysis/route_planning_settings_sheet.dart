import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';

import '../../../core/models/drone_profile.dart';
import '../../../core/models/route_planning_settings.dart';
import '../route_editor_controller.dart';

Future<void> showRoutePlanningSettings(
  BuildContext context,
  RouteEditorController editor,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _Settings(editor: editor),
);

class _Settings extends StatefulWidget {
  const _Settings({required this.editor});
  final RouteEditorController editor;
  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  final _form = GlobalKey<FormState>();
  late final _settings = widget.editor.planning;
  late bool _wind = _settings.useWind,
      _return = _settings.includeReturn,
      _telemetryEstimate = _settings.estimateMissingTelemetry;
  late final Map<String, TextEditingController> _fields = {
    'wind': TextEditingController(text: '${_settings.windSpeed}'),
    'direction': TextEditingController(text: '${_settings.windFromDegrees}'),
    'clearance': TextEditingController(text: '${_settings.minimumClearance}'),
    'mass': TextEditingController(
      text: _settings.flightMassGrams?.toString() ?? '',
    ),
    'reference': TextEditingController(
      text: _settings.referenceMassGrams?.toString() ?? '',
    ),
    'efficiency': TextEditingController(text: '${_settings.climbEfficiency}'),
    'reserve': TextEditingController(text: '${_settings.reservePercent}'),
    'optimistic': TextEditingController(text: '${_settings.optimisticFactor}'),
    'conservative': TextEditingController(
      text: '${_settings.conservativeFactor}',
    ),
    'source': TextEditingController(text: _settings.curveSource),
    'curve': TextEditingController(
      text: _settings.powerCurve
          .map((p) => '${p.speed}; ${p.watts}')
          .join('\n'),
    ),
  };
  String? _error;
  double? _read(String key) =>
      double.tryParse(_fields[key]!.text.trim().replaceAll(',', '.'));
  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _number(
    String key,
    String label,
    double low,
    double high, {
    bool optional = false,
    String? helper,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _fields[key],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 3,
      ),
      validator: (text) {
        if (optional && text!.trim().isEmpty) return null;
        final n = _read(key);
        return n == null || !n.isFinite || n < low || n > high
            ? 'Enter $low to $high.'
            : null;
      },
    ),
  );

  List<PowerCurvePoint> _curve() => _fields['curve']!.text.trim().isEmpty
      ? []
      : [
          for (final line in _fields['curve']!.text.trim().split('\n'))
            if (line.trim().isNotEmpty) _parseRow(line),
        ];
  PowerCurvePoint _parseRow(String line) {
    final values = line.split(';');
    if (values.length != 2) {
      throw const FormatException('Use one speed; watts pair per line.');
    }
    return PowerCurvePoint(
      double.parse(values[0].trim().replaceAll(',', '.')),
      double.parse(values[1].trim().replaceAll(',', '.')),
    );
  }

  void _useDrone() {
    final profile = widget.editor.equipment?.drones
        .where((p) => p.drone.id == widget.editor.droneId)
        .firstOrNull;
    if (profile == null) return;
    final d = profile.drone;
    if (d.takeoffWeightGrams != null) {
      _fields['mass']!.text = '${d.takeoffWeightGrams}';
      _fields['reference']!.text = '${d.takeoffWeightGrams}';
    }
    if (d.hoverPowerWatts != null &&
        d.cruiseSpeedMetersPerSecond != null &&
        d.cruisePowerWatts != null) {
      _fields['curve']!.text =
          '0; ${d.hoverPowerWatts}\n${d.cruiseSpeedMetersPerSecond}; ${d.cruisePowerWatts}';
      String source(DroneParameter p) =>
          profile.measurements[p]?.source.name ?? 'unspecified';
      _fields['source']!.text =
          'Drone profile: hover ${source(DroneParameter.hoverPowerWatts)}, cruise ${source(DroneParameter.cruisePowerWatts)}';
    }
    setState(() => _error = null);
  }

  void _apply() {
    if (!_form.currentState!.validate()) return;
    try {
      final settings = RoutePlanningSettings(
        useWind: _wind,
        windSpeed: _read('wind')!,
        windFromDegrees: _read('direction')!,
        minimumClearance: _read('clearance')!,
        flightMassGrams: _read('mass'),
        referenceMassGrams: _read('reference'),
        climbEfficiency: _read('efficiency')!,
        reservePercent: _read('reserve')!,
        includeReturn: _return,
        estimateMissingTelemetry: _telemetryEstimate,
        optimisticFactor: _read('optimistic')!,
        conservativeFactor: _read('conservative')!,
        powerCurve: _curve(),
        curveSource: _fields['source']!.text.trim(),
        constraints: widget.editor.planning.constraints,
        signal: widget.editor.planning.signal,
        sceneTime: widget.editor.planning.sceneTime,
      );
      settings.validate();
      widget.editor.configurePlanning(settings);
      Navigator.pop(context);
    } catch (_) {
      setState(
        () => _error = 'Check the power curve: at most 30 pairs, increasing speed (0–200 m/s), positive power. A source description is required.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FractionallySizedBox(
      heightFactor: .9,
      child: Form(
        key: _form,
        child: Column(
          children: [
            ListTile(
              title: Text(
                context.localized(
                  "Planning assumptions",
                  (l10n) => l10n.routesPlanningAssumptions61ebf317,
                ),
              ),
              trailing: IconButton(
                tooltip: context.localized(
                  "Close",
                  (l10n) => l10n.commonClosebbfa773e,
                ),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  MediaQuery.viewInsetsOf(context).bottom + 20,
                ),
                children: [
                  Text(
                    context.localized(
                      "These values describe a simplified planning model. They do not account for gusts, manoeuvres, battery sag, temperature, battery ageing or unknown obstacles.",
                      (l10n) => l10n.commonTheseValuesDescribeAa43d2a95,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _number(
                    'clearance',
                    'Minimum sampled terrain clearance (m)',
                    0,
                    1000,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      context.localized(
                        "Include steady wind",
                        (l10n) => l10n.routesIncludeSteadyWind4a449918,
                      ),
                    ),
                    subtitle: Text(
                      context.localized(
                        "Manual assumption, not an automatically verified forecast.",
                        (l10n) => l10n.commonManualAssumptionNotAn31019e80,
                      ),
                    ),
                    value: _wind,
                    onChanged: (v) => setState(() => _wind = v),
                  ),
                  _number('wind', 'Wind speed (m/s)', 0, 100),
                  _number(
                    'direction',
                    'Wind from direction (degrees true)',
                    0,
                    360,
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Estimate missing flight telemetry'),
                    subtitle: const Text(
                      'Optional: use the selected drone cruise speed and the '
                      'configured power curve. Never replace recorded values '
                      'or treat ground speed as measured airspeed.',
                    ),
                    value: _telemetryEstimate,
                    onChanged: (v) => setState(() => _telemetryEstimate = v),
                  ),
                  Text(
                    context.localized(
                      "Level-flight power curve",
                      (l10n) => l10n.routesLevelFlightPowerCurve5cf82060,
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (widget.editor.equipment?.drones.any(
                        (d) => d.drone.id == widget.editor.droneId,
                      ) ==
                      true)
                    TextButton.icon(
                      onPressed: _useDrone,
                      icon: const Icon(Icons.flight),
                      label: Text(
                        context.localized(
                          "Copy available drone values for review",
                          (l10n) => l10n.routesCopyAvailableDroneValues12ac7ef8,
                        ),
                      ),
                    ),
                  _number(
                    'mass',
                    'Total takeoff mass including battery (g)',
                    .1,
                    1000000,
                    optional: true,
                    helper: 'Empty uses the assigned drone profile takeoff mass, if recorded.',
                  ),
                  _number(
                    'reference',
                    'Mass used for the power measurements (g)',
                    .1,
                    1000000,
                    optional: true,
                  ),
                  TextFormField(
                    controller: _fields['curve'],
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: context.localized(
                        "Airspeed (m/s); power (W)",
                        (l10n) => l10n.routesAirspeedMSPower705d4a92,
                      ),
                      hintText: '0; 150\n10; 180\n20; 300',
                      helperText: context.localized(
                        "One pair per line. Level flight only, without climb power. No extrapolation outside the curve.",
                        (l10n) => l10n.commonOnePairPerLine94168101,
                      ),
                    ),
                    validator: (_) {
                      try {
                        _curve();
                        return null;
                      } catch (_) {
                        return 'Use speed; watts, one pair per line.';
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fields['source'],
                    maxLength: 240,
                    decoration: InputDecoration(
                      labelText: context.localized(
                        "Curve source / measurement conditions",
                        (l10n) =>
                            l10n.routesCurveSourceMeasurementConditions241dc3af,
                      ),
                    ),
                    validator: (v) => v!.trim().isEmpty
                        ? 'Describe whether the curve is measured or estimated.'
                        : null,
                  ),
                  _number(
                    'efficiency',
                    'Assumed climb efficiency (0–1)',
                    .01,
                    1,
                  ),
                  Text(
                    context.localized(
                      "Power is interpolated by airspeed and scaled by (takeoff mass / reference mass)^1.5. Climb adds m·g·height / efficiency. Descent does not recover energy. This assumes multirotor-like behaviour.",
                      (l10n) => l10n.routesPowerIsInterpolatedBy90df4a57,
                    ),
                  ),
                  const Divider(),
                  Text(
                    context.localized(
                      "Reserve and uncertainty",
                      (l10n) => l10n.routesReserveAndUncertainty53aafdf4,
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      context.localized(
                        "Include return to takeoff",
                        (l10n) => l10n.routesIncludeReturnToTakeoff90a464ac,
                      ),
                    ),
                    subtitle: Text(
                      context.localized(
                        "Retrace the planned path, with reverse-direction wind. No return leg is added at takeoff.",
                        (l10n) => l10n.commonRetraceThePlannedPathec9e751c,
                      ),
                    ),
                    value: _return,
                    onChanged: (v) => setState(() => _return = v),
                  ),
                  _number('reserve', 'Reserve (% of nominal capacity)', 0, 95),
                  _number(
                    'optimistic',
                    'Optimistic consumption multiplier',
                    .1,
                    1,
                  ),
                  _number(
                    'conservative',
                    'Conservative consumption multiplier',
                    1,
                    5,
                  ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  FilledButton(
                    onPressed: _apply,
                    child: Text(
                      context.localized(
                        "Apply planning assumptions",
                        (l10n) => l10n.routesApplyPlanningAssumptions8576b420,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
