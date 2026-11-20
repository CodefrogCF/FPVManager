import 'dart:math' as math;

import '../../core/database/fpv_database.dart';
import 'controller_settings.dart';
import 'signal_hud_settings.dart';
import 'failsafe_settings.dart';
import 'simulation_battery_profile.dart';
import '../../core/models/scene_time.dart';

enum SimulationFlightMode { gps, angle, acro }

/// Legacy preserves v0.18 behaviour; advanced uses fixed physics substeps.
enum SimulationPhysicsModel { legacy, advanced }

enum SimulationGraphicsProfile { quality, balanced, performance, compatibility }

enum SimulationHudStyle { goggles, betaflight }

class SimulationSettings {
  const SimulationSettings({
    this.agl = 20,
    this.maxSpeed = 15,
    this.climbSpeed = 5,
    this.acceleration = 6,
    this.deceleration = 4,
    this.droneId,
    this.flightMode = SimulationFlightMode.angle,
    this.physicsModel = SimulationPhysicsModel.legacy,
    this.physicsStepHz = 120,
    this.cameraTiltDegrees = 0,
    this.cameraFovDegrees = 90,
    this.graphicsProfile = SimulationGraphicsProfile.balanced,
    this.hudStyle = SimulationHudStyle.goggles,
    this.showCoordinates = false,
    this.signalHud = const SignalHudSettings(),
    this.failsafe = const FailsafeSettings(),
    this.showBatteryVoltage = false,
    this.showBatteryCellVoltage = false,
    this.lowBatteryCellVoltage = 3.5,
    this.criticalBatteryCellVoltage = 3.3,
    this.batterySagResistanceOhmsPerCell = 0,
    this.batteryUseChemistryThresholds = true,
    this.batteryProfile,
    this.controller = const ControllerSettings(),
    this.acroThrustToWeight = 4,
    this.acroThrustCurve = 1,
    this.acroMotorTimeConstant = .04,
    this.acroTerminalVelocity = 22.5,
    this.acroRollRate = 180,
    this.acroPitchRate = 180,
    this.acroYawRate = 180,
    this.acroRateExpo = 0,
    this.sceneTime = const SceneTime(),
  });
  final double agl, maxSpeed, climbSpeed, acceleration, deceleration;
  final int? droneId;
  final SimulationFlightMode flightMode;
  final SimulationPhysicsModel physicsModel;
  final int physicsStepHz;
  final double cameraTiltDegrees;

  /// Horizontal FPV camera field of view in degrees (not a focal length).
  final double cameraFovDegrees;
  final SimulationGraphicsProfile graphicsProfile;
  final SimulationHudStyle hudStyle;
  final bool showCoordinates;
  final SignalHudSettings signalHud;
  final FailsafeSettings failsafe;
  final bool showBatteryVoltage, showBatteryCellVoltage;
  final double lowBatteryCellVoltage, criticalBatteryCellVoltage;

  /// Chemistry-derived warning levels are used unless explicitly overridden.
  final bool batteryUseChemistryThresholds;
  final double batterySagResistanceOhmsPerCell;
  final SimulationBatteryProfile? batteryProfile;
  final ControllerSettings controller;
  final SceneTime sceneTime;
  SimulationSettings withCameraTilt(
    double degrees, {
    double? cameraFovDegrees,
    SimulationGraphicsProfile? graphicsProfile,
    SimulationHudStyle? hudStyle,
    bool? showCoordinates,
    SignalHudSettings? signalHud,
    FailsafeSettings? failsafe,
    bool? showBatteryVoltage,
    bool? showBatteryCellVoltage,
    double? lowBatteryCellVoltage,
    double? criticalBatteryCellVoltage,
    double? batterySagResistanceOhmsPerCell,
    bool? batteryUseChemistryThresholds,
    ControllerSettings? controller,
    SimulationPhysicsModel? physicsModel,
    int? physicsStepHz,
    SceneTime? sceneTime,
  }) => SimulationSettings(
    agl: agl,
    maxSpeed: maxSpeed,
    climbSpeed: climbSpeed,
    acceleration: acceleration,
    deceleration: deceleration,
    droneId: droneId,
    flightMode: flightMode,
    physicsModel: physicsModel ?? this.physicsModel,
    physicsStepHz: physicsStepHz ?? this.physicsStepHz,
    cameraTiltDegrees: degrees,
    cameraFovDegrees: cameraFovDegrees ?? this.cameraFovDegrees,
    graphicsProfile: graphicsProfile ?? this.graphicsProfile,
    hudStyle: hudStyle ?? this.hudStyle,
    showCoordinates: showCoordinates ?? this.showCoordinates,
    signalHud: signalHud ?? this.signalHud,
    failsafe: failsafe ?? this.failsafe,
    showBatteryVoltage: showBatteryVoltage ?? this.showBatteryVoltage,
    showBatteryCellVoltage:
        showBatteryCellVoltage ?? this.showBatteryCellVoltage,
    lowBatteryCellVoltage: lowBatteryCellVoltage ?? this.lowBatteryCellVoltage,
    criticalBatteryCellVoltage:
        criticalBatteryCellVoltage ?? this.criticalBatteryCellVoltage,
    batterySagResistanceOhmsPerCell:
        batterySagResistanceOhmsPerCell ?? this.batterySagResistanceOhmsPerCell,
    batteryUseChemistryThresholds:
        batteryUseChemistryThresholds ?? this.batteryUseChemistryThresholds,
    batteryProfile: batteryProfile,
    controller: controller ?? this.controller,
    sceneTime: sceneTime ?? this.sceneTime,
    acroThrustToWeight: acroThrustToWeight,
    acroThrustCurve: acroThrustCurve,
    acroMotorTimeConstant: acroMotorTimeConstant,
    acroTerminalVelocity: acroTerminalVelocity,
    acroRollRate: acroRollRate,
    acroPitchRate: acroPitchRate,
    acroYawRate: acroYawRate,
    acroRateExpo: acroRateExpo,
  );
  final double acroThrustToWeight,
      acroThrustCurve,
      acroMotorTimeConstant,
      acroTerminalVelocity;
  final double acroRollRate, acroPitchRate, acroYawRate, acroRateExpo;

