import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/models/bounded_csv.dart';
import '../../core/models/route_planning_settings.dart';

class TelemetrySample {
  const TelemetrySample(this.seconds, this.speed, this.voltage, this.current);
  final double seconds, speed, voltage, current;
  double get watts => voltage * current;
}

class TelemetryLog {
  TelemetryLog._(this.samples, this.format, this.isAirspeed);
  final List<TelemetrySample> samples;
  final String format;
  final bool isAirspeed;
  double get duration => samples.last.seconds - samples.first.seconds;
  double _integrate(double Function(TelemetrySample) value) {
    var total = 0.0;
    for (var i = 1; i < samples.length; i++) {
      total +=
          (value(samples[i - 1]) + value(samples[i])) *
          .5 *
          (samples[i].seconds - samples[i - 1].seconds);
    }
    return total;
  }

  double get energyWh => _integrate((s) => s.watts) / 3600;
  double get averageSpeed => _integrate((s) => s.speed) / duration;
  double get maxSpeed => samples.map((s) => s.speed).reduce(math.max);
  double get distance => _integrate((s) => s.speed);
  double get averagePower => energyWh * 3600 / duration;

  factory TelemetryLog.decode(Uint8List bytes) {
    final rows = readBoundedCsv(bytes),
        header = rows.first.map((h) => h.trim()).toList();
    int column(List<String> names) {
      final matches = [
        for (var i = 0; i < header.length; i++)
          if (names.contains(header[i])) i,
      ];
      if (matches.length != 1) {
        throw FormatException('Expected one column: ${names.join(" or ")}');
      }
      return matches.single;
    }

    final canonical = header.contains('time_s');
    final time = column(canonical ? ['time_s'] : ['Time']);
    final date = canonical ? -1 : column(['Date']);
    final airspeed = canonical && header.contains('airspeed_m_s');
    final speed = column(
      canonical
          ? ['airspeed_m_s', 'groundspeed_m_s']
          : ['GSpd(kmh)', 'GSpd(km/h)', 'GSpd(m/s)', 'GSpd(kts)'],
    );
    final voltage = column(canonical ? ['voltage_v'] : ['VFAS(V)', 'Bat(V)']);
    final current = column(canonical ? ['current_a'] : ['Curr(A)']);
    double number(String value, double maximum) {
      final n = double.tryParse(value.trim());
      if (n == null || !n.isFinite || n < 0 || n > maximum) {
        throw const FormatException(
          'Missing, invalid or out-of-range telemetry measurement',
        );
      }
      return n;
    }

    final samples = <TelemetrySample>[];
    double? origin;
    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.length != header.length) {
        throw FormatException('CSV row ${r + 1} has a different column count');
      }
      double seconds;
      if (canonical) {
        seconds = number(row[time], 1e9);
      } else {
        final d = row[date], t = row[time];
        if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d) ||
            !RegExp(r'^\d{2}:\d{2}:\d{2}(\.\d{1,3})?$').hasMatch(t)) {
          throw const FormatException(
            'Use EdgeTX Date and Time columns with calendar timestamps',
          );
        }
        final dt = DateTime.tryParse('${d}T${t}Z');
        if (dt == null ||
            dt.toIso8601String().substring(0, 19) !=
                '${d}T${t.split('.').first}') {
          throw const FormatException('Invalid telemetry timestamp');
        }
        seconds = dt.millisecondsSinceEpoch / 1000;
      }
      origin ??= seconds;
      seconds -= origin;
      if (seconds > 21600 ||
          (samples.isNotEmpty &&
              (seconds <= samples.last.seconds ||
                  seconds - samples.last.seconds > 30))) {
        throw const FormatException(
          'Import one continuous flight: increasing times, gaps at most 30 s, duration at most 6 h',
        );
      }
      var velocity = number(row[speed], canonical ? 200 : 720);
      if (!canonical) {
        if (header[speed].contains('km')) velocity /= 3.6;
        if (header[speed].contains('kts')) velocity *= .514444;
      }
      if (velocity > 200) throw const FormatException('Speed exceeds 200 m/s');
      samples.add(
        TelemetrySample(
          seconds,
          velocity,
          number(row[voltage], 1000),
          number(row[current], 10000),
        ),
      );
    }
    if (samples.length < 2 || samples.length > 20000) {
      throw const FormatException('Use 2–20000 telemetry samples');
    }
    return TelemetryLog._(
      List.unmodifiable(samples),
      canonical ? 'FPVManager telemetry CSV v1' : 'EdgeTX SD Logs CSV',
      airspeed,
    );
  }

  TelemetryComparison compare(
    RoutePlanningSettings settings, {
    double? droneMass,
    bool assumeStillAir = false,
  }) {
    settings.validate();
    final mass = settings.flightMassGrams ?? droneMass,
        reference = settings.referenceMassGrams;
    if (!isAirspeed && !assumeStillAir) {
      return const TelemetryComparison(
        problem: 'GPS ground speed is not airspeed. Confirm a still-air approximation to compare the level-flight model.',
      );
    }
    if (mass == null ||
        reference == null ||
        mass <= 0 ||
        settings.powerCurve.length < 2) {
      return const TelemetryComparison(
        problem: 'The route needs a power curve with at least two points, takeoff mass and reference mass.',
      );
    }
    final curve = settings.powerCurve;
    double? watts(double speed) {
      if (speed < curve.first.speed || speed > curve.last.speed) return null;
      for (var i = 1; i < curve.length; i++) {
        if (speed <= curve[i].speed) {
          final a = curve[i - 1], b = curve[i];
          return (a.watts +
                  (b.watts - a.watts) *
                      (speed - a.speed) /
                      (b.speed - a.speed)) *
              math.pow(mass / reference, 1.5);
        }
      }
      return null;
    }

    final modeled = samples.map((s) => watts(s.speed)).toList();
    if (modeled.any((v) => v == null)) {
      return const TelemetryComparison(
        problem: 'Measured speeds lie outside the route power curve. No extrapolation is used.',
      );
    }
    var energy = 0.0;
    for (var i = 1; i < samples.length; i++) {
      energy +=
          (modeled[i - 1]! + modeled[i]!) *
          .5 *
          (samples[i].seconds - samples[i - 1].seconds) /
          3600;
    }
    return TelemetryComparison(predictedWh: energy, measuredWh: energyWh);
  }
}

class TelemetryComparison {
  const TelemetryComparison({this.predictedWh, this.measuredWh, this.problem});
  final double? predictedWh, measuredWh;
  final String? problem;
  double? get differenceWh =>
      predictedWh == null ? null : measuredWh! - predictedWh!;
  double? get factor => predictedWh == null || predictedWh! <= 0
      ? null
      : measuredWh! / predictedWh!;
  bool get canCalibrate =>
      factor != null && factor!.isFinite && factor! >= .25 && factor! <= 4;
}
