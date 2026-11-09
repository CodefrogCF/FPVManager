import 'package:flutter/material.dart';

import '../../core/database/fpv_database.dart';
import '../../core/database/repositories/drone_repository.dart';
import 'simulation_settings.dart';
import 'controller_settings.dart';
import 'controller_settings_fields.dart';
import '../globe/scene_time_control.dart';
import '../help/guides_screen.dart';

Future<SimulationSettings?> showSimulationSettings(
  BuildContext context, {
  required DroneRepository repository,
  SimulationSettings initial = const SimulationSettings(),
  required bool hasSelection,
  Widget? windControls,
  Widget? radioControls,
  bool configureOnly = false,
}) => showModalBottomSheet<SimulationSettings>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _Settings(
    repository: repository,
    initial: initial,
    hasSelection: hasSelection,
    windControls: windControls,
    radioControls: radioControls,
    configureOnly: configureOnly,
  ),
);

class _Settings extends StatefulWidget {
  const _Settings({
    required this.repository,
    required this.initial,
    required this.hasSelection,
    this.windControls,
    this.radioControls,
    this.configureOnly = false,
  });
  final DroneRepository repository;
  final SimulationSettings initial;
  final bool hasSelection;
  final Widget? windControls;
  final Widget? radioControls;
  final bool configureOnly;
  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  final _form = GlobalKey<FormState>();
  late var _sceneTime = widget.initial.sceneTime;
  late final _fields = <String, TextEditingController>{
    'agl': TextEditingController(text: '${widget.initial.agl}'),
    'cameraTilt': TextEditingController(
      text: '${widget.initial.cameraTiltDegrees}',
    ),
    'cameraFov': TextEditingController(
      text: '${widget.initial.cameraFovDegrees}',
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
    'acroRollRate': TextEditingController(
      text: '${widget.initial.acroRollRate}',
    ),
    'acroPitchRate': TextEditingController(
      text: '${widget.initial.acroPitchRate}',
    ),
    'acroYawRate': TextEditingController(text: '${widget.initial.acroYawRate}'),
    'acroRateExpo': TextEditingController(
      text: '${widget.initial.acroRateExpo}',
    ),
  };
  final _acroOptions = ExpansibleController();
  final _ratesOptions = ExpansibleController();
  final _cameraOptions = ExpansibleController();
  final _assistedOptions = ExpansibleController();
  List<Drone> _drones = [];
  int? _drone;
  bool _loading = true;
  late SimulationFlightMode _mode = widget.initial.flightMode;
  late SimulationGraphicsProfile _graphics = widget.initial.graphicsProfile;
  late SimulationHudStyle _hud = widget.initial.hudStyle;
  late bool _showCoordinates = widget.initial.showCoordinates;
  late ControllerSettings _controller = widget.initial.controller;
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
          () => _error =
              'Drohnenprofile nicht verfügbar. Manuelle Werte bleiben nutzbar.',
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
    _ratesOptions.dispose();
    _cameraOptions.dispose();
    _assistedOptions.dispose();
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
      ? 'Links: Bewegung · Rechts: Blick · E/Q: Höhe'
      : 'Links: Gas / Yaw · Rechts: Pitch / Roll';
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
      return 'Gültige Schubwerte für die Schwebeschätzung eingeben.';
    }
    final hover = SimulationSettings(
      acroThrustToWeight: ratio,
      acroThrustCurve: curve,
    ).acroHoverThrottle;
    return 'Schwebeschätzung: ${(hover * 100).toStringAsFixed(0)} % Gas';
  }

  String get _acroSpeedHelp {
    final thrust = read('acroThrustToWeight'),
        terminal = read('acroTerminalVelocity');
    if (thrust == null ||
        !thrust.isFinite ||
        thrust < 1.1 ||
        thrust > 12 ||
        terminal == null ||
        !terminal.isFinite ||
        terminal < 5 ||
        terminal > 120) {
      return 'Gültige Schub- und Widerstandswerte eingeben.';
    }
    final speed = SimulationSettings(
      acroThrustToWeight: thrust,
      acroTerminalVelocity: terminal,
    ).acroEstimatedLevelSpeedKmh;
    return 'Geschätztes Horizontaltempo bei Vollgas: ${speed.toStringAsFixed(0)} km/h. Höherer Luftwiderstand senkt diesen Wert; Sturzflug kann ihn überschreiten.';
  }

  bool _invalid(String key, double min, double max) {
    final value = read(key);
    return value == null || !value.isFinite || value < min || value > max;
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
      decoration: InputDecoration(labelText: label),
      validator: (_) {
        return _invalid(key, min, max)
            ? 'Wert von $min bis $max eingeben.'
            : null;
      },
    ),
  );
  Widget _group(
    String id,
    String title,
    IconData icon,
    List<Widget> children, {
    ExpansibleController? controller,
    Widget? subtitle,
  }) => ExpansionTile(
    key: PageStorageKey(id),
    controller: controller,
    maintainState: true,
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(top: 8, bottom: 12),
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle,
    children: children,
  );

  Widget _submit(BuildContext context) => FilledButton.icon(
    onPressed: () {
      if (!_form.currentState!.validate()) {
        if (_invalid('cameraFov', 50, 140) ||
            (_mode != SimulationFlightMode.gps &&
                _invalid('cameraTilt', 0, 80))) {
          _cameraOptions.expand();
        }
        if (_mode == SimulationFlightMode.acro) {
          if (_invalid('acroThrustToWeight', 1.1, 12) ||
              _invalid('acroThrustCurve', 0, 1) ||
              _invalid('acroMotorTimeConstant', 0, .5) ||
              _invalid('acroTerminalVelocity', 5, 120)) {
            _acroOptions.expand();
          }
          if (_invalid('acroRollRate', 10, 1500) ||
              _invalid('acroPitchRate', 10, 1500) ||
              _invalid('acroYawRate', 10, 1500) ||
              _invalid('acroRateExpo', 0, 1)) {
            _ratesOptions.expand();
          }
        } else if (_invalid('speed', .5, 100) ||
            _invalid('climb', .2, 30) ||
            _invalid('acceleration', .2, 50) ||
            _invalid('deceleration', .2, 50)) {
          _assistedOptions.expand();
        }
        return;
      }
      Navigator.pop(
        context,
        SimulationSettings(
          sceneTime: _sceneTime,
          agl: read('agl')!,
          maxSpeed: parameter('speed', .5, 100, 15),
          climbSpeed: parameter('climb', .2, 30, 5),
          acceleration: parameter('acceleration', .2, 50, 6),
          deceleration: parameter('deceleration', .2, 50, 4),
          droneId: _drone,
          flightMode: _mode,
          graphicsProfile: _graphics,
          hudStyle: _hud,
          showCoordinates: _showCoordinates,
          controller: _controller,
          cameraTiltDegrees: parameter('cameraTilt', 0, 80, 0),
          cameraFovDegrees: parameter('cameraFov', 50, 140, 90),
          acroThrustToWeight: parameter('acroThrustToWeight', 1.1, 12, 4),
          acroThrustCurve: parameter('acroThrustCurve', 0, 1, 1),
          acroMotorTimeConstant: parameter('acroMotorTimeConstant', 0, .5, .04),
          acroTerminalVelocity: parameter('acroTerminalVelocity', 5, 120, 22.5),
          acroRollRate: parameter('acroRollRate', 10, 1500, 180),
          acroPitchRate: parameter('acroPitchRate', 10, 1500, 180),
          acroYawRate: parameter('acroYawRate', 10, 1500, 180),
          acroRateExpo: parameter('acroRateExpo', 0, 1, 0),
        ),
      );
    },
    icon: const Icon(Icons.flight_takeoff),
    label: Text(widget.configureOnly ? 'Übernehmen' : 'Flug starten'),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FractionallySizedBox(
      heightFactor: .9,
      child: LayoutBuilder(
        builder: (context, constraints) => Form(
          key: _form,
          child: Column(
            children: [
              if (constraints.maxHeight -
                      MediaQuery.viewInsetsOf(context).bottom >=
                  180)
                ListTile(
                  title: Text(
                    widget.configureOnly ? 'Flug einstellen' : 'Flugsimulator',
                  ),
                  subtitle: const Text(
                    'Simulation · keine realen Flugeigenschaften',
                  ),
                  trailing: IconButton(
                    tooltip: 'Flugeinstellungen schließen',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!widget.configureOnly)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            widget.hasSelection
                                ? 'Start am markierten Punkt.'
                                : 'Start unter der Kartenmitte.',
                          ),
                        ),
                      DropdownButtonFormField<SimulationFlightMode>(
                        initialValue: _mode,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Flugmodus',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: SimulationFlightMode.gps,
                            child: Text(
                              'GPS · unterstützt',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: SimulationFlightMode.angle,
                            child: Text(
                              'Angle · selbststabilisierend',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: SimulationFlightMode.acro,
                            child: Text(
                              'Acro · freie Drehraten',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _mode = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_loading) const LinearProgressIndicator(),
                      if (_error != null) Text(_error!),
                      DropdownButtonFormField<int>(
                        key: ValueKey(_drone),
                        initialValue: _drone,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Drohnenprofil',
                        ),
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text('Manuelle Werte'),
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
                          final d = _drones
                              .where((d) => d.id == id)
                              .firstOrNull;
                          final settings = d == null
                              ? const SimulationSettings()
                              : SimulationSettings.fromDrone(d);
                          _fields['speed']!.text = '${settings.maxSpeed}';
                          _fields['climb']!.text = '${settings.climbSpeed}';
                        }),
                      ),
                      const SizedBox(height: 12),
                      number('agl', 'Starthöhe über Grund (m)', 1, 1000),
                      _group(
                        'simulation-camera-options',
                        'Kamera & HUD',
                        Icons.videocam_outlined,
                        [
                          if (_mode != SimulationFlightMode.gps)
                            number(
                              'cameraTilt',
                              'Kameraneigung nach oben (°)',
                              0,
                              80,
                            ),
                          number(
                            'cameraFov',
                            'Horizontales Sichtfeld (°)',
                            50,
                            140,
                          ),
                          DropdownButtonFormField<SimulationHudStyle>(
                            key: const ValueKey('simulation-hud'),
                            initialValue: _hud,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'HUD-Stil',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: SimulationHudStyle.goggles,
                                child: Text('Goggles'),
                              ),
                              DropdownMenuItem(
                                value: SimulationHudStyle.betaflight,
                                child: Text('Betaflight'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) setState(() => _hud = value);
                            },
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Koordinaten im HUD anzeigen'),
                            value: _showCoordinates,
                            onChanged: (value) =>
                                setState(() => _showCoordinates = value),
                          ),
                        ],
                        controller: _cameraOptions,
                      ),
                      _group(
                        'simulation-display-options',
                        'Grafik & Tageszeit',
                        Icons.tune,
                        [
                          DropdownButtonFormField<SimulationGraphicsProfile>(
                            key: const ValueKey('simulation-graphics'),
                            initialValue: _graphics,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Grafikprofil',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: SimulationGraphicsProfile.quality,
                                child: Text('Quality'),
                              ),
                              DropdownMenuItem(
                                value: SimulationGraphicsProfile.balanced,
                                child: Text('Balanced'),
                              ),
                              DropdownMenuItem(
                                value: SimulationGraphicsProfile.performance,
                                child: Text('Performance'),
                              ),
                              DropdownMenuItem(
                                value: SimulationGraphicsProfile.compatibility,
                                child: Text('Compatibility'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _graphics = value);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          SceneTimeControl(
                            value: _sceneTime,
                            onChanged: (value) =>
                                setState(() => _sceneTime = value),
                          ),
                        ],
                      ),
                      ControllerSettingsFields(
                        initial: _controller,
                        onChanged: (value) => _controller = value,
                      ),
                      if (_mode == SimulationFlightMode.acro) ...[
                        ExpansionTile(
                          key: const ValueKey('simulation-acro-rates'),
                          controller: _ratesOptions,
                          maintainState: true,
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(top: 8),
                          leading: const Icon(Icons.rotate_right),
                          title: const Text('Acro-Drehraten'),
                          subtitle: Text(
                            'Roll ${_fields['acroRollRate']!.text} · Pitch ${_fields['acroPitchRate']!.text} · Yaw ${_fields['acroYawRate']!.text} °/s',
                          ),
                          children: [
                            number(
                              'acroRollRate',
                              'Roll maximal (°/s)',
                              10,
                              1500,
                            ),
                            number(
                              'acroPitchRate',
                              'Pitch maximal (°/s)',
                              10,
                              1500,
                            ),
                            number(
                              'acroYawRate',
                              'Yaw maximal (°/s)',
                              10,
                              1500,
                            ),
                            number(
                              'acroRateExpo',
                              'Expo (0 linear, 1 weich)',
                              0,
                              1,
                            ),
                          ],
                        ),
                        ExpansionTile(
                          key: const ValueKey('simulation-acro-physics'),
                          controller: _acroOptions,
                          maintainState: true,
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(top: 8),
                          leading: const Icon(Icons.speed),
                          title: const Text('Acro-Physik'),
                          subtitle: Text(_acroHoverHelp),
                          children: [
                            Text(_acroSpeedHelp),
                            number(
                              'acroThrustToWeight',
                              'Maximaler Schub / Gewicht',
                              1.1,
                              12,
                            ),
                            number(
                              'acroThrustCurve',
                              'Schubkurve (0 linear, 1 quadratisch)',
                              0,
                              1,
                            ),
                            number(
                              'acroMotorTimeConstant',
                              'Motor-Ansprechzeit (s)',
                              0,
                              .5,
                            ),
                            number(
                              'acroTerminalVelocity',
                              'Endgeschwindigkeit im freien Fall (m/s)',
                              5,
                              120,
                            ),
                          ],
                        ),
                      ] else
                        _group(
                          'simulation-assisted-options',
                          'Flugeigenschaften',
                          Icons.speed,
                          [
                            number(
                              'speed',
                              'Höchstgeschwindigkeit (m/s)',
                              .5,
                              100,
                            ),
                            number(
                              'climb',
                              'Steigen / Sinken maximal (m/s)',
                              .2,
                              30,
                            ),
                            number(
                              'acceleration',
                              _mode == SimulationFlightMode.gps
                                  ? 'Beschleunigung (m/s²)'
                                  : 'Zusätzlicher Schub (m/s²)',
                              .2,
                              50,
                            ),
                            number(
                              'deceleration',
                              _mode == SimulationFlightMode.gps
                                  ? 'Bremswirkung (m/s²)'
                                  : 'Widerstand bei Höchsttempo (m/s²)',
                              .2,
                              50,
                            ),
                          ],
                          controller: _assistedOptions,
                        ),
                      if (widget.windControls != null ||
                          widget.radioControls != null)
                        _group(
                          'simulation-environment-options',
                          'Wind & Funk',
                          Icons.air,
                          [
                            if (widget.windControls != null)
                              widget.windControls!,
                            if (widget.radioControls != null)
                              widget.radioControls!,
                          ],
                        ),
                      _group(
                        'simulation-help',
                        'Hilfe & Hinweise',
                        Icons.help_outline,
                        [
                          const GuideLink(GuideTopic.controls),
                          Text(_controlHelp),
                          Text(switch (_mode) {
                            SimulationFlightMode.gps => 'GPS bremst automatisch. Linker Stick: Bewegung; rechter Stick: Blickrichtung.',
                            SimulationFlightMode.angle => 'Angle stabilisiert die Lage und begrenzt die Neigung auf 50°. Bei Neigung ist mehr Gas zum Halten der Höhe nötig.',
                            SimulationFlightMode.acro => 'Acro hat keine Selbststabilisierung oder Höhenhaltung. Schub folgt der Drohnenlage; geringer Schub lässt sie frei fallen.',
                          }),
                          const SizedBox(height: 8),
                          const Text(
                            'Zum Verbinden oder Fortsetzen Gas auf null und die übrigen Sticks zentrieren. R / Controller A setzt zurück; Escape / B beendet den Flug. Ein Moduswechsel startet am Ausgangspunkt neu.',
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Drohnenprofile übernehmen Geschwindigkeit und Steigrate für Angle und GPS. Acro-Physik und Beschleunigung bleiben geschätzte Modellwerte. Die Kamera beeinflusst nur die Ansicht.',
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Gelände und unterstützte Modellflächen können die Bewegung stoppen. Hindernisse und Kollisionen sind nicht vollständig erfasst. Die Simulation ist keine reale Leistungs- oder Sicherheitsprüfung.',
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Keine automatische Aufzeichnung oder Ausfuhr. Online-Karten- und Geländeabrufe übermitteln den betrachteten Bereich an die Anbieter.',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.viewInsetsOf(context).bottom + 12,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: _submit(context),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
