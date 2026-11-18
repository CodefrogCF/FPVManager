import 'dart:math' as math;

import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../core/database/repositories/flight_plan_repository.dart';
import 'flight_recording.dart';

Future<int?> showFlightRecordingReview(
  BuildContext context, {
  required RecordedFlight flight,
  required FlightPlanRepository repository,
  required Future<void> Function() onDiscard,
}) => showDialog<int>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      _Review(flight: flight, repository: repository, onDiscard: onDiscard),
);

class _Review extends StatefulWidget {
  const _Review({
    required this.flight,
    required this.repository,
    required this.onDiscard,
  });
  final RecordedFlight flight;
  final FlightPlanRepository repository;
  final Future<void> Function() onDiscard;
  @override
  State<_Review> createState() => _ReviewState();
}

class _ReviewState extends State<_Review> {
  late final _segments = widget.flight.segments;
  late int _segment = _longest();
  late final _name = TextEditingController(
    text:
        'Simulated flight ${widget.flight.startedAt.toLocal().toString().substring(0, 16)}',
  );
  double _tolerance = 2;
  bool _agl = false, _working = false;
  RangeValues? _range;
  String? _error;
  final _save = RecordingRouteSave();
  int _longest() {
    var best = 0, dist = -1.0;
    for (var i = 0; i < _segments.length; i++) {
      final d = recordedDistance(_segments[i]);
      if (d > dist) {
        best = i;
        dist = d;
      }
    }
    return best;
  }

