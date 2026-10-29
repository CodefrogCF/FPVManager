import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/database/repositories/flight_plan_repository.dart';
import '../../core/geo/altitude_service.dart';
import '../../core/geo/geo_coordinate_service.dart';
import '../../core/models/flight_route.dart';

enum RecordingPhase { idle, recording, paused, stopped }

class RecordedFlightPoint {
  const RecordedFlightPoint({
    required this.sequence,
    required this.segment,
    required this.seconds,
    required this.position,
    required this.height,
    this.ground,
  });
  final int sequence, segment;
  final double seconds, height;
  final Wgs84Coordinate position;
  final double? ground;
  double? get agl => ground == null ? null : height - ground!;

  factory RecordedFlightPoint.parse(Object? raw) {
    if (raw is! List || raw.length != 7 || raw[0] is! int || raw[1] is! int) {
      throw const FormatException('Invalid recorded sample');
    }
    double number(int i, double min, double max) {
      final n = raw[i];
      if (n is! num || !n.isFinite || n < min || n > max) {
        throw const FormatException('Invalid recorded position or time');
      }
      return n.toDouble();
    }

    final sequence = raw[0] as int, segment = raw[1] as int;
    if (sequence < 1 || sequence > 4096 || segment < 0 || segment > 4096) {
      throw const FormatException('Invalid recorded sequence');
    }
    return RecordedFlightPoint(
      sequence: sequence,
      segment: segment,
      seconds: number(2, 0, 1800),
      position: Wgs84Coordinate(
        latitude: number(3, -89.9, 89.9),
        longitude: number(4, -180, 180),
      ),
      height: number(5, -100000, 100000),
      ground: raw[6] == null ? null : number(6, -100000, 100000),
    );
  }
}

/// Temporary, bounded receiver. Samples cross the bridge at most twice a second.
/// Renderer loss ends capture but preserves all positions already received.
class FlightRecording extends ChangeNotifier {
  FlightRecording(this.send);
  final Future<void> Function(Map<String, dynamic>) send;
  final _points = <RecordedFlightPoint>[];
  String? id, message;
  DateTime? startedAt;
  RecordingPhase phase = RecordingPhase.idle;
  bool busy = false, _disposed = false, _captureClosed = true;
  int _serial = 0;
  int get count => _points.length;
  bool get hasSamples => _points.isNotEmpty;
  bool get running =>
      phase == RecordingPhase.recording || phase == RecordingPhase.paused;
  List<RecordedFlightPoint> get points => List.unmodifiable(_points);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> control(String action) async {
    if (busy) return;
    if (action == 'start') {
      if (hasSamples || running) {
        throw StateError('Review or discard the existing recording first');
      }
      startedAt = DateTime.now().toUtc();
      id = 'flight-${startedAt!.microsecondsSinceEpoch}-${++_serial}';
      phase = RecordingPhase.recording;
      _captureClosed = false;
    }
    if (id == null) return;
    busy = true;
    message = null;
    _notify();
    try {
      if (action == 'start') {
        // Clear renderer-only remnants of an explicitly discarded recording.
        await send({
          'type': 'flight-recording-control',
          'action': 'restore',
          'id': 'empty-$id',
          'count': 0,
        });
      }
      await send({
        'type': 'flight-recording-control',
        'action': action,
        'id': id,
      });
      if (action == 'stop') {
        phase = RecordingPhase.stopped;
        _captureClosed = true;
      }
      if (action == 'pause' && running) phase = RecordingPhase.paused;
      if (action == 'resume' && phase == RecordingPhase.paused) {
        phase = RecordingPhase.recording;
      }
    } catch (_) {
      phase = RecordingPhase.stopped;
      _captureClosed = true;
      message = 'Recording interrupted. Received positions are retained; review or discard them.';
      rethrow;
    } finally {
      busy = false;
      _notify();
    }
  }

  bool handle(Map<String, dynamic> event) {
    if (!{
      'flight-recording-sample',
      'flight-recording-state',
    }.contains(event['type'])) {
      return false;
    }
    if (event['id'] != id || id == null || _disposed) return true;
    if (event['type'] == 'flight-recording-state') {
      final next = RecordingPhase.values
          .where((p) => p.name == event['phase'])
          .firstOrNull;
      if (next != null) {
        if (_captureClosed &&
            (next == RecordingPhase.recording ||
                next == RecordingPhase.paused)) {
          return true;
        }
        phase = next;
        if (next == RecordingPhase.stopped) _captureClosed = true;
        final reason = event['reason'];
        if (reason is String) {
          message = reason.substring(0, reason.length.clamp(0, 180));
        }
        _notify();
      }
      return true;
    }
    if (!running || count >= 4096) return true;
    try {
      final point = RecordedFlightPoint.parse(event['sample']);
      if (point.sequence != count + 1 ||
          _points.isNotEmpty &&
              (point.seconds <= _points.last.seconds ||
                  point.segment < _points.last.segment)) {
        throw const FormatException('Interrupted recorded sequence');
      }
      _points.add(point);
      if (count == 4096) {
        phase = RecordingPhase.stopped;
        _captureClosed = true;
      }
      if (count == 1 || count.isEven || !running) _notify();
    } on FormatException {
      rendererLost(
        'Invalid or missing sample. Recording stopped; received positions are retained.',
      );
      unawaited(
        send({'type': 'flight-recording-control', 'action': 'stop', 'id': id})
            .catchError((Object _) {}),
      );
    }
    return true;
  }

  void rendererLost([String? reason]) {
    if (!running) return;
    phase = RecordingPhase.stopped;
    _captureClosed = true;
    message =
        reason ??
        'Renderer connection interrupted. Received positions are retained.';
    _notify();
  }

