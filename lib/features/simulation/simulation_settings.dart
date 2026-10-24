import 'dart:math' as math;

import '../../core/database/fpv_database.dart';

enum SimulationFlightMode { gps, angle, acro }

class SimulationSettings {
  const SimulationSettings({
    this.agl = 20,
    this.maxSpeed = 15,
    this.climbSpeed = 5,
    this.acceleration = 6,
    this.deceleration = 4,
    this.droneId,
    this.flightMode = SimulationFlightMode.angle,
    this.acroThrustToWeight = 4,
    this.acroThrustCurve = 1,
    this.acroMotorTimeConstant = .04,
    this.acroTerminalVelocity = 35,
  });
  final double agl, maxSpeed, climbSpeed, acceleration, deceleration;
  final int? droneId;
  final SimulationFlightMode flightMode;
  final double acroThrustToWeight,
      acroThrustCurve,
      acroMotorTimeConstant,
      acroTerminalVelocity;
  double get acroHoverThrottle {
    final linear = 1 - acroThrustCurve;
    return (2 / acroThrustToWeight) /
        (linear +
            math.sqrt(
              linear * linear + 4 * acroThrustCurve / acroThrustToWeight,
            ));
  }

  void validate() {
    for (final entry in [
      (agl, 1.0, 1000.0),
      (maxSpeed, .5, 100.0),
      (climbSpeed, .2, 30.0),
      (acceleration, .2, 50.0),
      (deceleration, .2, 50.0),
      (acroThrustToWeight, 1.1, 12.0),
      (acroThrustCurve, 0.0, 1.0),
      (acroMotorTimeConstant, 0.0, .5),
      (acroTerminalVelocity, 5.0, 120.0),
    ]) {
      if (!entry.$1.isFinite || entry.$1 < entry.$2 || entry.$1 > entry.$3) {
        throw ArgumentError('Simulation parameter outside supported range');
      }
    }
  }

  Map<String, dynamic> toCommand() {
    validate();
    return {
      'agl': agl,
      'maxSpeed': maxSpeed,
      'climbSpeed': climbSpeed,
      'acceleration': acceleration,
      'deceleration': deceleration,
      'flightMode': flightMode.name,
      'acroThrustToWeight': acroThrustToWeight,
      'acroThrustCurve': acroThrustCurve,
      'acroMotorTimeConstant': acroMotorTimeConstant,
      'acroTerminalVelocity': acroTerminalVelocity,
    };
  }

  factory SimulationSettings.fromDrone(Drone drone) => SimulationSettings(
    droneId: drone.id,
    maxSpeed: (drone.maxSpeedMetersPerSecond ?? 15).clamp(.5, 100).toDouble(),
    climbSpeed: (drone.maxClimbRateMetersPerSecond ?? 5)
        .clamp(.2, 30)
        .toDouble(),
  );
}