  List<RecordedFlightPoint> get _selected {
    final all = _segments[_segment], range = _range;
    return range == null
        ? all
        : all.sublist(range.start.round(), range.end.round() + 1);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveRoute(
    List<RecordedFlightPoint> points, {
    required bool agl,
  }) async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final id = await _save.save(
        widget.repository,
        name: _name.text,
        points: recordingWaypoints(points, agl: agl),
        flight: widget.flight,
        recordedPoints: points,
      );
      if (mounted && id != null) Navigator.pop(context, id);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to save. Your recording is retained; check the name and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _discard() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          context.localized(
            "Discard recording?",
            (l10n) => l10n.simulationDiscardRecording76dde3d6,
          ),
        ),
        content: Text(
          context.localized(
            "The unsaved simulated flight will be removed.",
            (l10n) => l10n.simulationTheUnsavedSimulatedFlight363d0ff5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(
              context.localized(
                "Keep recording",
                (l10n) => l10n.simulationKeepRecording77ccc1b0,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              context.localized(
                "Discard",
                (l10n) => l10n.simulationDiscard36fff63c,
              ),
            ),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _working = true);
    try {
      await widget.onDiscard();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to update the flight controls. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected,
        points = simplifyRecording(selected, _tolerance);
    final hasAgl = selected.every((p) => p.agl != null && p.agl! >= 0);
    final distance = recordedDistance(selected),
        seconds = selected.last.seconds - selected.first.seconds;
    final usable =
        points.length >= 2 && points.length <= 1000 && distance >= .1;
    final heights = selected
        .map((p) => _agl && hasAgl ? p.agl! : p.height)
        .toList();
    final speeds = [
      for (final p in selected)
        if (p.speedMetersPerSecond != null) p.speedMetersPerSecond!,
    ];
    final airspeeds = [
      for (final p in selected)
        if (p.airspeedMetersPerSecond != null) p.airspeedMetersPerSecond!,
    ];
    final measuredGround = selected.where((p) => p.agl != null).length;
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_working,
      child: AlertDialog(
        title: Text(
          context.localized(
            "Review simulated flight",
            (l10n) => l10n.simulationReviewSimulatedFlight21515c9f,
          ),
        ),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.localized(
                    "Save a continuous section as a new planning route. Unsaved recordings are lost when closing the app.",
                    (l10n) => l10n.simulationSaveAContinuousSectionead8234c,
                  ),
                ),
                const SizedBox(height: 12),
                if (_segments.length > 1)
                  DropdownButtonFormField<int>(
                    initialValue: _segment,
                    decoration: InputDecoration(
                      labelText: context.localized(
                        "Continuous section",
                        (l10n) => l10n.simulationContinuousSection1042d718,
                      ),
                    ),
                    isExpanded: true,
                    items: [
                      for (var i = 0; i < _segments.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            context.localizedWithArgs(
                              "Section {0} · {1} samples",
                              [i + 1, _segments[i].length],
                              (l10n, value) =>
                                  l10n.simulationSectionSamplesb76afcf0(
                                    value(0),
                                    value(1),
                                  ),
                            ),
                          ),
                        ),
                    ],
                    onChanged: _working
                        ? null
                        : (v) => setState(() {
                            _segment = v!;
                            _range = null;
                            _agl = false;
                            _error = null;
                          }),
                  ),
                Semantics(
                  label: context.localizedWithArgs(
                    "Recorded trajectory, north up, with height profile. {0} metres.",
                    [distance.toStringAsFixed(0)],
                    (l10n, value) =>
                        l10n.commonRecordedTrajectoryNorthUp84f04fe5(value(0)),
                  ),
                  child: SizedBox(
                    height: 180,
                    child: CustomPaint(
                      painter: _TrackPainter(
                        selected,
                        points,
                        colors.primary,
                        colors.outlineVariant,
                        _agl && hasAgl,
                      ),
                    ),
                  ),
                ),
                Text(
                  context.localized(
                    "Track: north ↑ · Profile: height in metres",
                    (l10n) => l10n.simulationTrackNorthProfileHeight13701f87,
                  ),
                  style: TextStyle(fontSize: 12),
                ),
                Text(
                  'Height: ${heights.reduce(math.min).toStringAsFixed(1)}–${heights.reduce(math.max).toStringAsFixed(1)} m ${_agl && hasAgl ? 'AGL' : 'WGS84 ellipsoid'}',
                ),
                Text(
                  context.localizedWithArgs(
                    "{0} m in 3D · {1} s · {2} samples → {3} waypoints",
                    [
                      distance.toStringAsFixed(0),
                      seconds.toStringAsFixed(1),
                      selected.length,
                      points.length,
                    ],
                    (l10n, value) => l10n.simulationMInDSeefbaac5(
                      value(0),
                      value(1),
                      value(2),
                      value(3),
                    ),
                  ),
                ),
                Text(
                  context.localizedWithArgs(
                    "Recorded ground speed: {0} · Terrain samples: {1}/{2}",
                    [
                      speeds.isEmpty
                          ? 'unavailable'
                          : '${speeds.reduce(math.min).toStringAsFixed(1)}–${speeds.reduce(math.max).toStringAsFixed(1)} m/s (3D)',
                      measuredGround,
                      selected.length,
                    ],
                    (l10n, value) =>
                        l10n.simulationRecordedGroundSpeedTerrainb2579dd6(
                          value(0),
                          value(1),
                          value(2),
                        ),
                  ),
                ),
                Text(
                  airspeeds.isEmpty
                      ? 'Airspeed: unavailable (groundspeed is not airspeed). '
                            'Enable conservative profile estimates in route analysis if needed.'
                      : 'Simulated airspeed: '
                            '${airspeeds.reduce(math.min).toStringAsFixed(1)}–'
                            '${airspeeds.reduce(math.max).toStringAsFixed(1)} m/s '
                            '(${airspeeds.length}/${selected.length} samples)',
                ),
                if (widget.flight.interrupted)
                  const Text('Recording interrupted; partial track retained.'),
                Text(
                  context.localizedWithArgs(
                    "UTC start: {0} · Per-point elapsed time retained",
                    [widget.flight.startedAt.toUtc().toIso8601String()],
                    (l10n, value) =>
                        l10n.simulationUtcStartPerPoint7a1f6f82(value(0)),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
                if (_segments[_segment].length > 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.localizedWithArgs(
                      "Trim section · samples {0}–{1}",
                      [
                        (_range?.start.round() ?? 0) + 1,
                        (_range?.end.round() ??
                                (_segments[_segment].length - 1)) +
                            1,
                      ],
                      (l10n, value) =>
                          l10n.simulationTrimSectionSamples9e88a826(
                            value(0),
                            value(1),
                          ),
                    ),
                  ),
                  RangeSlider(
                    values:
                        _range ??
                        RangeValues(
                          0,
                          (_segments[_segment].length - 1).toDouble(),
                        ),
                    max: (_segments[_segment].length - 1).toDouble(),
                    divisions: math.min(1000, _segments[_segment].length - 1),
                    onChanged: _working
                        ? null
                        : (r) => setState(() => _range = r),
                  ),
                ],
                const SizedBox(height: 8),
                DropdownButtonFormField<double>(
                  isExpanded: true,
                  initialValue: _tolerance,
                  decoration: InputDecoration(
                    labelText: context.localized(
                      "Maximum simplification deviation",
                      (l10n) =>
                          l10n.simulationMaximumSimplificationDeviationd255b933,
                    ),
                  ),
                  items: [
                    for (final t in [0.0, 1.0, 2.0, 5.0, 10.0, 20.0])
                      DropdownMenuItem(
                        value: t,
                        child: Text(
                          t == 0
                              ? context.localized(
                                  "Keep all samples",
                                  (l10n) =>
                                      l10n.simulationKeepAllSamples1900da8c,
                                )
                              : context.localizedWithArgs(
                                  "{0} m in 3D",
                                  [t.toInt()],
                                  (l10n, value) =>
                                      l10n.simulationMInD2d9450e4(value(0)),
                                ),
                        ),
                      ),
                  ],
                  onChanged: _working
                      ? null
                      : (v) => setState(() => _tolerance = v!),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    context.localized(
                      "Use height above terrain (AGL)",
                      (l10n) => l10n.simulationUseHeightAboveTerrain0cc4fd11,
                    ),
                  ),
                  subtitle: Text(
                    hasAgl
                        ? context.localized(
                            "Based on terrain loaded during recording.",
                            (l10n) =>
                                l10n.simulationBasedOnTerrainLoaded058810aa,
                          )
                        : context.localized(
                            "Unavailable: terrain height is missing for part of this section.",
                            (l10n) => l10n
                                .simulationUnavailableTerrainHeightIs1122a292,
                          ),
                  ),
                  value: _agl && hasAgl,
                  onChanged: _working || !hasAgl
                      ? null
                      : (v) => setState(() => _agl = v),
                ),
                if (!_agl || !hasAgl)
                  Text(
                    context.localized(
                      "Saved height reference: WGS84 ellipsoid. Recorded absolute heights are preserved.",
                      (l10n) => l10n.simulationSavedHeightReferenceWgs6f44e746,
                    ),
                  ),
                if (_agl && hasAgl)
                  Text(
                    context.localized(
                      "AGL follows the terrain between waypoints and may differ from the recorded absolute trajectory.",
                      (l10n) => l10n.simulationAglFollowsTheTerrain71243353,
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  enabled: !_working,
                  maxLength: 120,
                  decoration: InputDecoration(
                    labelText: context.localized(
                      "Route name",
                      (l10n) => l10n.commonRouteName4421bcfb,
                    ),
                  ),
                ),
                Text(
                  context.localized(
                    "Review the saved route before real flight. Sampled motion, terrain and timing are simulated; drone and battery assignments can be added in the route editor.",
                    (l10n) => l10n.commonReviewTheSavedRoute73d944db,
                  ),
                ),
                if (!usable)
                  Text(
                    points.length > 1000
                        ? context.localized(
                            "More than 1000 waypoints: increase simplification or trim the section.",
                            (l10n) => l10n
                                .simulationMoreThanWaypointsIncrease766de83d,
                          )
                        : context.localized(
                            "Record or select at least two positions with movement.",
                            (l10n) => l10n.simulationRecordOrSelectAt4a275e16,
                          ),
                    style: TextStyle(color: colors.error),
                  ),
                if (_error != null)
                  Text(_error!, style: TextStyle(color: colors.error)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _working ? null : _discard,
            child: Text(
              context.localized(
                "Discard",
                (l10n) => l10n.simulationDiscard36fff63c,
              ),
            ),
          ),
          TextButton(
            onPressed: _working ? null : () => Navigator.pop(context),
            child: Text(
              context.localized(
                "Keep for later",
                (l10n) => l10n.simulationKeepForLatera212630b,
              ),
            ),
          ),
          FilledButton(
            onPressed: _working || !usable
                ? null
                : () => _saveRoute(points, agl: _agl && hasAgl),
            child: Text(
              _working
                  ? context.localized(
                      "Saving…",
                      (l10n) => l10n.commonSaving56a2285c,
                    )
                  : context.localized(
                      "Save as route",
                      (l10n) => l10n.simulationSaveAsRouteb13386ba,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  const _TrackPainter(this.raw, this.points, this.color, this.muted, this.agl);
  final List<RecordedFlightPoint> raw, points;
  final Color color, muted;
  final bool agl;
  @override
  void paint(Canvas canvas, Size size) {
    final lat = raw.first.position.latitude * math.pi / 180;
    Offset xy(RecordedFlightPoint p) => Offset(
      ((p.position.longitude - raw.first.position.longitude + 540) % 360 -
              180) *
          math.pi /
          180 *
          6371000 *
          math.cos(lat),
      -(p.position.latitude - raw.first.position.latitude) *
          math.pi /
          180 *
          6371000,
    );
    final coords = raw.map(xy).toList();
    final minX = coords.map((p) => p.dx).reduce(math.min),
        maxX = coords.map((p) => p.dx).reduce(math.max),
        minY = coords.map((p) => p.dy).reduce(math.min),
        maxY = coords.map((p) => p.dy).reduce(math.max);
    final scale = math.min(
      (size.width - 24) / math.max(1, maxX - minX),
      (size.height * .62 - 16) / math.max(1, maxY - minY),
    );
    Offset project(RecordedFlightPoint p) {
      final q = xy(p);
      return Offset(
        size.width / 2 + (q.dx - (minX + maxX) / 2) * scale,
        size.height * .31 + (q.dy - (minY + maxY) / 2) * scale,
      );
    }

    void line(List<Offset> positions, Color c) {
      final path = Path()..moveTo(positions.first.dx, positions.first.dy);
      for (final p in positions.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = c
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }

    line(raw.map(project).toList(), muted);
    line(points.map(project).toList(), color);
    canvas.drawCircle(project(raw.first), 4, Paint()..color = color);
    canvas.drawCircle(
      project(raw.last),
      4,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final heights = raw.map((p) => agl ? p.agl ?? p.height : p.height).toList(),
        lo = raw.isEmpty
            ? 0.0
            : raw
                  .map((p) => agl ? p.agl ?? p.height : p.height)
                  .reduce(math.min),
        hi = heights.reduce(math.max);
    final start = raw.first.seconds,
        span = math.max(.001, raw.last.seconds - start);
    line([
      for (var i = 0; i < raw.length; i++)
        Offset(
          12 + (size.width - 24) * (raw[i].seconds - start) / span,
          size.height -
              8 -
              (heights[i] - lo) / math.max(1, hi - lo) * (size.height * .25),
        ),
    ], color);
  }

  @override
  bool shouldRepaint(_TrackPainter old) => true;
}
