import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The origin of an airspeed reading, not an assertion of sensor accuracy.
/// Ground speed and WGS84 heights from the simulator are always identified as
/// simulated values; they must never be relabeled as measured airspeed.
enum RecordedAirspeedSource { simulator, measured }

/// Compact, route-signature-bound telemetry saved with a simulated route.
/// Version 1 tracks (four values per sample) remain readable. Version 2 adds
/// optional airspeed and a clearly identified source; unknown is never zero.
class RecordedRouteTrack {
  RecordedRouteTrack({
    required this.id,
    required this.startedAtUtc,
    required this.waypointSignature,
    required List<RecordedTrackSample> samples,
    this.interrupted = false,
  }) : samples = List.unmodifiable(samples) {
    validate();
  }

  final String id;
  final DateTime startedAtUtc;
  final String waypointSignature;
  final List<RecordedTrackSample> samples;
  final bool interrupted;

  /// Duration of the selected continuous track, not an assumed flight time.
  double get durationSeconds => samples.last.seconds - samples.first.seconds;

  /// Timestamp of a sample in the original recording session (UTC).
  DateTime timestampAt(RecordedTrackSample sample) => startedAtUtc.add(
    Duration(microseconds: (sample.seconds * 1000000).round()),
  );

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

  /// Interpolated *simulated* telemetry for virtual replay, not measurement.
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
    final sameSource =
        a.airspeedSource != null && a.airspeedSource == b.airspeedSource;
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
      airspeedMetersPerSecond: sameSource
          ? optional(a.airspeedMetersPerSecond, b.airspeedMetersPerSecond)
          : null,
      airspeedSource: sameSource ? a.airspeedSource : null,
    );
  }

  /// Numeric sample arrays are rounded before persistence to keep the 64 KiB
  /// planning_json limit practical for a 1000-point recording.
  Map<String, Object?> toJson() => {
    'version': 2,
    'id': id,
    'startedAtUtc': startedAtUtc.toIso8601String(),
    'waypointSignature': waypointSignature,
    if (interrupted) 'interrupted': true,
    'samples': [for (final sample in samples) sample.toJson()],
  };

  factory RecordedRouteTrack.fromJson(Object? value) {
    try {
      final json = value as Map<String, dynamic>;
      final version = json['version'];
      if (version != 1 && version != 2) {
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
      if (json['interrupted'] != null && json['interrupted'] is! bool) {
        throw const FormatException('Invalid interruption flag');
      }
      return RecordedRouteTrack(
        id: json['id'] as String,
        startedAtUtc: start,
        waypointSignature: json['waypointSignature'] as String,
        interrupted: json['interrupted'] == true,
        samples: [
          for (final item in raw)
            RecordedTrackSample.fromJson(item, version: version as int),
        ],
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
    this.airspeedMetersPerSecond,
    this.airspeedSource,
  });

  /// Seconds since session start, 0–1800, including time spent paused.
  final double seconds;

  /// Simulated altitude (metres, WGS84 ellipsoid); never silently MSL.
  final double absoluteElevationMeters;

  /// Simulated terrain elevation (metres, WGS84 ellipsoid), null = unavailable.
  final double? terrainElevationMeters;

  /// Simulated 3D ground speed (m/s), not planned or measured airspeed.
  final double? groundSpeedMetersPerSecond;

  /// Separate, optional airspeed (m/s) and its origin.
  final double? airspeedMetersPerSecond;
  final RecordedAirspeedSource? airspeedSource;

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
                groundSpeedMetersPerSecond! > 200)) ||
        (airspeedMetersPerSecond != null &&
            (!airspeedMetersPerSecond!.isFinite ||
                airspeedMetersPerSecond! < 0 ||
                airspeedMetersPerSecond! > 200)) ||
        (airspeedMetersPerSecond == null) != (airspeedSource == null)) {
      throw const FormatException('Invalid recorded height, speed or time');
    }
  }

  static double? _compact(double? n, int places) {
    if (n == null) return null;
    final multiplier = places == 6 ? 1000000 : 100;
    return (n * multiplier).round() / multiplier;
  }

  List<Object?> toJson() => [
    _compact(seconds, 6),
    _compact(groundSpeedMetersPerSecond, 2),
    _compact(absoluteElevationMeters, 2),
    _compact(terrainElevationMeters, 2),
    _compact(airspeedMetersPerSecond, 2),
    airspeedSource?.name,
  ];

  factory RecordedTrackSample.fromJson(Object? raw, {int version = 2}) {
    try {
      final values = raw as List;
      if (values.length != (version == 1 ? 4 : 6)) {
        throw const FormatException('Invalid recording sample format');
      }
      double? number(Object? v) => v == null ? null : (v as num).toDouble();
      final source = version == 2 && values[5] != null
          ? RecordedAirspeedSource.values.byName(values[5] as String)
          : null;
      final sample = RecordedTrackSample(
        seconds: number(values[0])!,
        groundSpeedMetersPerSecond: number(values[1]),
        absoluteElevationMeters: number(values[2])!,
        terrainElevationMeters: number(values[3]),
        airspeedMetersPerSecond: version == 2 ? number(values[4]) : null,
        airspeedSource: source,
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