  Future<void> restore() async {
    if (id != null) {
      await send({
        'type': 'flight-recording-control',
        'action': 'restore',
        'id': id,
        'count': count,
      });
    }
  }

  /// Local discard also works without a renderer. The old ID rejects late data.
  void discard() {
    id = null;
    _points.clear();
    phase = RecordingPhase.idle;
    _captureClosed = true;
    startedAt = null;
    message = null;
    _notify();
  }

  RecordedFlight snapshot() => RecordedFlight(id!, startedAt!, _points);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class RecordedFlight {
  RecordedFlight(this.id, this.startedAt, List<RecordedFlightPoint> points)
    : points = List.unmodifiable(points);
  final String id;
  final DateTime startedAt;
  final List<RecordedFlightPoint> points;
  List<List<RecordedFlightPoint>> get segments {
    final result = <List<RecordedFlightPoint>>[];
    for (final p in points) {
      if (result.isEmpty || result.last.last.segment != p.segment) {
        result.add([]);
      }
      result.last.add(p);
    }
    return result;
  }
}

/// Iterative 3D Ramer-Douglas-Peucker over WGS84 ECEF chords. The tolerance
/// bounds deviation from retained chords, not from unobserved flight motion.
List<RecordedFlightPoint> simplifyRecording(
  List<RecordedFlightPoint> points,
  double tolerance,
) {
  if (!tolerance.isFinite ||
      tolerance < 0 ||
      tolerance > 20 ||
      points.length > 4096) {
    throw ArgumentError('Invalid recording simplification');
  }
  if (points.length < 3 || tolerance == 0) return List.unmodifiable(points);
  final vectors = points.map(_ecef).toList();
  final keep = <int>{0, points.length - 1};
  final ranges = <(int, int)>[(0, points.length - 1)];
  while (ranges.isNotEmpty) {
    final (a, b) = ranges.removeLast();
    var farthest = -1, maxSquared = tolerance * tolerance;
    for (var i = a + 1; i < b; i++) {
      final d = _chordDistanceSquared(vectors[i], vectors[a], vectors[b]);
      if (d > maxSquared) {
        maxSquared = d;
        farthest = i;
      }
    }
    if (farthest >= 0) {
      keep.add(farthest);
      ranges.add((a, farthest));
      ranges.add((farthest, b));
    }
  }
  final indices = keep.toList()..sort();
  return List.unmodifiable(indices.map((i) => points[i]));
}

(double, double, double) _ecef(RecordedFlightPoint p) {
  final lat = p.position.latitude * math.pi / 180,
      lon = p.position.longitude * math.pi / 180;
  const a = 6378137.0, e2 = 6.6943799901413165e-3;
  final n = a / math.sqrt(1 - e2 * math.pow(math.sin(lat), 2));
  return (
    (n + p.height) * math.cos(lat) * math.cos(lon),
    (n + p.height) * math.cos(lat) * math.sin(lon),
    (n * (1 - e2) + p.height) * math.sin(lat),
  );
}

double _chordDistanceSquared(
  (double, double, double) p,
  (double, double, double) a,
  (double, double, double) b,
) {
  final x = b.$1 - a.$1, y = b.$2 - a.$2, z = b.$3 - a.$3;
  final length = x * x + y * y + z * z;
  final t = length == 0
      ? 0.0
      : ((p.$1 - a.$1) * x + (p.$2 - a.$2) * y + (p.$3 - a.$3) * z) / length;
  final f = t.clamp(0.0, 1.0);
  return math.pow(p.$1 - a.$1 - f * x, 2).toDouble() +
      math.pow(p.$2 - a.$2 - f * y, 2) +
      math.pow(p.$3 - a.$3 - f * z, 2);
}

double recordedDistance(List<RecordedFlightPoint> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += math.sqrt(
      _chordDistanceSquared(
        _ecef(points[i]),
        _ecef(points[i - 1]),
        _ecef(points[i - 1]),
      ),
    );
  }
  return total;
}

List<RouteWaypointInput> recordingWaypoints(
  List<RecordedFlightPoint> points, {
  required bool agl,
}) {
  if (points.length < 2 ||
      points.length > 1000 ||
      recordedDistance(points) < .1 ||
      points.any((p) => p.segment != points.first.segment)) {
    throw ArgumentError(
      'Choose a continuous moving segment with 2–1000 waypoints',
    );
  }
  return List.unmodifiable(
    points.map((p) {
      if (agl && (p.agl == null || p.agl! < 0)) {
        throw ArgumentError('AGL is unavailable for this segment');
      }
      return RouteWaypointInput(
        position: p.position,
        height: agl
            ? AglWaypointHeight(AboveGroundHeight(p.agl!))
            : AbsoluteWaypointHeight(
                ReferencedElevation(
                  meters: p.height,
                  reference: VerticalReference.wgs84Ellipsoid,
                ),
              ),
      );
    }),
  );
}

/// Keeps failed saves retryable and prevents concurrent taps from duplicating a route.
class RecordingRouteSave {
  bool saving = false;
  int? savedId;
  Future<int?> save(
    FlightPlanRepository repository, {
    required String name,
    required List<RouteWaypointInput> points,
  }) async {
    if (saving || savedId != null) return savedId;
    if (name.trim().isEmpty || name.trim().length > 120) {
      throw ArgumentError('Enter a route name');
    }
    if (points.length < 2 || points.length > 1000) {
      throw ArgumentError('A recorded route supports 2–1000 waypoints');
    }
    saving = true;
    try {
      return savedId = await repository.saveRoute(
        name: name.trim(),
        notes: 'Created from a simulated flight. Review before real flight.',
        waypoints: points,
      );
    } finally {
      saving = false;
    }
  }
}
