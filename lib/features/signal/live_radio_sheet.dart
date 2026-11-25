import 'package:flutter/foundation.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/database/fpv_database.dart';
import '../../core/database/repositories/radio_equipment_repository.dart';

import 'package:flutter/material.dart';

import '../../core/geo/geo_coordinate_service.dart';
import '../../core/models/local_csv_file.dart';
import '../../core/models/signal_settings.dart';
import '../globe/globe_controller.dart';
import '../routes/route_start_sheet.dart';
import '../spots/data/spot_repository.dart';
import 'live_radio_controller.dart';
import 'rf_profile_settings.dart';
import 'rf_equipment_adapter.dart';
import 'surface_csv.dart';

class LiveRadioLauncher extends StatelessWidget {
  const LiveRadioLauncher({
    super.key,
    required this.globe,
    this.spots,
    this.equipment,
  });
  final GlobeController globe;
  final SpotRepository? spots;
  final RadioEquipmentRepository? equipment;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () => showLiveRadioSettings(
      context,
      globe,
      spots: spots,
      equipment: equipment,
    ),
    icon: const Icon(Icons.settings_input_antenna),
    label: Text(
      context.localized(
        "Radio line of sight",
        (l10n) => l10n.signalRadioLineOfSight3d11d898,
      ),
    ),
  );
}

Future<void> showLiveRadioSettings(
  BuildContext context,
  GlobeController globe, {
  SpotRepository? spots,
  RadioEquipmentRepository? equipment,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) =>
      _LiveRadioSheet(globe: globe, spots: spots, equipment: equipment),
);

class _LiveRadioSheet extends StatefulWidget {
  const _LiveRadioSheet({required this.globe, this.spots, this.equipment});
  final GlobeController globe;
  final SpotRepository? spots;
  final RadioEquipmentRepository? equipment;
  @override
  State<_LiveRadioSheet> createState() => _LiveRadioSheetState();
}

