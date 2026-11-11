import 'dart:math' as math;

import '../../core/localization/app_localizations.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/geo/geo_coordinate_service.dart';
import '../../core/models/local_csv_file.dart';
import '../../core/models/signal_settings.dart';
import 'radio_analysis.dart';
import 'radio_analysis_controller.dart';
import 'surface_csv.dart';

Future<void> showRadioAnalysis(
  BuildContext context,
  RadioAnalysisController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _RadioSheet(controller: controller),
);

String radioStateLabel(RadioPathState state) => switch (state) {
  RadioPathState.unknown => 'Unknown height / vertical path',
  RadioPathState.obstructed => 'Potential geometric obstruction',
  RadioPathState.fresnelIntrusion => 'Fresnel clearance intrusion',
  RadioPathState.noSampledObstruction => 'No obstruction at sampled positions',
};

class _RadioSheet extends StatefulWidget {
  const _RadioSheet({required this.controller});
  final RadioAnalysisController controller;
  @override
  State<_RadioSheet> createState() => _RadioSheetState();
}

class _RadioSheetState extends State<_RadioSheet> {
  RadioAnalysisController get c => widget.controller;
  late final _initial = c.editor.planning.signal;
  late final _position = _initial?.pilot ?? c.editor.points.first.position;
  late final _fields = <String, TextEditingController>{
    'latitude': TextEditingController(text: '${_position.latitude}'),
    'longitude': TextEditingController(text: '${_position.longitude}'),
    'antenna': TextEditingController(text: '${_initial?.antennaHeight ?? 2}'),
    'frequency': TextEditingController(
      text: '${_initial?.frequencyMhz ?? 5800}',
    ),
    'clearance': TextEditingController(
      text: '${(_initial?.clearanceFraction ?? .6) * 100}',
    ),
  };
  late List<SurfaceObservation> _surfaces = _initial?.surfaces ?? const [];
  late bool _useSurfaces = _initial?.useSurfaces ?? false;
  bool _importing = false;
  String? _error;
  @override
  void dispose() {
    for (final f in _fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  double _value(String name) =>
      double.parse(_fields[name]!.text.trim().replaceAll(',', '.'));
  void _changed(String _) {
    c.clear();
  }

  Future<void> _calculate() async {
    try {
      final settings = SignalSettings(
        pilot: Wgs84Coordinate(
          latitude: _value('latitude'),
          longitude: _value('longitude'),
        ),
        antennaHeight: _value('antenna'),
        frequencyMhz: _value('frequency'),
        clearanceFraction: _value('clearance') / 100,
        useSurfaces: _useSurfaces,
        surfaces: _surfaces,
      );
      settings.validate();
      c.editor.configurePlanning(c.editor.planning.withSignal(settings));
      setState(() => _error = null);
      await c.calculate();
    } catch (e) {
      if (mounted) setState(() => _error = 'Check inputs: $e');
    }
  }

  Future<void> _importSurface() async {
    setState(() => _importing = true);
    try {
      final file = await pickLocalCsv();
      if (file == null) return;
      final surfaces = await compute(decodeSurfaceCsv, file.bytes);
      if (mounted) {
        c.clear();
        setState(() {
          _surfaces = surfaces;
          _useSurfaces = true;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Surface import: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Widget _field(String key, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: _fields[key],
      enabled: !c.loading && !_importing,
      keyboardType: const TextInputType.numberWithOptions(
        signed: true,
        decimal: true,
      ),
      decoration: InputDecoration(labelText: label),
      onChanged: _changed,
    ),
  );
  @override
  Widget build(BuildContext context) => SafeArea(
    child: FractionallySizedBox(
      heightFactor: .9,
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => Column(
          children: [
            ListTile(
              title: Text(context.translate("Terrain & radio path")),
              trailing: IconButton(
                tooltip: context.translate("Close signal analysis"),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  Text(
                    context.translate(
                      "Geometric visibility and Fresnel clearance are approximations, not measured signal quality or a guaranteed communication range.",
                    ),
                  ),
                  ExpansionTile(
                    initiallyExpanded: c.result == null,
                    title: Text(context.translate("Pilot & frequency")),
                    subtitle: Text(
                      context.translate(
                        "Analyze applies inputs; Save the route to keep them",
                      ),
                    ),
                    children: [
                      _field('latitude', 'Pilot latitude · WGS84'),
                      _field('longitude', 'Pilot longitude · WGS84'),
                      _field(
                        'antenna',
                        'Pilot antenna height · m AGL (0.1–100)',
                      ),
                      _field(
                        'frequency',
                        'Transmission frequency · MHz (10–100000)',
                      ),
                      _field(
                        'clearance',
                        'First Fresnel zone clearance · % (0–100)',
                      ),
                      Text(
                        context.translate(
                          "Defaults: 2 m antenna, 5800 MHz and 60% first-zone radius. Set the actual control or video frequency for each analysis.",
                        ),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    title: Text(
                      context.translate(
                        "Optional building / vegetation observations",
                      ),
                    ),
                    subtitle: Text(
                      context.translate("{0} local observations · {1}", [
                        _surfaces.length,
                        _useSurfaces ? "included" : "disabled",
                      ]),
                    ),
                    children: [
                      Text(
                        context.translate(
                          "No building or canopy service is connected. Import known local footprints as circular AGL height observations. These are approximate site observations, not a complete surface model.",
                        ),
                      ),
                      SwitchListTile(
                        title: Text(
                          context.translate(
                            "Include imported surface observations",
                          ),
                        ),
                        value: _useSurfaces,
                        onChanged: c.loading || _importing
                            ? null
                            : (v) {
                                c.clear();
                                setState(() => _useSurfaces = v);
                              },
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: c.loading || _importing
                                ? null
                                : _importSurface,
                            child: Text(
                              context.translate("Import surface CSV"),
                            ),
                          ),
                          TextButton(
                            onPressed:
                                c.loading || _importing || _surfaces.isEmpty
                                ? null
                                : () {
                                    c.clear();
                                    setState(() {
                                      _surfaces = const [];
                                      _useSurfaces = false;
                                    });
                                  },
                            child: Text(
                              context.translate("Remove observations"),
                            ),
                          ),
                        ],
                      ),
                      SelectableText(
                        context.translate(
                          "latitude,longitude,height_m_agl,radius_m,kind,source\nKinds: building, vegetation, other. Up to 100 observations. Heights 0–1000 m AGL, radius 1–1000 m.",
                        ),
                      ),
                      for (final s in _surfaces)
                        ListTile(
                          dense: true,
                          title: Text(
                            context.translate(
                              "{0} · {1} m AGL · {2} m radius",
                              [s.kind, s.height, s.radius],
                            ),
                          ),
                          subtitle: Text(
                            '${s.position.latitude}, ${s.position.longitude} · ${s.source}',
                          ),
                        ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: c.loading || _importing ? null : _calculate,
                        icon: const Icon(Icons.settings_input_antenna),
                        label: Text(context.translate("Analyze radio paths")),
                      ),
                      TextButton(
                        onPressed: c.clear,
                        child: Text(
                          c.loading
                              ? context.translate("Cancel analysis")
                              : context.translate("Clear overlay"),
                        ),
                      ),
                    ],
                  ),
                  if (c.loading) ...[
                    LinearProgressIndicator(
                      value: c.total == 0 ? null : c.completed / c.total,
                    ),
                    Text(
                      context.translate("{0} / {1} terrain samples", [
                        c.completed,
                        c.total,
                      ]),
                    ),
                  ],
                  if (_importing) const LinearProgressIndicator(),
                  if (_error != null || c.error != null)
                    Text(_error ?? c.error!),
                  if (c.result case final paths?) ...[
                    Text(
                      context.translate("{0} route targets · terrain: {1}", [
                        paths.length,
                        c.methods.join(", "),
                      ]),
                    ),
                    Text(
                      context.translate(
                        "Map: orange = potential obstruction, purple = Fresnel intrusion, cyan = no sampled obstruction, gray = unknown. The selected path shows the configured Fresnel envelope.",
                      ),
                    ),
                    DropdownButtonFormField<int>(
                      key: ValueKey(paths),
                      initialValue: c.selected,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.translate(
                          "Inspect communication path",
                        ),
                      ),
                      items: [
                        for (var i = 0; i < paths.length; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(
                              '${i + 1}: ${radioStateLabel(paths[i].state)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (i) {
                        if (i != null) c.select(i);
                      },
                    ),
                    _profile(paths[c.selected]),
                  ],
                  ExpansionTile(
                    title: Text(context.translate("Method, sources & limits")),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          context.translate(
                            "swisstopo terrain via Cesium, WGS84 ellipsoidal heights. Straight ECEF chord includes Earth curvature; no atmospheric refraction, diffraction loss, multipath, interference, antenna patterns or received-power prediction. First Fresnel radius: √(λ d1 d2 / (d1+d2)), ITU-R P.526 Annex 1 §2.1. Route targets ≤100 m apart, communication profiles ≤25 m apart; narrow obstacles and obstructions beside the sampled centerline may be missed. Imported surface observations are circular, constant AGL additions to sampled terrain. The Fresnel envelope is a wireframe aid, not a surveyed clearance volume. Unknown route heights stay unknown; 30 m display previews are excluded. Up to 128 targets / 16384 terrain samples. Recalculate after route, pilot or terrain changes.",
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _profile(RadioPathResult p) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12),
      Text(radioStateLabel(p.state)),
      if (p.minimumClearance != null)
        Text(
          context.translate("Minimum sampled LOS clearance: {0} m", [
            p.minimumClearance!.toStringAsFixed(2),
          ]),
        ),
      if (p.minimumFresnelClearance != null)
        Text(
          context.translate("Minimum configured Fresnel margin: {0} m", [
            p.minimumFresnelClearance!.toStringAsFixed(2),
          ]),
        ),
      if (p.profile.isNotEmpty) ...[
        SizedBox(
          height: 180,
          width: double.infinity,
          child: CustomPaint(
            painter: _RadioProfilePainter(
              p.profile,
              c.editor.planning.signal!.clearanceFraction,
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Text(
          context.translate(
            "Profile: brown terrain/surface · cyan LOS · purple lower Fresnel boundary. Heights in WGS84 ellipsoid.",
          ),
        ),
      ],
    ],
  );
}

class _RadioProfilePainter extends CustomPainter {
  _RadioProfilePainter(this.profile, this.fraction, this.color);
  final List<RadioPathSample> profile;
  final double fraction;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final values = profile.expand(
      (p) => [p.surface, p.lineHeight, p.lineHeight - p.radius * fraction],
    );
    final low = values.reduce(math.min) - 2, high = values.reduce(math.max) + 2;
    void curve(double Function(RadioPathSample) value, Color color) {
      final path = Path();
      for (var i = 0; i < profile.length; i++) {
        final x = size.width * i / (profile.length - 1),
            y = size.height * (1 - (value(profile[i]) - low) / (high - low));
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    curve((p) => p.surface, Colors.brown);
    curve((p) => p.lineHeight, Colors.cyan);
    curve((p) => p.lineHeight - p.radius * fraction, Colors.purpleAccent);
  }

  @override
  bool shouldRepaint(covariant _RadioProfilePainter old) =>
      old.profile != profile || old.fraction != fraction || old.color != color;
}
