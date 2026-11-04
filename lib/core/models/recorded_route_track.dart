import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Versioned, compact metadata for the recorded samples retained as route
/// waypoints. This is simulated *ground* speed, not planned airspeed.
/// The route's actual coordinates and selected waypoint height modes remain in
/// flight_waypoints. A signature prevents replaying stale telemetry after edits.
class RecordedRouteTrack {
  RecordedRouteTrack({
    required this.id,
    required this.startedAtUtc,
    required this.waypointSignature,
    required List<RecordedTrackSample> samples,
  }) : samples = List.unmodifiable(samples) {
    validate();
  }

  final String id;
  final DateTime startedAtUtc;
  final String waypointSignature;
  final List<RecordedTrackSample> samples;

  static String signature(Iterable<List<Object?>> canonicalWaypoints) => sha256
      .convert(utf8.encode(jsonEncode(canonicalWaypoints.toList())))
      .toString();

  void validate() {
    if (id.isEmpty ||
        id.length > 100 ||
        waypointSignature.length != 64 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(waypointSignature) ||
        !startedAtUtc.isUtc ||
        samples.length < 2 ||
        samples.length > 1000) {
      throw const FormatException('Invalid recorded route metadata');
    }
    var previous = -1.0;
    for (final sample in samples) {
      sample.validate();
      if (sample.seconds <= previous) {
        throw const FormatException('Recording timestamps must increase');
      }
      previous = sample.seconds;
    }
  }

  /// Interpolated telemetry for virtual replay, never a direct measurement.
  /// Requests outside the captured window are clamped to its endpoints.
  RecordedTrackSample sampleAt(double elapsedSeconds) {
    if (!elapsedSeconds.isFinite) {
      throw ArgumentError('Replay time must be finite');
    }
    if (elapsedSeconds <= samples.first.seconds) return samples.first;
    if (elapsedSeconds >= samples.last.seconds) return samples.last;
    var lower = 0, upper = samples.length - 1;
    while (upper - lower > 1) {
      final middle = (upper + lower) ~/ 2;
      if (samples[middle].seconds <= elapsedSeconds) {
        lower = middle;
      } else {
        upper = middle;
      }
    }
    final a = samples[lower], b = samples[upper];
    final fraction = (elapsedSeconds - a.seconds) / (b.seconds - a.seconds);
    double blend(double first, double last) =>
        first + (last - first) * fraction;
    double? optional(double? first, double? last) =>
        first == null || last == null ? null : blend(first, last);
    return RecordedTrackSample(
      seconds: elapsedSeconds,
      absoluteElevationMeters: blend(
        a.absoluteElevationMeters,
        b.absoluteElevationMeters,
      ),
      terrainElevationMeters: optional(
        a.terrainElevationMeters,
        b.terrainElevationMeters,
      ),
      groundSpeedMetersPerSecond: optional(
        a.groundSpeedMetersPerSecond,
        b.groundSpeedMetersPerSecond,
      ),
    );
  }

  /// Compact numeric arrays bound the 64 KiB planning_json field. Absolute and
  /// terrain elevations use the WGS84 ellipsoid in metres; null = unavailable.
  Map<String, Object?> toJson() => {
    'version': 1,
    'id': id,
    'startedAtUtc': startedAtUtc.toIso8601String(),
    'waypointSignature': waypointSignature,
    'samples': [for (final sample in samples) sample.toJson()],
  };

  factory RecordedRouteTrack.fromJson(Object? value) {
    try {
      final json = value as Map<String, dynamic>;
      if (json['version'] != 1) {
        throw const FormatException('Unsupported recorded route version');
      }
      final raw = json['samples'] as List;
      if (raw.length < 2 || raw.length > 1000) {
        throw const FormatException('Invalid recorded sample count');
      }
      final start = DateTime.parse(json['startedAtUtc'] as String);
      if (!start.isUtc || !(json['startedAtUtc'] as String).endsWith('Z')) {
        throw const FormatException('Recording start must be UTC');
      }
      return RecordedRouteTrack(
        id: json['id'] as String,
        startedAtUtc: start,
        waypointSignature: json['waypointSignature'] as String,
        samples: [for (final item in raw) RecordedTrackSample.fromJson(item)],
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Malformed recorded route metadata');
    }
  }
}

class RecordedTrackSample {
  const RecordedTrackSample({
    required this.seconds,
    required this.absoluteElevationMeters,
    this.terrainElevationMeters,
    this.groundSpeedMetersPerSecond,
  });

  /// Seconds since the recording started (0–1800 s).
  final double seconds;

  /// Absolute simulated position in metres, WGS84 ellipsoid reference.
  final double absoluteElevationMeters;

  /// Terrain elevation in metres, WGS84 ellipsoid; null means AGL is unknown.
  final double? terrainElevationMeters;

  /// Simulator's 3D ground speed (m/s). Null for legacy/unknown readings.
  final double? groundSpeedMetersPerSecond;

  double? get aglMeters => terrainElevationMeters == null
      ? null
      : absoluteElevationMeters - terrainElevationMeters!;

  void validate() {
    if (!seconds.isFinite ||
        seconds < 0 ||
        seconds > 1800 ||
        !absoluteElevationMeters.isFinite ||
        absoluteElevationMeters.abs() > 100000 ||
        (terrainElevationMeters != null &&
            (!terrainElevationMeters!.isFinite ||
                terrainElevationMeters!.abs() > 100000 ||
                terrainElevationMeters! > absoluteElevationMeters)) ||
        (groundSpeedMetersPerSecond != null &&
            (!groundSpeedMetersPerSecond!.isFinite ||
                groundSpeedMetersPerSecond! < 0 ||
                groundSpeedMetersPerSecond! > 200))) {
      throw const FormatException('Invalid recorded height, speed or time');
    }
  }

  List<Object?> toJson() => [
    seconds,
    groundSpeedMetersPerSecond,
    absoluteElevationMeters,
    terrainElevationMeters,
  ];

  factory RecordedTrackSample.fromJson(Object? raw) {
    try {
      final values = raw as List;
      if (values.length != 4) {
        throw const FormatException('Invalid recording sample format');
      }
      double? number(Object? v) => v == null ? null : (v as num).toDouble();
      final sample = RecordedTrackSample(
        seconds: number(values[0])!,
        groundSpeedMetersPerSecond: number(values[1]),
        absoluteElevationMeters: number(values[2])!,
        terrainElevationMeters: number(values[3]),
      );
      sample.validate();
      return sample;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid numeric recording sample');
    }
  }
}