class _LiveRadioSheetState extends State<_LiveRadioSheet> {
  LiveRadioController get c => widget.globe.liveRadio;
  late bool _enabled = c.settings.enabled,
      _spawn = c.settings.useSpawn,
      _marker = c.settings.showGroundStationMarker,
      _path = c.settings.showSignalPath,
      _surfacesEnabled = c.settings.signal.useSurfaces,
      _rfEnabled = c.settings.rfProfiles.enabled;
  late RfScenario _videoScenario = c.settings.rfProfiles.videoScenario;
  late RfScenario _controlScenario = c.settings.rfProfiles.controlScenario;
  late List<SurfaceObservation> _surfaces = c.settings.signal.surfaces;
  late final _fields = <String, TextEditingController>{
    'latitude': TextEditingController(
      text: '${c.settings.signal.pilot.latitude}',
    ),
    'longitude': TextEditingController(
      text: '${c.settings.signal.pilot.longitude}',
    ),
    'antenna': TextEditingController(
      text: '${c.settings.signal.antennaHeight}',
    ),
    'frequency': TextEditingController(
      text: '${c.settings.signal.frequencyMhz}',
    ),
    'fraction': TextEditingController(
      text: '${c.settings.signal.clearanceFraction * 100}',
    ),
    for (final field in [
      ('videoFrequency', c.settings.rfProfiles.video.frequencyMhz),
      ('videoPower', c.settings.rfProfiles.video.eirpDbm),
      ('videoThreshold', c.settings.rfProfiles.video.receiverThresholdDbm),
      ('videoFade', c.settings.rfProfiles.video.fadeMarginDb),
      ('rcFrequency', c.settings.rfProfiles.control.frequencyMhz),
      ('rcPower', c.settings.rfProfiles.control.eirpDbm),
      ('rcThreshold', c.settings.rfProfiles.control.receiverThresholdDbm),
      ('rcFade', c.settings.rfProfiles.control.fadeMarginDb),
    ])
      field.$1: TextEditingController(text: '${field.$2}'),
  };
  bool _working = false;
  String? _error;
  @override
  void dispose() {
    for (final f in _fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  double _value(String key) =>
      double.parse(_fields[key]!.text.trim().replaceAll(',', '.'));

  double? _theoreticalRangeKm(String prefix) {
    try {
      final profile = RfBandProfile(
        frequencyMhz: _value('${prefix}Frequency'),
        eirpDbm: _value('${prefix}Power'),
        receiverThresholdDbm: _value('${prefix}Threshold'),
        fadeMarginDb: _value('${prefix}Fade'),
      );
      return profile.theoreticalFreeSpaceRangeMeters / 1000.0;
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  void _position(Wgs84Coordinate p) => setState(() {
    _fields['latitude']!.text = '${p.latitude}';
    _fields['longitude']!.text = '${p.longitude}';
  });
  Future<void> _savedSpot() async {
    final spot = await showRouteStartLocation(
      context,
      search: false,
      spots: widget.spots,
      title: 'Choose transmitter spot',
      hint: 'Use the saved coordinates as the radio transmitter position.',
    );
    if (spot != null && mounted) _position(spot.position);
  }

  Future<void> _import() async {
    setState(() => _working = true);
    try {
      final file = await pickLocalCsv();
      if (file == null) return;
      final items = await compute(decodeSurfaceCsv, file.bytes);
      if (mounted) {
        setState(() {
          _surfaces = items;
          _surfacesEnabled = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to import surface observations.');
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _useStoredEquipment(String category) async {
    if (_working || widget.equipment == null) return;
    try {
      final equipment = (await widget.equipment!.getAllEquipment())
          .where((item) => item.category == category)
          .toList();
      if (!mounted) return;
      final selected = await showDialog<RadioEquipmentData>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: Text(
            category == 'video'
                ? 'Videosystem auswählen'
                : 'RC-System auswählen',
          ),
          children: equipment.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Keine gespeicherten Geräte dieser Kategorie.'),
                  ),
                ]
              : equipment
                    .map(
                      (item) => SimpleDialogOption(
                        onPressed: () => Navigator.pop(dialogContext, item),
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
        ),
      );
      if (!mounted || selected == null) return;
      final prefix = category == 'video' ? 'video' : 'rc';
      final fallback = RfBandProfile(
        frequencyMhz: _value('${prefix}Frequency'),
        eirpDbm: _value('${prefix}Power'),
        receiverThresholdDbm: _value('${prefix}Threshold'),
        fadeMarginDb: _value('${prefix}Fade'),
      );
      final updated = rfBandFromEquipment(selected, fallback: fallback);
      setState(() {
        if (category == 'video') {
          _videoScenario = RfScenario.custom;
        } else {
          _controlScenario = RfScenario.custom;
        }
        _fields['${prefix}Frequency']!.text = '${updated.frequencyMhz}';
        _fields['${prefix}Power']!.text = updated.eirpDbm.toStringAsFixed(2);
        _fields['${prefix}Threshold']!.text = '${updated.receiverThresholdDbm}';
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Gespeicherte Funkdaten konnten nicht übernommen werden.',
        );
      }
    }
  }

  void _selectScenario(String type, RfScenario scenario) {
    setState(() {
      if (type == 'video') {
        _videoScenario = scenario;
      } else {
        _controlScenario = scenario;
      }
      if (scenario == RfScenario.custom) return;
      final profile = type == 'video'
          ? RfReferencePresets.video(scenario)
          : RfReferencePresets.control(scenario);
      final prefix = type == 'video' ? 'video' : 'rc';
      _fields['${prefix}Frequency']!.text = '${profile.frequencyMhz}';
      _fields['${prefix}Power']!.text = '${profile.eirpDbm}';
      _fields['${prefix}Threshold']!.text = '${profile.receiverThresholdDbm}';
      _fields['${prefix}Fade']!.text = '${profile.fadeMarginDb}';
      _error = null;
    });
  }

  Widget _scenarioSelector(String type, String title) {
    final current = type == 'video' ? _videoScenario : _controlScenario;
    return DropdownButtonFormField<RfScenario>(
      key: ValueKey('rf-scenario-$type-$current'),
      initialValue: current,
      isExpanded: true,
      decoration: InputDecoration(labelText: title),
      items: const [
        DropdownMenuItem(value: RfScenario.eu, child: Text('EU / CE · SIM')),
        DropdownMenuItem(value: RfScenario.fcc, child: Text('FCC · SIM')),
        DropdownMenuItem(
          value: RfScenario.custom,
          child: Text('Benutzerdefiniert / Custom'),
        ),
      ],
      onChanged: _working
          ? null
          : (value) {
              if (value != null) _selectScenario(type, value);
            },
    );
  }

  Future<void> _apply() async {
    try {
      final settings = SignalSettings(
        pilot: _spawn
            ? c.settings.signal.pilot
            : Wgs84Coordinate(
                latitude: _value('latitude'),
                longitude: _value('longitude'),
              ),
        antennaHeight: _value('antenna'),
        frequencyMhz: _value('frequency'),
        clearanceFraction: _value('fraction') / 100,
        useSurfaces: _surfacesEnabled,
        surfaces: _surfaces,
      );
      settings.validate();
      final rf = RfProfileSettings(
        enabled: _rfEnabled,
        videoScenario: _videoScenario,
        controlScenario: _controlScenario,
        video: RfBandProfile(
          frequencyMhz: _value('videoFrequency'),
          eirpDbm: _value('videoPower'),
          receiverThresholdDbm: _value('videoThreshold'),
          fadeMarginDb: _value('videoFade'),
        ),
        control: RfBandProfile(
          frequencyMhz: _value('rcFrequency'),
          eirpDbm: _value('rcPower'),
          receiverThresholdDbm: _value('rcThreshold'),
          fadeMarginDb: _value('rcFade'),
        ),
      );
      rf.validate();
      setState(() {
        _working = true;
        _error = null;
      });
      await c.configure(
        LiveRadioSettings(
          enabled: _enabled,
          useSpawn: _spawn,
          showGroundStationMarker: _marker,
          showSignalPath: _path,
          signal: settings,
          rfProfiles: rf,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Check the inputs and renderer connection, then retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.globe.selectedPoint;
    final videoRangeKm = _theoreticalRangeKm('video');
    final rcRangeKm = _theoreticalRangeKm('rc');
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: .9,
        child: Column(
          children: [
            ListTile(
              title: Text(
                context.localized(
                  "Live radio line of sight",
                  (l10n) => l10n.signalLiveRadioLineOfb3b60fda,
                ),
              ),
              trailing: IconButton(
                tooltip: context.localized(
                  "Close",
                  (l10n) => l10n.commonClosebbfa773e,
                ),
                onPressed: _working ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.localized(
                        "Periodic geometric preview between the transmitter and the simulated drone. This is not measured signal quality or a guaranteed communication range.",
                        (l10n) =>
                            l10n.signalPeriodicGeometricPreviewBetweenb75cb376,
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        context.localized(
                          "Enable live radio preview",
                          (l10n) => l10n.signalEnableLiveRadioPreview96c70f99,
                        ),
                      ),
                      value: _enabled,
                      onChanged: _working
                          ? null
                          : (v) => setState(() => _enabled = v),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        context.localized(
                          "Show ground station marker",
                          (l10n) => l10n.signalShowGroundStationMarker,
                        ),
                      ),
                      value: _marker,
                      onChanged: _working
                          ? null
                          : (v) => setState(() => _marker = v),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        context.localized(
                          "Show live line of sight",
                          (l10n) => l10n.signalShowLiveSignalPath,
                        ),
                      ),
                      value: _path,
                      onChanged: _working
                          ? null
                          : (v) => setState(() => _path = v),
                    ),
                    DropdownButtonFormField<bool>(
                      initialValue: _spawn,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.localized(
                          "Transmitter position",
                          (l10n) => l10n.signalTransmitterPositiond87196e3,
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: true,
                          child: Text(
                            context.localized(
                              "Current flight launch point",
                              (l10n) =>
                                  l10n.signalCurrentFlightLaunchPointb1e984c0,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: false,
                          child: Text(
                            context.localized(
                              "Fixed spot / coordinates",
                              (l10n) => l10n.signalFixedSpotCoordinatese71de0f9,
                            ),
                          ),
                        ),
                      ],
                      onChanged: _working
                          ? null
                          : (v) => setState(() => _spawn = v!),
                    ),
                    if (!_spawn) ...[
                      Text(
                        context.localized(
                          "Select a point on the 3D map, then reopen this panel and choose “Selected map point”.",
                          (l10n) => l10n.signalChooseGroundStationFromMap,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.restart_alt),
                        onPressed: _working
                            ? null
                            : () => setState(() => _spawn = true),
                        label: Text(
                          context.localized(
                            "Reset to takeoff position",
                            (l10n) => l10n.signalUseTakeoffAsGroundStation,
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (widget.spots != null)
                            TextButton(
                              onPressed: _working ? null : _savedSpot,
                              child: Text(
                                context.localized(
                                  "Saved spot",
                                  (l10n) => l10n.commonSavedSpot64ad0674,
                                ),
                              ),
                            ),
                          if (selected != null)
                            TextButton(
                              onPressed: _working
                                  ? null
                                  : () => _position(
                                      Wgs84Coordinate(
                                        latitude: selected.latitude,
                                        longitude: selected.longitude,
                                      ),
                                    ),
                              child: Text(
                                context.localized(
                                  "Selected map point",
                                  (l10n) => l10n.signalSelectedMapPoint1717e7f7,
                                ),
                              ),
                            ),
                        ],
                      ),
                      for (final key in ['latitude', 'longitude'])
                        TextField(
                          controller: _fields[key],
                          enabled: !_working,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: InputDecoration(
                            labelText: key == 'latitude'
                                ? context.localized(
                                    "Latitude · WGS84",
                                    (l10n) => l10n.signalLatitudeWgsd5f5cf6c,
                                  )
                                : context.localized(
                                    "Longitude · WGS84",
                                    (l10n) => l10n.signalLongitudeWgs63c0ff8c,
                                  ),
                          ),
                        ),
                    ],
                    for (final field in [
                      ('antenna', 'Transmitter antenna · m AGL (0.1–100)'),
                      ('frequency', 'Frequency · MHz (10–100000)'),
                      ('fraction', 'First Fresnel zone clearance · % (0–100)'),
                    ])
                      TextField(
                        controller: _fields[field.$1],
                        enabled: !_working,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(labelText: field.$2),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      context.localized(
                        "Transmitter height is above sampled terrain. The receiving endpoint is the drone’s simulated WGS84 ellipsoidal height.",
                        (l10n) => l10n.signalTransmitterHeightIsAboveb50b536b,
                      ),
                    ),
                    ExpansionTile(
                      title: const Text(
                        'SIM RF profiles · DJI O4 Pro / TBS Crossfire',
                      ),
                      subtitle: const Text(
                        'Illustrative link budget, not measured signal quality',
                      ),
                      children: [
                        SwitchListTile(
                          title: const Text(
                            'Automatic simulated RF estimation',
                          ),
                          value: _rfEnabled,
                          onChanged: _working
                              ? null
                              : (value) => setState(() => _rfEnabled = value),
                        ),
                        if (widget.equipment != null)
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed: _working
                                    ? null
                                    : () => _useStoredEquipment('video'),
                                icon: const Icon(Icons.file_download_outlined),
                                label: const Text('Videosystem übernehmen'),
                              ),
                              TextButton.icon(
                                onPressed: _working
                                    ? null
                                    : () => _useStoredEquipment('control'),
                                icon: const Icon(Icons.file_download_outlined),
                                label: const Text('RC-System übernehmen'),
                              ),
                            ],
                          ),
                        _scenarioSelector(
                          'video',
                          'DJI O4 Pro · Region / scenario',
                        ),
                        _scenarioSelector(
                          'control',
                          'TBS Crossfire · Region / scenario',
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'SIM ONLY: EU/CE und FCC sind Modell-Szenarien, keine Geräteumstellung oder Betriebsfreigabe. DJI-Reichweitenwerte dienen nur zur theoretischen Kalibrierung. Crossfire-FCC verwendet beispielhaft 250 mW. 40 MHz ist Bandbreite, kein Leistungsfaktor.',
                          ),
                        ),
                        for (final field in [
                          ('videoFrequency', 'O4 Pro · MHz'),
                          ('videoPower', 'O4 Pro · EIRP dBm'),
                          (
                            'videoThreshold',
                            'O4 Pro · assumed receiver threshold dBm',
                          ),
                          ('videoFade', 'O4 Pro · fade margin dB'),
                          ('rcFrequency', 'Crossfire · MHz'),
                          ('rcPower', 'Crossfire · EIRP dBm'),
                          (
                            'rcThreshold',
                            'Crossfire · assumed receiver threshold dBm',
                          ),
                          ('rcFade', 'Crossfire · fade margin dB'),
                        ])
                          TextField(
                            controller: _fields[field.$1],
                            enabled: !_working,
                            onChanged: (_) => setState(() {
                              if (field.$1.startsWith('video')) {
                                _videoScenario = RfScenario.custom;
                              }
                              if (field.$1.startsWith('rc')) {
                                _controlScenario = RfScenario.custom;
                              }
                            }),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: InputDecoration(labelText: field.$2),
                          ),
                        if (_rfEnabled &&
                            videoRangeKm != null &&
                            rcRangeKm != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'SIM · FSPL (0 dB): Video ≈${videoRangeKm.toStringAsFixed(1)} km · '
                              'RC ≈${rcRangeKm.toStringAsFixed(1)} km',
                            ),
                          ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Ideal free-space calculation only. Assumed receiver thresholds, '
                            'no terrain/radio horizon; not a usable or guaranteed flight range.',
                          ),
                        ),
                      ],
                    ),
                    ExpansionTile(
                      title: Text(
                        context.localized(
                          "Local surface observations",
                          (l10n) => l10n.signalLocalSurfaceObservations5f83fa58,
                        ),
                      ),
                      subtitle: Text(
                        context.localizedWithArgs(
                          "{0} imported observations",
                          [_surfaces.length],
                          (l10n, value) =>
                              l10n.signalImportedObservations6dc74f21(value(0)),
                        ),
                      ),
                      children: [
                        Text(
                          context.localized(
                            "Optional circular AGL observations, as in preflight analysis. Visible 3D buildings, forests, masts and cables are not automatically included.",
                            (l10n) => l10n
                                .commonOptionalCircularAglObservations3ad9fcc1,
                          ),
                        ),
                        SwitchListTile(
                          title: Text(
                            context.localized(
                              "Include imported observations",
                              (l10n) => l10n
                                  .signalIncludeImportedObservations2e110738,
                            ),
                          ),
                          value: _surfacesEnabled,
                          onChanged: _working
                              ? null
                              : (v) => setState(() => _surfacesEnabled = v),
                        ),
                        TextButton(
                          onPressed: _working ? null : _import,
                          child: Text(
                            context.localized(
                              "Import surface CSV",
                              (l10n) => l10n.signalImportSurfaceCsv07954aaf,
                            ),
                          ),
                        ),
                        if (_surfaces.isNotEmpty)
                          TextButton(
                            onPressed: _working
                                ? null
                                : () => setState(() {
                                    _surfaces = const [];
                                    _surfacesEnabled = false;
                                  }),
                            child: Text(
                              context.localized(
                                "Clear observations",
                                (l10n) => l10n.signalClearObservationsc6114e52,
                              ),
                            ),
                          ),
                      ],
                    ),
                    ExpansionTile(
                      title: Text(
                        context.localized(
                          "Sampling and limits",
                          (l10n) => l10n.signalSamplingAndLimits81b895c4,
                        ),
                      ),
                      children: [
                        Text(
                          context.localized(
                            "swisstopo terrain via Cesium · fixed terrain level 12 · profile points at most 25 m apart · live range 1 m–6 km. A new profile is attempted at most every 2 seconds. Sample heights may be reused for up to 30 seconds. Narrow or finer terrain features may be missed.",
                            (l10n) =>
                                l10n.signalSwisstopoTerrainViaCesium5961555e,
                          ),
                        ),
                        Text(
                          context.localized(
                            "Results expire after 5 seconds. Flight movement, pauses, respawns and unavailable terrain can make a result unknown. Terrain publication time is not supplied by this sampling interface. Radio propagation, interference, antenna patterns and material attenuation are not modelled.",
                            (l10n) =>
                                l10n.commonResultsExpireAfterSecondsfc4e5dd8,
                          ),
                        ),
                      ],
                    ),
                    ListenableBuilder(
                      listenable: c,
                      builder: (_, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(c.status),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Live RF diagnostics'),
                            subtitle: const Text(
                              'Show the optional debug panel in the flight HUD',
                            ),
                            value: c.diagnosticsEnabled,
                            onChanged: c.setDiagnosticsEnabled,
                          ),
                          if (c.diagnosticsEnabled)
                            SelectableText(_diagnosticsText(c.diagnostics)),
                          if (c.calculatedAt != null)
                            Text(
                              context.localizedWithArgs(
                                "Last completed profile: {0} · {1}",
                                [
                                  c.calculatedAt!.toLocal(),
                                  c.current
                                      ? 'within live window'
                                      : 'not current',
                                ],
                                (l10n, value) =>
                                    l10n.signalLastCompletedProfileaec2638b(
                                      value(0),
                                      value(1),
                                    ),
                              ),
                            ),
                          if (c.result?.minimumClearance != null)
                            Text(
                              context.localizedWithArgs(
                                "Minimum sampled geometric clearance: {0} m",
                                [
                                  c.result!.minimumClearance!.toStringAsFixed(
                                    2,
                                  ),
                                ],
                                (l10n, value) => l10n
                                    .signalMinimumSampledGeometricClearancecf242d36(
                                      value(0),
                                    ),
                              ),
                            ),
                          if (c.result?.minimumFresnelClearance != null)
                            Text(
                              context.localizedWithArgs(
                                "Minimum configured Fresnel margin: {0} m",
                                [
                                  c.result!.minimumFresnelClearance!
                                      .toStringAsFixed(2),
                                ],
                                (l10n, value) => l10n
                                    .signalMinimumConfiguredFresnelMargin119fbdcf(
                                      value(0),
                                    ),
                              ),
                            ),
                          if (c.transmitter != null)
                            Text(
                              'Transmitter: ${c.transmitter!.latitude.toStringAsFixed(5)}, ${c.transmitter!.longitude.toStringAsFixed(5)}',
                            ),
                        ],
                      ),
                    ),
                    if (c.obstruction != null)
                      Text(
                        context.localizedWithArgs(
                          "Potential obstruction: {0}, {1} · surface {2} m WGS84 ellipsoid",
                          [
                            c.obstruction!.position.latitude.toStringAsFixed(5),
                            c.obstruction!.position.longitude.toStringAsFixed(
                              5,
                            ),
                            c.obstruction!.surface.toStringAsFixed(1),
                          ],
                          (l10n, value) =>
                              l10n.commonPotentialObstructionSurfaceMf0e561ae(
                                value(0),
                                value(1),
                                value(2),
                              ),
                        ),
                      ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _working ? null : _apply,
                      child: Text(
                        context.localized(
                          "Apply radio preview",
                          (l10n) => l10n.signalApplyRadioPreview1e94fdf7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _diagnosticsText(Map<String, Object?> d) {
  String value(String key) => switch (d[key]) {
    final double number => number.toStringAsFixed(1),
    final Object value => '$value',
    null => '—',
  };
  return 'LoS ${value('los')} · ${value('quality')} · age ${value('ageMs')} ms\n'
      'Calculation ${value('durationMs')} ms · P50/P95 ${value('p50Ms')}/${value('p95Ms')} ms\n'
      'Active/queued ${value('active')}/${value('queued')} · failures ${value('failures')} · ${value('error')}\n'
      '${d['errorDetail'] == null ? '' : '${value('errorDetail')}\n'}'
      'Distance ${value('distanceMeters')} m · movement ${value('movementMeters')} m\n'
      'Samples ${value('validSamples')}/${value('samples')} · missing ${value('missingSamples')}\n'
      'Request ${value('requestId')} · generation ${value('generation')} · ${value('provider')}';
}
