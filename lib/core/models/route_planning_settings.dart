import 'dart:convert';

import 'route_constraints.dart';
import 'signal_settings.dart';
import 'scene_time.dart';

class PowerCurvePoint {
  const PowerCurvePoint(this.speed, this.watts);
  final double speed, watts;
  Map<String, double> toJson() => {'speed': speed, 'watts': watts};
}

/// User planning assumptions, stored with the route rather than global defaults.
class RoutePlanningSettings {
  const RoutePlanningSettings({
    this.windSpeed = 0,
    this.windFromDegrees = 0,
    this.useWind = false,
    this.reservePercent = 20,
    this.includeReturn = true,
    this.optimisticFactor = .8,
    this.conservativeFactor = 1.3,
    this.referenceMassGrams,
    this.flightMassGrams,
    this.climbEfficiency = .65,
    this.powerCurve = const [],
    this.curveSource = 'User estimate',
    this.minimumClearance = 20,
    this.constraints = const RouteConstraints(),
    this.signal,
    this.sceneTime = const SceneTime(),
  });
  final bool useWind, includeReturn;
  final double windSpeed, windFromDegrees, reservePercent;
  final double optimisticFactor,
      conservativeFactor,
      climbEfficiency,
      minimumClearance;
  final double? referenceMassGrams, flightMassGrams;
  final List<PowerCurvePoint> powerCurve;
  final String curveSource;
  final RouteConstraints constraints;
  final SignalSettings? signal;
  final SceneTime sceneTime;

  RoutePlanningSettings withSceneTime(SceneTime value) {
    final j = jsonDecode(encode()) as Map<String, dynamic>;
    j['sceneTime'] = value.toJson();
    return RoutePlanningSettings.decode(jsonEncode(j));
  }

  RoutePlanningSettings withSignal(SignalSettings value) {
    final j = jsonDecode(encode()) as Map<String, dynamic>;
    j['signal'] = value.toJson();
    return RoutePlanningSettings.decode(jsonEncode(j));
  }

  RoutePlanningSettings calibrated(double factor, String source) {
    if (!factor.isFinite || factor < .25 || factor > 4) {
      throw ArgumentError('Calibration factor must be 0.25–4');
    }
    final j = jsonDecode(encode()) as Map<String, dynamic>;
    j['powerCurve'] = [
      for (final p in powerCurve)
        PowerCurvePoint(p.speed, p.watts * factor).toJson(),
    ];
    j['curveSource'] = source;
    return RoutePlanningSettings.decode(jsonEncode(j));
  }

  RoutePlanningSettings withConstraints(RouteConstraints value) {
    final j = jsonDecode(encode()) as Map<String, dynamic>;
    j['constraints'] = value.toJson();
    return RoutePlanningSettings.decode(jsonEncode(j));
  }

  void validate() {
    constraints.validate();
    sceneTime.validate();
    signal?.validate();
    void range(double n, double low, double high, String name) {
      if (!n.isFinite || n < low || n > high) {
        throw ArgumentError('Invalid $name');
      }
    }

    range(windSpeed, 0, 100, 'wind speed');
    range(windFromDegrees, 0, 360, 'wind direction');
    range(reservePercent, 0, 95, 'reserve');
    range(optimisticFactor, .1, 1, 'optimistic factor');
    range(conservativeFactor, 1, 5, 'conservative factor');
    range(climbEfficiency, .01, 1, 'climb efficiency');
    range(minimumClearance, 0, 1000, 'clearance');
    for (final mass in [referenceMassGrams, flightMassGrams]) {
      if (mass != null) range(mass, .1, 1000000, 'mass');
    }
    if (powerCurve.length > 30 ||
        curveSource.trim().isEmpty ||
        curveSource.length > 240) {
      throw ArgumentError('Invalid power curve metadata');
    }
    var previous = -1.0;
    for (final p in powerCurve) {
      range(p.speed, 0, 200, 'curve speed');
      range(p.watts, .01, 1000000, 'curve power');
      if (p.speed <= previous) {
        throw ArgumentError('Curve speeds must increase');
      }
      previous = p.speed;
    }
  }

  String encode() {
    validate();
    final encoded = jsonEncode({
      'version': 1,
      'sceneTime': sceneTime.toJson(),
      'useWind': useWind,
      'windSpeed': windSpeed,
      'windFromDegrees': windFromDegrees,
      'reservePercent': reservePercent,
      'includeReturn': includeReturn,
      'optimisticFactor': optimisticFactor,
      'conservativeFactor': conservativeFactor,
      'referenceMassGrams': referenceMassGrams,
      'flightMassGrams': flightMassGrams,
      'climbEfficiency': climbEfficiency,
      'powerCurve': powerCurve.map((p) => p.toJson()).toList(),
      'curveSource': curveSource,
      'minimumClearance': minimumClearance,
      'constraints': constraints.toJson(),
      if (signal != null) 'signal': signal!.toJson(),
    });
    if (encoded.length > 64000) {
      throw ArgumentError('Planning settings too large');
    }
    return encoded;
  }

  factory RoutePlanningSettings.decode(String encoded) {
    try {
      if (encoded.length > 64000) {
        throw const FormatException('Planning settings too large');
      }
      final j = jsonDecode(encoded) as Map<String, dynamic>;
      if (j.isEmpty) return const RoutePlanningSettings();
      if (j['version'] != 1) {
        throw const FormatException('Unsupported planning settings');
      }
      final value = RoutePlanningSettings(
        sceneTime: j['sceneTime'] == null
            ? const SceneTime()
            : SceneTime.fromJson(j['sceneTime'] as Map<String, dynamic>),
        useWind: j['useWind'] as bool,
        signal: j['signal'] == null
            ? null
            : SignalSettings.fromJson(j['signal'] as Map<String, dynamic>),
        windSpeed: (j['windSpeed'] as num).toDouble(),
        windFromDegrees: (j['windFromDegrees'] as num).toDouble(),
        reservePercent: (j['reservePercent'] as num).toDouble(),
        includeReturn: j['includeReturn'] as bool,
        optimisticFactor: (j['optimisticFactor'] as num).toDouble(),
        conservativeFactor: (j['conservativeFactor'] as num).toDouble(),
        referenceMassGrams: (j['referenceMassGrams'] as num?)?.toDouble(),
        flightMassGrams: (j['flightMassGrams'] as num?)?.toDouble(),
        climbEfficiency: (j['climbEfficiency'] as num).toDouble(),
        minimumClearance: (j['minimumClearance'] as num).toDouble(),
        constraints: j['constraints'] == null
            ? const RouteConstraints()
            : RouteConstraints.fromJson(
                j['constraints'] as Map<String, dynamic>,
              ),
        curveSource: j['curveSource'] as String,
        powerCurve: List.unmodifiable(
          (j['powerCurve'] as List).map(
            (p) => PowerCurvePoint(
              (p['speed'] as num).toDouble(),
              (p['watts'] as num).toDouble(),
            ),
          ),
        ),
      );
      value.validate();
      return value;
    } catch (e) {
      throw FormatException('Invalid route planning settings: $e');
    }
  }
}