  /// Full-throttle steady level flight in the current isotropic drag model.
  /// Vertical thrust balances gravity; remaining thrust balances horizontal drag.
  double get acroEstimatedLevelSpeedKmh =>
      acroTerminalVelocity *
      math.pow(acroThrustToWeight * acroThrustToWeight - 1, .25) *
      3.6;
  double get acroHoverThrottle {
    final linear = 1 - acroThrustCurve;
    return (2 / acroThrustToWeight) /
        (linear +
            math.sqrt(
              linear * linear + 4 * acroThrustCurve / acroThrustToWeight,
            ));
  }

  void validate() {
    if (![60, 120, 240].contains(physicsStepHz)) {
      throw ArgumentError('Unsupported simulation physics rate');
    }
    controller.validate();
    sceneTime.validate();
    batteryProfile?.validate();
    signalHud.validate();
    failsafe.validate();
    if (!lowBatteryCellVoltage.isFinite ||
        !criticalBatteryCellVoltage.isFinite ||
        criticalBatteryCellVoltage < .5 ||
        criticalBatteryCellVoltage > 4.4 ||
        lowBatteryCellVoltage < .6 ||
        lowBatteryCellVoltage > 4.5 ||
        lowBatteryCellVoltage <= criticalBatteryCellVoltage ||
        !batterySagResistanceOhmsPerCell.isFinite ||
        batterySagResistanceOhmsPerCell < 0 ||
        batterySagResistanceOhmsPerCell > .1) {
      throw ArgumentError('Invalid battery HUD configuration');
    }
    for (final entry in [
      (agl, 1.0, 1000.0),
      (maxSpeed, .5, 100.0),
      (climbSpeed, .2, 30.0),
      (acceleration, .2, 50.0),
      (deceleration, .2, 50.0),
      (cameraTiltDegrees, 0.0, 80.0),
      (cameraFovDegrees, 50.0, 140.0),
      (acroThrustToWeight, 1.1, 12.0),
      (acroThrustCurve, 0.0, 1.0),
      (acroMotorTimeConstant, 0.0, .5),
      (acroTerminalVelocity, 5.0, 120.0),
      (acroRollRate, 10.0, 1500.0),
      (acroPitchRate, 10.0, 1500.0),
      (acroYawRate, 10.0, 1500.0),
      (acroRateExpo, 0.0, 1.0),
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
      'sceneTime': sceneTime.toJson(),
      'maxSpeed': maxSpeed,
      'climbSpeed': climbSpeed,
      'acceleration': acceleration,
      'deceleration': deceleration,
      'flightMode': flightMode.name,
      'physicsModel': physicsModel.name,
      'physicsStepHz': physicsStepHz,
      'cameraTiltDegrees': cameraTiltDegrees,
      'cameraFovDegrees': cameraFovDegrees,
      'graphicsProfile': graphicsProfile.name,
      'hudStyle': hudStyle.name,
      'showCoordinates': showCoordinates,
      'signalHud': signalHud.toJson(),
      'failsafe': failsafe.toJson(),
      'showBatteryVoltage': showBatteryVoltage,
      'showBatteryCellVoltage': showBatteryCellVoltage,
      'lowBatteryCellVoltage': lowBatteryCellVoltage,
      'criticalBatteryCellVoltage': criticalBatteryCellVoltage,
      'batterySagResistanceOhmsPerCell': batterySagResistanceOhmsPerCell,
      'batteryUseChemistryThresholds': batteryUseChemistryThresholds,
      'batteryProfile': batteryProfile?.toJson(),
      'controller': controller.toJson(),
      'acroThrustToWeight': acroThrustToWeight,
      'acroThrustCurve': acroThrustCurve,
      'acroMotorTimeConstant': acroMotorTimeConstant,
      'acroTerminalVelocity': acroTerminalVelocity,
      'acroRollRate': acroRollRate,
      'acroPitchRate': acroPitchRate,
      'acroYawRate': acroYawRate,
      'acroRateExpo': acroRateExpo,
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
