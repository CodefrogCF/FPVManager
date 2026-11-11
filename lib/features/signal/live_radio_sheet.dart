import 'package:flutter/foundation.dart';

import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../core/geo/geo_coordinate_service.dart';
import '../../core/models/local_csv_file.dart';
import '../../core/models/signal_settings.dart';
import '../globe/globe_controller.dart';
import '../routes/route_start_sheet.dart';
import '../spots/data/spot_repository.dart';
import 'live_radio_controller.dart';
import 'surface_csv.dart';

class LiveRadioLauncher extends StatelessWidget {
  const LiveRadioLauncher({super.key, required this.globe, this.spots});
  final GlobeController globe;
  final SpotRepository? spots;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () => showLiveRadioSettings(context, globe, spots: spots),
    icon: const Icon(Icons.settings_input_antenna),
    label: Text(context.translate("Radio line of sight")),
  );
}

Future<void> showLiveRadioSettings(
  BuildContext context,
  GlobeController globe, {
  SpotRepository? spots,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _LiveRadioSheet(globe: globe, spots: spots),
);

class _LiveRadioSheet extends StatefulWidget {
  const _LiveRadioSheet({required this.globe, this.spots});
  final GlobeController globe;
  final SpotRepository? spots;
  @override
  State<_LiveRadioSheet> createState() => _LiveRadioSheetState();
}

class _LiveRadioSheetState extends State<_LiveRadioSheet> {
  LiveRadioController get c => widget.globe.liveRadio;
  late bool _enabled = c.settings.enabled,
      _spawn = c.settings.useSpawn,
      _surfacesEnabled = c.settings.signal.useSurfaces;
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
      setState(() {
        _working = true;
        _error = null;
      });
      await c.configure(
        LiveRadioSettings(
          enabled: _enabled,
          useSpawn: _spawn,
          signal: settings,
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: .9,
        child: Column(
          children: [
            ListTile(
              title: Text(context.translate("Live radio line of sight")),
              trailing: IconButton(
                tooltip: context.translate("Close"),
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
                      context.translate(
                        "Periodic geometric preview between the transmitter and the simulated drone. This is not measured signal quality or a guaranteed communication range.",
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        context.translate("Enable live radio preview"),
                      ),
                      value: _enabled,
                      onChanged: _working
                          ? null
                          : (v) => setState(() => _enabled = v),
                    ),
                    DropdownButtonFormField<bool>(
                      initialValue: _spawn,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.translate("Transmitter position"),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: true,
                          child: Text(
                            context.translate("Current flight launch point"),
                          ),
                        ),
                        DropdownMenuItem(
                          value: false,
                          child: Text(
                            context.translate("Fixed spot / coordinates"),
                          ),
                        ),
                      ],
                      onChanged: _working
                          ? null
                          : (v) => setState(() => _spawn = v!),
                    ),
                    if (!_spawn) ...[
                      Wrap(
                        spacing: 8,
                        children: [
                          if (widget.spots != null)
                            TextButton(
                              onPressed: _working ? null : _savedSpot,
                              child: Text(context.translate("Saved spot")),
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
                                context.translate("Selected map point"),
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
                                ? context.translate("Latitude · WGS84")
                                : context.translate("Longitude · WGS84"),
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
                      context.translate(
                        "Transmitter height is above sampled terrain. The receiving endpoint is the drone’s simulated WGS84 ellipsoidal height.",
                      ),
                    ),
                    ExpansionTile(
                      title: Text(
                        context.translate("Local surface observations"),
                      ),
                      subtitle: Text(
                        context.translate("{0} imported observations", [
                          _surfaces.length,
                        ]),
                      ),
                      children: [
                        Text(
                          context.translate(
                            "Optional circular AGL observations, as in preflight analysis. Visible 3D buildings, forests, masts and cables are not automatically included.",
                          ),
                        ),
                        SwitchListTile(
                          title: Text(
                            context.translate("Include imported observations"),
                          ),
                          value: _surfacesEnabled,
                          onChanged: _working
                              ? null
                              : (v) => setState(() => _surfacesEnabled = v),
                        ),
                        TextButton(
                          onPressed: _working ? null : _import,
                          child: Text(context.translate("Import surface CSV")),
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
                              context.translate("Clear observations"),
                            ),
                          ),
                      ],
                    ),
                    ExpansionTile(
                      title: Text(context.translate("Sampling and limits")),
                      children: [
                        Text(
                          context.translate(
                            "swisstopo terrain via Cesium · fixed terrain level 12 · profile points at most 25 m apart · live range 1 m–6 km. A new profile is attempted at most every 2 seconds. Sample heights may be reused for up to 30 seconds. Narrow or finer terrain features may be missed.",
                          ),
                        ),
                        Text(
                          context.translate(
                            "Results expire after 5 seconds. Flight movement, pauses, respawns and unavailable terrain can make a result unknown. Terrain publication time is not supplied by this sampling interface. Radio propagation, interference, antenna patterns and material attenuation are not modelled.",
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
                          if (c.calculatedAt != null)
                            Text(
                              context.translate(
                                "Last completed profile: {0} · {1}",
                                [
                                  c.calculatedAt!.toLocal(),
                                  c.current
                                      ? 'within live window'
                                      : 'not current',
                                ],
                              ),
                            ),
                          if (c.result?.minimumClearance != null)
                            Text(
                              context.translate(
                                "Minimum sampled geometric clearance: {0} m",
                                [
                                  c.result!.minimumClearance!.toStringAsFixed(
                                    2,
                                  ),
                                ],
                              ),
                            ),
                          if (c.result?.minimumFresnelClearance != null)
                            Text(
                              context.translate(
                                "Minimum configured Fresnel margin: {0} m",
                                [
                                  c.result!.minimumFresnelClearance!
                                      .toStringAsFixed(2),
                                ],
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
                        context.translate(
                          "Potential obstruction: {0}, {1} · surface {2} m WGS84 ellipsoid",
                          [
                            c.obstruction!.position.latitude.toStringAsFixed(5),
                            c.obstruction!.position.longitude.toStringAsFixed(
                              5,
                            ),
                            c.obstruction!.surface.toStringAsFixed(1),
                          ],
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
                      child: Text(context.translate("Apply radio preview")),
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
