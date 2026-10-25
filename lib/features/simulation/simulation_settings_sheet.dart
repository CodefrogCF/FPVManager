import 'package:flutter/material.dart';

import '../../core/database/fpv_database.dart';
import '../../core/database/repositories/drone_repository.dart';
import 'simulation_settings.dart';

Future<SimulationSettings?> showSimulationSettings(
  BuildContext context, {
  required DroneRepository repository,
  SimulationSettings initial = const SimulationSettings(),
  required bool hasSelection,
}) => showModalBottomSheet<SimulationSettings>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _Settings(
    repository: repository,
    initial: initial,
    hasSelection: hasSelection,
  ),
);

class _Settings extends StatefulWidget {
  const _Settings({
    required this.repository,
    required this.initial,
    required this.hasSelection,
  });
  final DroneRepository repository;
  final SimulationSettings initial;
  final bool hasSelection;
  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  final _form = GlobalKey<FormState>();
  late final _fields = <String, TextEditingController>{
    'agl': TextEditingController(text: '${widget.initial.agl}'),
    'cameraTilt': TextEditingController(
      text: '${widget.initial.cameraTiltDegrees}',
    ),
    'speed': TextEditingController(text: '${widget.initial.maxSpeed}'),
    'climb': TextEditingController(text: '${widget.initial.climbSpeed}'),
    'acceleration': TextEditingController(
      text: '${widget.initial.acceleration}',
    ),
    'deceleration': TextEditingController(
      text: '${widget.initial.deceleration}',
    ),
    'acroThrustToWeight': TextEditingController(
      text: '${widget.initial.acroThrustToWeight}',
    ),
    'acroThrustCurve': TextEditingController(
      text: '${widget.initial.acroThrustCurve}',
    ),
    'acroMotorTimeConstant': TextEditingController(
      text: '${widget.initial.acroMotorTimeConstant}',
    ),
    'acroTerminalVelocity': TextEditingController(
      text: '${widget.initial.acroTerminalVelocity}',
    ),
  };
  final _acroOptions = ExpansibleController();
  List<Drone> _drones = [];
  int? _drone;
  bool _loading = true;
  late SimulationFlightMode _mode = widget.initial.flightMode;
  late SimulationGraphicsProfile _graphics = widget.initial.graphicsProfile;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final drones = await widget.repository.getAllDrones();
      if (!mounted) return;
      setState(() {
        _drones = drones;
        _drone = drones.any((d) => d.id == widget.initial.droneId)
            ? widget.initial.droneId
            : null;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Drone profiles unavailable. Default or manual parameters remain available.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    _acroOptions.dispose();
    super.dispose();
  }

  double? read(String key) =>
      double.tryParse(_fields[key]!.text.trim().replaceAll(',', '.'));
  double parameter(String key, double min, double max, double fallback) {
    final value = read(key);
    return value != null && value.isFinite && value >= min && value <= max
        ? value
        : fallback;
  }

  String get _controlHelp => _mode == SimulationFlightMode.gps
      ? 'Touch/controller: left stick moves, right stick looks. Keyboard: WASD / arrows move, drag or IJKL looks, E/Q climbs/descends.'
      : 'Touch/controller: left stick vertical = throttle, horizontal = yaw; right stick vertical = pitch, horizontal = roll. Keyboard: E/Q throttle, A/D yaw, W/S pitch, left/right arrows roll. IJKL also controls pitch/roll.';
  String get _acroHoverHelp {
    final ratio = read('acroThrustToWeight'), curve = read('acroThrustCurve');
    if (ratio == null ||
        !ratio.isFinite ||
        ratio < 1.1 ||
        ratio > 12 ||
        curve == null ||
        !curve.isFinite ||
        curve < 0 ||
        curve > 1) {
      return 'Enter valid thrust and curve values to estimate level hover.';
    }
    final hover = SimulationSettings(
      acroThrustToWeight: ratio,
      acroThrustCurve: curve,
    ).acroHoverThrottle;
    return 'Estimated level hover: ${(hover * 100).toStringAsFixed(0)}% throttle. This is a model estimate, not measured drone performance.';
  }

  Widget number(String key, String label, double min, double max) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: ValueKey('simulation-$key'),
      controller: _fields[key],
      onChanged: (_) {
        if (key.startsWith('acro')) setState(() {});
      },
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, helperText: '$min–$max'),
      validator: (_) {
        final v = read(key);
        return v == null || !v.isFinite || v < min || v > max
            ? 'Enter $min–$max.'
            : null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) => SafeArea(
    child: FractionallySizedBox(
      heightFactor: .9,
      child: Form(
        key: _form,
        child: Column(
          children: [
            ListTile(
              title: const Text('Free flight simulation'),
              trailing: IconButton(
                tooltip: 'Close simulation settings',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  MediaQuery.viewInsetsOf(context).bottom + 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Simplified flight exploration, not a prediction of real aircraft performance. '
                      'Terrain contact stops movement; cables, buildings and other obstacles have no collision model.',
                    ),
                    Text(
                      widget.hasSelection
                          ? 'Spawn at the selected map point or spot.'
                          : 'No selected point: spawn at the terrain under the camera target.',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SimulationFlightMode>(
                      initialValue: _mode,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Flight mode',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: SimulationFlightMode.gps,
                          child: Text('GPS · assisted movement'),
                        ),
                        DropdownMenuItem(
                          value: SimulationFlightMode.angle,
                          child: Text('Angle · Mode 2, self-level'),
                        ),
                        DropdownMenuItem(
                          value: SimulationFlightMode.acro,
                          child: Text('Acro · Mode 2, rate control'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _mode = value);
                      },
                    ),
                    Text(switch (_mode) {
                      SimulationFlightMode.gps => 'Assisted movement with automatic braking. Left stick moves, right stick looks.',
                      SimulationFlightMode.angle => 'Mode 2: left stick throttle/yaw, right stick pitch/roll. Tilt is limited to 50° and self-levels when released.',
                      SimulationFlightMode.acro => 'Mode 2: left stick throttle/yaw, right stick pitch/roll rates up to 180°/s. No self-level or tilt limit; loops and inverted flight are possible.',
                    }),
                    if (_mode == SimulationFlightMode.angle)
                      const Text(
                        'Centred throttle is a 50% hover aid while level. Tilt needs more throttle to maintain height. Switching modes respawns level at the spawn point.',
                      ),
                    if (_mode == SimulationFlightMode.acro)
                      const Text(
                        'Throttle is 0% with the left stick centred or below centre; pushing upward increases it to 100% at the top. Releasing the stick cuts throttle. Thrust follows the drone: inverted full throttle accelerates toward the ground. Low throttle allows free fall and existing momentum continues. No altitude hold or assisted speed limits. Switching modes respawns level.',
                      ),
                    const SizedBox(height: 12),
                    if (_loading) const LinearProgressIndicator(),
                    DropdownButtonFormField<SimulationGraphicsProfile>(
                      key: const ValueKey('simulation-graphics'),
                      initialValue: _graphics,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Graphics profile',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: SimulationGraphicsProfile.quality,
                          child: Text('Quality · full resolution'),
                        ),
                        DropdownMenuItem(
                          value: SimulationGraphicsProfile.balanced,
                          child: Text('Balanced · 85% resolution'),
                        ),
                        DropdownMenuItem(
                          value: SimulationGraphicsProfile.performance,
                          child: Text('Performance · 75% resolution'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _graphics = value);
                      },
                    ),
                    const Text(
                      'Graphics affect image sharpness and smoothing. Terrain detail and flight physics stay the same. Adjustable during flight using Graphics.',
                    ),
                    if (_error != null) Text(_error!),
                    DropdownButtonFormField<int>(
                      key: ValueKey(_drone),
                      initialValue: _drone,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Optional drone profile',
                      ),
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('Default / manual parameters'),
                        ),
                        for (final d in _drones)
                          DropdownMenuItem(
                            value: d.id,
                            child: Text(
                              d.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (id) => setState(() {
                        _drone = id;
                        final d = _drones.where((d) => d.id == id).firstOrNull;
                        final settings = d == null
                            ? const SimulationSettings()
                            : SimulationSettings.fromDrone(d);
                        _fields['speed']!.text = '${settings.maxSpeed}';
                        _fields['climb']!.text = '${settings.climbSpeed}';
                      }),
                    ),
                    Text(
                      _mode == SimulationFlightMode.acro
                          ? 'Profile speed/climb values apply to Angle and GPS. Acro thrust, motor response and drag are separate manual estimates.'
                          : 'Profile selection copies recorded maximum speed and climb rate within the supported ranges. Missing values use defaults. Acceleration and braking remain manual approximations.',
                    ),
                    const SizedBox(height: 12),
                    number('agl', 'Spawn height (m AGL)', 1, 1000),
                    if (_mode != SimulationFlightMode.gps) ...[
                      number('cameraTilt', 'FPV camera tilt (° upward)', 0, 80),
                      const Text(
                        '0° looks along the drone. Positive angles tilt the camera upward relative to the frame. You can also adjust this during flight using Camera.',
                      ),
                    ],
                    if (_mode == SimulationFlightMode.acro)
                      ExpansionTile(
                        controller: _acroOptions,
                        maintainState: true,
                        title: const Text('Acro physics'),
                        subtitle: Text(_acroHoverHelp),
                        children: [
                          number(
                            'acroThrustToWeight',
                            'Maximum thrust / weight',
                            1.1,
                            12,
                          ),
                          number(
                            'acroThrustCurve',
                            'Thrust curve (0 linear, 1 quadratic)',
                            0,
                            1,
                          ),
                          number(
                            'acroMotorTimeConstant',
                            'Motor response time (s)',
                            0,
                            .5,
                          ),
                          number(
                            'acroTerminalVelocity',
                            'Terminal free-fall speed (m/s)',
                            5,
                            120,
                          ),
                        ],
                      ),
                    if (_mode != SimulationFlightMode.acro) ...[
                      number(
                        'speed',
                        'Maximum horizontal speed (m/s)',
                        .5,
                        100,
                      ),
                      number(
                        'climb',
                        'Maximum climb / descent speed (m/s)',
                        .2,
                        30,
                      ),
                      number(
                        'acceleration',
                        _mode == SimulationFlightMode.gps
                            ? 'Acceleration response (m/s²)'
                            : 'Extra thrust acceleration (m/s²)',
                        .2,
                        50,
                      ),
                      number(
                        'deceleration',
                        _mode == SimulationFlightMode.gps
                            ? 'Braking response (m/s²)'
                            : 'Drag at maximum speed (m/s²)',
                        .2,
                        50,
                      ),
                    ],
                    Text(
                      '$_controlHelp\n'
                      'Touch and hold the right half to show the second stick. ↑/↓ and right/left triggers or shoulders adjust throttle/height. R or controller A resets, Escape or B exits. '
                      'Release sticks to neutral when connecting or resuming. Web requires a supported standard-mapped gamepad and a secure context.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Simulation stays in memory. No flight track is recorded or exported automatically. '
                      'Online map and terrain requests still reveal the viewed area to their providers.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        if (!_form.currentState!.validate()) {
                          if (_mode == SimulationFlightMode.acro) {
                            _acroOptions.expand();
                          }
                          return;
                        }
                        Navigator.pop(
                          context,
                          SimulationSettings(
                            agl: read('agl')!,
                            maxSpeed: parameter('speed', .5, 100, 15),
                            climbSpeed: parameter('climb', .2, 30, 5),
                            acceleration: parameter('acceleration', .2, 50, 6),
                            deceleration: parameter('deceleration', .2, 50, 4),
                            droneId: _drone,
                            flightMode: _mode,
                            graphicsProfile: _graphics,
                            cameraTiltDegrees: parameter(
                              'cameraTilt',
                              0,
                              80,
                              0,
                            ),
                            acroThrustToWeight: parameter(
                              'acroThrustToWeight',
                              1.1,
                              12,
                              4,
                            ),
                            acroThrustCurve: parameter(
                              'acroThrustCurve',
                              0,
                              1,
                              1,
                            ),
                            acroMotorTimeConstant: parameter(
                              'acroMotorTimeConstant',
                              0,
                              .5,
                              .04,
                            ),
                            acroTerminalVelocity: parameter(
                              'acroTerminalVelocity',
                              5,
                              120,
                              35,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.flight_takeoff),
                      label: const Text('Spawn in map'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
