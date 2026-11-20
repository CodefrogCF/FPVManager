import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import '../../core/database/fpv_database.dart';
import '../../core/database/repositories/drone_repository.dart';
import '../../core/database/repositories/battery_repository.dart';
import 'simulation_battery_profile.dart';
import 'simulation_settings.dart';
import 'signal_hud_settings.dart';
import 'failsafe_settings.dart';
import 'controller_settings.dart';
import 'controller_settings_fields.dart';
import '../globe/scene_time_control.dart';
import '../help/guides_screen.dart';

Future<SimulationSettings?> showSimulationSettings(
  BuildContext context, {
  required DroneRepository repository,
  BatteryRepository? batteryRepository,
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
    batteryRepository: batteryRepository,
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
    this.batteryRepository,
    required this.initial,
    required this.hasSelection,
    this.windControls,
    this.radioControls,
    this.configureOnly = false,
  });
  final DroneRepository repository;
  final BatteryRepository? batteryRepository;
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
    'batteryCharge': TextEditingController(
      text: '${widget.initial.batteryProfile?.chargePercent ?? 100}',
    ),
    'batteryLow': TextEditingController(
      text: '${widget.initial.lowBatteryCellVoltage}',
    ),
    'batteryCritical': TextEditingController(
      text: '${widget.initial.criticalBatteryCellVoltage}',
    ),
    'batterySag': TextEditingController(
      text: '${widget.initial.batterySagResistanceOhmsPerCell}',
    ),
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
  final _batteryOptions = ExpansibleController();
  final _signalOptions = ExpansibleController();
  final _assistedOptions = ExpansibleController();
  List<Drone> _drones = [];
  List<Battery> _batteries = [];
  int? _batteryId;
  late bool _showBatteryVoltage = widget.initial.showBatteryVoltage;
  late bool _showBatteryCellVoltage = widget.initial.showBatteryCellVoltage;
  late bool _batteryUseChemistryThresholds =
      widget.initial.batteryUseChemistryThresholds;
  late SignalHudSettings _signalHud = widget.initial.signalHud;
  late bool _failsafeEnabled = widget.initial.failsafe.enabled;
  late String _failsafeMode = widget.initial.failsafe.mode;
  int? _drone;
  bool _loading = true;
  late SimulationFlightMode _mode = widget.initial.flightMode;
  late SimulationPhysicsModel _physicsModel = widget.initial.physicsModel;
  late int _physicsStepHz = widget.initial.physicsStepHz;
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
      List<Battery> batteries = [];
      try {
        batteries =
            await widget.batteryRepository?.getAllBatteries() ?? <Battery>[];
      } catch (_) {
        // Battery HUD is optional; drone settings must remain available.
      }
      if (!mounted) return;
      setState(() {
        _drones = drones;
        _batteries = batteries.where((battery) => !battery.isType).toList();
        _batteryId =
            _batteries.any(
              (battery) =>
                  battery.id == widget.initial.batteryProfile?.batteryId,
            )
            ? widget.initial.batteryProfile?.batteryId
            : null;
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
    _batteryOptions.dispose();
    _signalOptions.dispose();
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

  String get _controlHelp => context.translate(
    _mode == SimulationFlightMode.gps
        ? 'Links: Bewegung · Rechts: Blick · E/Q: Höhe'
        : 'Links: Gas / Yaw · Rechts: Pitch / Roll',
  );
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
      return context.localized(
        'Gültige Schubwerte für die Schwebeschätzung eingeben.',
        (l10n) => l10n.simulationGueltigeSchubwerteFuerDie9f739082,
      );
    }
    final hover = SimulationSettings(
      acroThrustToWeight: ratio,
      acroThrustCurve: curve,
    ).acroHoverThrottle;
    return context.localizedWithArgs('Schwebeschätzung: {0} % Gas', [
      (hover * 100).toStringAsFixed(0),
    ], (l10n, value) => l10n.simulationSchwebeschaetzungGas487da692(value(0)));
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
      return context.localized(
        'Gültige Schub- und Widerstandswerte eingeben.',
        (l10n) => l10n.simulationGueltigeSchubUndWiderstandswerted87ecf7c,
      );
    }
    final speed = SimulationSettings(
      acroThrustToWeight: thrust,
      acroTerminalVelocity: terminal,
    ).acroEstimatedLevelSpeedKmh;
    return context.localizedWithArgs(
      'Geschätztes Horizontaltempo bei Vollgas: {0} km/h. Höherer Luftwiderstand senkt diesen Wert; Sturzflug kann ihn überschreiten.',
      [speed.toStringAsFixed(0)],
      (l10n, value) => l10n
          .simulationGeschaetztesHorizontaltempoBeiVollgasbf685b25(value(0)),
    );
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
      decoration: InputDecoration(labelText: context.translate(label)),
      validator: (_) {
        return _invalid(key, min, max)
            ? context.localizedWithArgs(
                'Wert von {0} bis {1} eingeben.',
                [min, max],
                (l10n, value) => l10n.simulationWertVonBisEingeben87edf0e9(
                  value(0),
                  value(1),
                ),
              )
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
    title: Text(context.translate(title)),
    subtitle: subtitle,
    children: children,
  );

  Widget _submit(BuildContext context) => FilledButton.icon(
    onPressed: () {
      if ((read('batteryLow') ?? 0) <= (read('batteryCritical') ?? 0)) {
        _batteryOptions.expand();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.localized(
                'Die niedrige Zellspannung muss höher als die kritische Zellspannung sein.',
                (l10n) => l10n.simulationDieNiedrigeZellspannungMuss653c3f34,
              ),
            ),
          ),
        );
        return;
      }
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
          physicsModel: _physicsModel,
          physicsStepHz: _physicsStepHz,
          graphicsProfile: _graphics,
          hudStyle: _hud,
          showCoordinates: _showCoordinates,
          signalHud: _signalHud,
          failsafe: FailsafeSettings.fromJson({
            ...widget.initial.failsafe.toJson(),
            'enabled': _failsafeEnabled,
            'mode': _failsafeMode,
          }),
          showBatteryVoltage: _showBatteryVoltage,
          showBatteryCellVoltage: _showBatteryCellVoltage,
          lowBatteryCellVoltage: read('batteryLow')!,
          criticalBatteryCellVoltage: read('batteryCritical')!,
          batterySagResistanceOhmsPerCell: read('batterySag')!,
          batteryUseChemistryThresholds: _batteryUseChemistryThresholds,
          batteryProfile: _batteryId == null
              ? null
              : SimulationBatteryProfile.fromProfiles(
                  battery: _batteries.firstWhere(
                    (battery) => battery.id == _batteryId,
                  ),
                  drone: _drones
                      .where((drone) => drone.id == _drone)
                      .firstOrNull,
                  chargePercent: read('batteryCharge')!,
                ),
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
    label: Text(
      widget.configureOnly
          ? context.localized(
              "Übernehmen",
              (l10n) => l10n.simulationUbernehmen59430842,
            )
          : context.localized(
              "Flug starten",
              (l10n) => l10n.simulationFlugStarten8846a2e4,
            ),
    ),
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
                    widget.configureOnly
                        ? context.localized(
                            "Flug einstellen",
                            (l10n) => l10n.simulationFlugEinstellenf142a101,
                          )
                        : context.localized(
                            "Flugsimulator",
                            (l10n) => l10n.simulationFlugsimulatore761527e,
                          ),
                  ),
                  subtitle: Text(
                    context.localized(
                      "Simulation · keine realen Flugeigenschaften",
                      (l10n) => l10n
                          .simulationSimulationKeineRealenFlugeigenschaften596363e0,
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: context.localized(
                      "Flugeinstellungen schließen",
                      (l10n) =>
                          l10n.simulationFlugeinstellungenSchliessen974d8874,
                    ),
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
                                ? context.localized(
                                    "Start am markierten Punkt.",
                                    (l10n) => l10n
                                        .simulationStartAmMarkiertenPunktded1ae8f,
                                  )
                                : context.localized(
                                    "Start unter der Kartenmitte.",
                                    (l10n) => l10n
                                        .simulationStartUnterDerKartenmitted55a2a7c,
                                  ),
                          ),
                        ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          context.localized(
                            'Simulierter RC-Failsafe',
                            (l10n) => l10n.failsafeSimulationTitle,
                          ),
                        ),
                        subtitle: Text(
                          context.localized(
                            'Nur bei explizit simuliertem RC-Verlust. Keine reale RF-Prognose.',
                            (l10n) => l10n.failsafeSimulationDisclaimer,
                          ),
                        ),
                        value: _failsafeEnabled,
                        onChanged: (value) =>
                            setState(() => _failsafeEnabled = value),
                      ),
                      if (_failsafeEnabled)
                        DropdownButtonFormField<String>(
                          initialValue: _failsafeMode,
                          decoration: InputDecoration(
                            labelText: context.localized(
                              'Failsafe-Aktion',
                              (l10n) => l10n.failsafeSimulationAction,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'hold',
                              child: Text('Hold'),
                            ),
                            DropdownMenuItem(
                              value: 'descend',
                              child: Text('Descend'),
                            ),
                            DropdownMenuItem(
                              value: 'gpsRescue',
                              child: Text('GPS Rescue'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _failsafeMode = value);
                            }
                          },
                        ),
                      DropdownButtonFormField<SimulationFlightMode>(
                        initialValue: _mode,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: context.localized(
                            "Flugmodus",
                            (l10n) => l10n.simulationFlugmodus699cac43,
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: SimulationFlightMode.gps,
                            child: Text(
                              context.localized(
                                "GPS · unterstützt",
                                (l10n) =>
                                    l10n.simulationGpsUnterstuetzt4fba7ae2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: SimulationFlightMode.angle,
                            child: Text(
                              context.localized(
                                "Angle · selbststabilisierend",
                                (l10n) => l10n
                                    .simulationAngleSelbststabilisierenddb3cdc71,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: SimulationFlightMode.acro,
                            child: Text(
                              context.localized(
                                "Acro · freie Drehraten",
                                (l10n) =>
                                    l10n.simulationAcroFreieDrehratena37d7b4c,
                              ),
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
                      DropdownButtonFormField<SimulationPhysicsModel>(
                        key: const ValueKey('simulation-physics-model'),
                        initialValue: _physicsModel,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText:
                              context.fpvStrings.simulationPhysicsModelTitle,
                          helperText:
                              context.fpvStrings.simulationPhysicsModelHint,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: SimulationPhysicsModel.legacy,
                            child: Text('Legacy'),
                          ),
                          DropdownMenuItem(
                            value: SimulationPhysicsModel.advanced,
                            child: Text('Advanced'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _physicsModel = value);
                          }
                        },
                      ),
                      if (_physicsModel == SimulationPhysicsModel.advanced)
                        DropdownButtonFormField<int>(
                          key: const ValueKey('simulation-physics-step-hz'),
                          initialValue: _physicsStepHz,
                          decoration: InputDecoration(
                            labelText:
                                context.fpvStrings.simulationPhysicsStepRate,
                          ),
                          items: const [
                            DropdownMenuItem(value: 60, child: Text('60 Hz')),
                            DropdownMenuItem(value: 120, child: Text('120 Hz')),
                            DropdownMenuItem(value: 240, child: Text('240 Hz')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _physicsStepHz = value);
                            }
                          },
                        ),
                      const SizedBox(height: 12),
                      if (_loading) const LinearProgressIndicator(),
                      if (_error != null) Text(context.translate(_error!)),
                      DropdownButtonFormField<int>(
                        key: ValueKey(_drone),
                        initialValue: _drone,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: context.localized(
                            "Drohnenprofil",
                            (l10n) => l10n.simulationDrohnenprofil2c80fbb6,
                          ),
                        ),
                        items: [
                          DropdownMenuItem<int>(
                            value: null,
                            child: Text(
                              context.localized(
                                "Manuelle Werte",
                                (l10n) => l10n.simulationManuelleWerte24267a01,
                              ),
                            ),
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
                            decoration: InputDecoration(
                              labelText: context.localized(
                                'HUD-Stil',
                                (l10n) => l10n.simulationHudStil9e126e51,
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: SimulationHudStyle.goggles,
                                child: Text(
                                  context.localized(
                                    "Goggles",
                                    (l10n) => l10n.simulationGoggles0b34f86f,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: SimulationHudStyle.betaflight,
                                child: Text(
                                  context.localized(
                                    "Betaflight",
                                    (l10n) => l10n.simulationBetaflightaaa2dc4d,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) setState(() => _hud = value);
                            },
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              context.localized(
                                "Koordinaten im HUD anzeigen",
                                (l10n) => l10n
                                    .simulationKoordinatenImHudAnzeigen5180787d,
                              ),
                            ),
                            value: _showCoordinates,
                            onChanged: (value) =>
                                setState(() => _showCoordinates = value),
                          ),
                        ],
                        controller: _cameraOptions,
                      ),
                      _group(
                        'simulation-signal-hud-options',
                        'Simuliertes Funksignal im HUD',
                        Icons.network_check,
                        [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              context.localized(
                                'DJI: Signalwarnung am unteren Bildrand',
                                (l10n) => l10n.signalHudDjiWarning,
                              ),
                            ),
                            value: _signalHud.djiWarning,
                            onChanged: (v) => setState(
                              () => _signalHud = _signalHud.copyWith(
                                djiWarning: v,
                              ),
                            ),
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              context.localized(
                                'Betaflight: Signalbalken anzeigen',
                                (l10n) => l10n.signalHudBetaflightBars,
                              ),
                            ),
                            value: _signalHud.betaflightBars,
                            onChanged: (v) => setState(
                              () => _signalHud = _signalHud.copyWith(
                                betaflightBars: v,
                              ),
                            ),
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              context.localized(
                                'Betaflight: analoges Videorauschen',
                                (l10n) => l10n.signalHudAnalogNoise,
                              ),
                            ),
                            value: _signalHud.analogNoise,
                            onChanged: (v) => setState(
                              () => _signalHud = _signalHud.copyWith(
                                analogNoise: v,
                              ),
                            ),
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              context.localized(
                                'Geländerisiko als Videoeffekt illustrieren',
                                (l10n) => l10n.signalHudTerrainIllustration,
                              ),
                            ),
                            subtitle: Text(
                              context.localized(
                                'Nur eine Illustration, keine RF-Messung. RC-Signal bleibt unbekannt.',
                                (l10n) => l10n.signalHudTerrainDisclaimer,
                              ),
                            ),
                            value: _signalHud.terrainIllustration,
                            onChanged: (v) => setState(
                              () => _signalHud = _signalHud.copyWith(
                                terrainIllustration: v,
                              ),
                            ),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              context.localized(
                                'Intensität des Bildrauschens',
                                (l10n) => l10n.signalHudIntensity,
                              ),
                            ),
                            subtitle: Slider(
                              value: _signalHud.analogIntensity,
                              min: 0,
                              max: 1,
                              divisions: 20,
                              label:
                                  '${(_signalHud.analogIntensity * 100).round()} %',
                              onChanged: (v) => setState(
                                () => _signalHud = _signalHud.copyWith(
                                  analogIntensity: v,
                                ),
                              ),
                            ),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              context.localized(
                                'Schwaches Signal – Schwelle',
                                (l10n) => l10n.signalHudWeakThreshold,
                              ),
                            ),
                            subtitle: Slider(
                              value: _signalHud.weakThreshold,
                              min: 0,
                              max: 1,
                              divisions: 100,
                              label:
                                  '${(_signalHud.weakThreshold * 100).round()} %',
                              onChanged: (v) {
                                if (v > _signalHud.criticalThreshold) {
                                  setState(
                                    () => _signalHud = _signalHud.copyWith(
                                      weakThreshold: v,
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              context.localized(
                                'Kritisches Signal – Schwelle',
                                (l10n) => l10n.signalHudCriticalThreshold,
                              ),
                            ),
                            subtitle: Slider(
                              value: _signalHud.criticalThreshold,
                              min: 0,
                              max: 1,
                              divisions: 100,
                              label:
                                  '${(_signalHud.criticalThreshold * 100).round()} %',
                              onChanged: (v) {
                                if (v > _signalHud.lostThreshold &&
                                    v < _signalHud.weakThreshold) {
                                  setState(
                                    () => _signalHud = _signalHud.copyWith(
                                      criticalThreshold: v,
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              context.localized(
                                'Signalverlust – Schwelle',
                                (l10n) => l10n.signalHudLostThreshold,
                              ),
                            ),
                            subtitle: Slider(
                              value: _signalHud.lostThreshold,
                              min: 0,
                              max: 1,
                              divisions: 100,
                              label:
                                  '${(_signalHud.lostThreshold * 100).round()} %',
                              onChanged: (v) {
                                if (v < _signalHud.criticalThreshold) {
                                  setState(
                                    () => _signalHud = _signalHud.copyWith(
                                      lostThreshold: v,
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                        controller: _signalOptions,
                      ),
                      _group(
                        'simulation-battery-options',
                        'Simulierter Akku (HUD)',
                        Icons.battery_charging_full,
                        [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              context.localized(
                                'Geschätzte Akkuspannung anzeigen',
                                (l10n) => l10n
                                    .simulationGeschaetzteAkkuspannungAnzeigen3fc4417b,
                              ),
                            ),
                            subtitle: Text(
                              context.localized(
                                'SIM: Modellwert, keine echte Akkutelemetrie.',
                                (l10n) =>
                                    l10n.commonSimModellwertKeineEchte2ec26181,
                              ),
                            ),
                            value: _showBatteryVoltage,
                            onChanged: (value) =>
                                setState(() => _showBatteryVoltage = value),
                          ),
                          DropdownButtonFormField<int>(
                            key: ValueKey('simulation-battery-$_batteryId'),
                            initialValue: _batteryId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: context.localized(
                                'Akkuprofil',
                                (l10n) => l10n.simulationAkkuprofilf5c68edf,
                              ),
                            ),
                            items: [
                              DropdownMenuItem<int>(
                                value: null,
                                child: Text(
                                  context.localized(
                                    'Kein Akku ausgewählt',
                                    (l10n) => l10n
                                        .simulationKeinAkkuAusgewaehltce2c46d1,
                                  ),
                                ),
                              ),
                              for (final battery in _batteries)
                                DropdownMenuItem(
                                  value: battery.id,
                                  child: Text(
                                    '${battery.name} (${battery.cellCount}S · ${battery.capacityMah} mAh)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (id) => setState(() {
                              _batteryId = id;
                              final selected = _batteries
                                  .where((battery) => battery.id == id)
                                  .firstOrNull;
                              _fields['batteryCharge']!.text =
                                  '${selected?.chargePercent ?? 100}';
                            }),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.localized(
                              'Fehlen im Akku die Startladungsdaten, wird 100 % als editierbare Annahme verwendet. Für eine Spannungsschätzung benötigt das Drohnenprofil Hover- und Cruise-Leistung sowie Cruise-Geschwindigkeit.',
                              (l10n) => l10n.commonFehlenImAkkuDie64009d59,
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          number(
                            'batteryCharge',
                            'Startladung (%) · Schätzung',
                            0,
                            100,
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              context.localized(
                                'Zellspannung zusätzlich anzeigen',
                                (l10n) => l10n
                                    .simulationZellspannungZusaetzlichAnzeigenb25b8602,
                              ),
                            ),
                            value: _showBatteryCellVoltage,
                            onChanged: (value) =>
                                setState(() => _showBatteryCellVoltage = value),
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              context.localized(
                                'Chemieabhängige Warnschwellen (SIM)',
                                (l10n) => l10n.batteryChemistryAutoThresholds,
                              ),
                            ),
                            subtitle: Text(
                              context.localized(
                                'Orientiert sich an der gewählten Akkuchemie; für eigene Spannungen deaktivieren.',
                                (l10n) =>
                                    l10n.batteryChemistryAutoThresholdsHint,
                              ),
                            ),
                            value: _batteryUseChemistryThresholds,
                            onChanged: (value) => setState(
                              () => _batteryUseChemistryThresholds = value,
                            ),
                          ),
                          number(
                            'batteryLow',
                            'Warnung Zellspannung (V)',
                            .6,
                            4.5,
                          ),
                          number(
                            'batteryCritical',
                            'Kritische Zellspannung (V)',
                            .5,
                            4.4,
                          ),
                          number(
                            'batterySag',
                            context
                                .fpvStrings
                                .batteryChemistryResistanceAutomatic,
                            0,
                            .1,
                          ),
                        ],
                        controller: _batteryOptions,
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
                            decoration: InputDecoration(
                              labelText: context.localized(
                                "Grafikprofil",
                                (l10n) => l10n.simulationGrafikprofile6062f50,
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: SimulationGraphicsProfile.quality,
                                child: Text(
                                  context.localized(
                                    "Quality",
                                    (l10n) => l10n.simulationQualitya60f2c73,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: SimulationGraphicsProfile.balanced,
                                child: Text(
                                  context.localized(
                                    "Balanced",
                                    (l10n) => l10n.simulationBalanced03342dbb,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: SimulationGraphicsProfile.performance,
                                child: Text(
                                  context.localized(
                                    "Performance",
                                    (l10n) =>
                                        l10n.simulationPerformance63c90455,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: SimulationGraphicsProfile.compatibility,
                                child: Text(
                                  context.localized(
                                    "Compatibility",
                                    (l10n) =>
                                        l10n.simulationCompatibility5d60c7dd,
                                  ),
                                ),
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
                          title: Text(
                            context.localized(
                              "Acro-Drehraten",
                              (l10n) => l10n.simulationAcroDrehratenf7001f19,
                            ),
                          ),
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
                          title: Text(
                            context.localized(
                              "Acro-Physik",
                              (l10n) => l10n.simulationAcroPhysikdf296beb,
                            ),
                          ),
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
                            SimulationFlightMode.gps => context.localized(
                              "GPS bremst automatisch. Linker Stick: Bewegung; rechter Stick: Blickrichtung.",
                              (l10n) => l10n
                                  .simulationGpsBremstAutomatischLinker62b42159,
                            ),
                            SimulationFlightMode.angle => context.localized(
                              "Angle stabilisiert die Lage und begrenzt die Neigung auf 50°. Bei Neigung ist mehr Gas zum Halten der Höhe nötig.",
                              (l10n) => l10n
                                  .simulationAngleStabilisiertDieLage73f2f597,
                            ),
                            SimulationFlightMode.acro => context.localized(
                              "Acro hat keine Selbststabilisierung oder Höhenhaltung. Schub folgt der Drohnenlage; geringer Schub lässt sie frei fallen.",
                              (l10n) => l10n
                                  .simulationAcroHatKeineSelbststabilisierung83a2e981,
                            ),
                          }),
                          const SizedBox(height: 8),
                          Text(
                            context.localized(
                              "Zum Verbinden oder Fortsetzen Gas auf null und die übrigen Sticks zentrieren. R / Controller A setzt zurück; Escape / B beendet den Flug. Ein Moduswechsel startet am Ausgangspunkt neu.",
                              (l10n) => l10n
                                  .simulationZumVerbindenOderFortsetzenb43ff5ab,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.localized(
                              "Drohnenprofile übernehmen Geschwindigkeit und Steigrate für Angle und GPS. Acro-Physik und Beschleunigung bleiben geschätzte Modellwerte. Die Kamera beeinflusst nur die Ansicht.",
                              (l10n) => l10n
                                  .simulationDrohnenprofileUebernehmenGeschwindigkeitUndb7b1010f,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.localized(
                              "Gelände und unterstützte Modellflächen können die Bewegung stoppen. Hindernisse und Kollisionen sind nicht vollständig erfasst. Die Simulation ist keine reale Leistungs- oder Sicherheitsprüfung.",
                              (l10n) => l10n
                                  .simulationGelaendeUndUnterstuetzteModellflaechen2d8c2c0b,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.localized(
                              "Keine automatische Aufzeichnung oder Ausfuhr. Online-Karten- und Geländeabrufe übermitteln den betrachteten Bereich an die Anbieter.",
                              (l10n) => l10n
                                  .simulationKeineAutomatischeAufzeichnungOder98df029c,
                            ),
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
