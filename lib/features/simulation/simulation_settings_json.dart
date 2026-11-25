part of 'simulation_settings.dart';

// The v1 preferences key is additive: older backups need no schema migration.

class _SettingsJson {
  _SettingsJson(Object? source) {
    if (source is! Map<String, dynamic>) {
      throw const FormatException('Invalid simulator settings object');
    }
    data = source;
  }
  late final Map<String, dynamic> data;
  T value<T>(String key, T fallback) {
    if (!data.containsKey(key)) return fallback;
    final raw = data[key];
    if (raw is! T) throw FormatException('Invalid simulator setting: $key');
    return raw;
  }

  double number(String key, double fallback) {
    final raw = value<num>(key, fallback);
    if (!raw.isFinite) {
      throw FormatException('Non-finite simulator setting: $key');
    }
    return raw.toDouble();
  }

  double? optionalNumber(String key) =>
      data[key] == null ? null : number(key, 0);
  int? optionalInt(String key) => data[key] == null ? null : value<int>(key, 0);
  String? optionalText(String key) =>
      data[key] == null ? null : value<String>(key, '');
  Map<String, dynamic> object(String key) =>
      value<Map<String, dynamic>>(key, {});
  T choice<T extends Enum>(String key, List<T> choices, T fallback) {
    final name = value<String>(key, fallback.name);
    return choices.where((v) => v.name == name).firstOrNull ??
        (throw FormatException('Invalid simulator option: $key'));
  }
}

SimulationSettings _simulationSettingsFromJson(Object? source) {
  final j = _SettingsJson(source);
  const d = SimulationSettings();
  try {
    final result = SimulationSettings(
      agl: j.number('agl', d.agl),
      maxSpeed: j.number('maxSpeed', d.maxSpeed),
      climbSpeed: j.number('climbSpeed', d.climbSpeed),
      acceleration: j.number('acceleration', d.acceleration),
      deceleration: j.number('deceleration', d.deceleration),
      cameraTiltDegrees: j.number('cameraTiltDegrees', d.cameraTiltDegrees),
      cameraFovDegrees: j.number('cameraFovDegrees', d.cameraFovDegrees),
      lowBatteryCellVoltage: j.number(
        'lowBatteryCellVoltage',
        d.lowBatteryCellVoltage,
      ),
      criticalBatteryCellVoltage: j.number(
        'criticalBatteryCellVoltage',
        d.criticalBatteryCellVoltage,
      ),
      batterySagResistanceOhmsPerCell: j.number(
        'batterySagResistanceOhmsPerCell',
        d.batterySagResistanceOhmsPerCell,
      ),
      acroThrustToWeight: j.number('acroThrustToWeight', d.acroThrustToWeight),
      acroThrustCurve: j.number('acroThrustCurve', d.acroThrustCurve),
      acroMotorTimeConstant: j.number(
        'acroMotorTimeConstant',
        d.acroMotorTimeConstant,
      ),
      acroTerminalVelocity: j.number(
        'acroTerminalVelocity',
        d.acroTerminalVelocity,
      ),
      acroRollRate: j.number('acroRollRate', d.acroRollRate),
      acroPitchRate: j.number('acroPitchRate', d.acroPitchRate),
      acroYawRate: j.number('acroYawRate', d.acroYawRate),
      acroRateExpo: j.number('acroRateExpo', d.acroRateExpo),
      showCoordinates: j.value<bool>('showCoordinates', d.showCoordinates),
      showBatteryVoltage: j.value<bool>(
        'showBatteryVoltage',
        d.showBatteryVoltage,
      ),
      showBatteryCellVoltage: j.value<bool>(
        'showBatteryCellVoltage',
        d.showBatteryCellVoltage,
      ),
      batteryUseChemistryThresholds: j.value<bool>(
        'batteryUseChemistryThresholds',
        d.batteryUseChemistryThresholds,
      ),
      flightMode: j.choice(
        'flightMode',
        SimulationFlightMode.values,
        d.flightMode,
      ),
      physicsModel: j.choice(
        'physicsModel',
        SimulationPhysicsModel.values,
        d.physicsModel,
      ),
      graphicsProfile: j.choice(
        'graphicsProfile',
        SimulationGraphicsProfile.values,
        d.graphicsProfile,
      ),
      hudStyle: j.choice('hudStyle', SimulationHudStyle.values, d.hudStyle),
      droneId: j.optionalInt('droneId'),
      physicsStepHz: j.value<int>('physicsStepHz', d.physicsStepHz),
      signalHud: SignalHudSettings.fromJson({
        ...d.signalHud.toJson(),
        ...j.object('signalHud'),
      }),
      failsafe: FailsafeSettings.fromJson({
        ...d.failsafe.toJson(),
        ...j.object('failsafe'),
      }),
      controller:
          ControllerSettings.tryParse({
            ...d.controller.toJson(),
            ...j.object('controller'),
          }) ??
          (throw const FormatException('Invalid simulator controller')),
      sceneTime: SceneTime.fromJson({
        ...d.sceneTime.toJson(),
        ...j.object('sceneTime'),
      }),
      aerodynamics: _aerodynamicsFromJson(j.object('aerodynamics')),
      rotation: _rotationFromJson(j.object('rotation')),
      descentAerodynamics: _descentAerodynamicsFromJson(
        j.object('descentAerodynamics'),
      ),
      collisionResponse: _collisionResponseFromJson(
        j.object('collisionResponse'),
      ),
      batteryProfile: j.data['batteryProfile'] == null
          ? null
          : _batteryProfileFromJson(j.object('batteryProfile')),
      propulsionProfile: j.data['propulsionProfile'] == null
          ? null
          : _propulsionProfileFromJson(j.object('propulsionProfile')),
    );
    if (result.droneId != null && result.droneId! <= 0) {
      throw ArgumentError('Invalid simulator drone');
    }
    result.validate();
    return result;
  } on ArgumentError catch (error) {
    throw FormatException('Invalid simulator configuration: $error');
  }
}

SimulationAerodynamicsSettings _aerodynamicsFromJson(Object? source) {
  final j = _SettingsJson(source);
  const d = SimulationAerodynamicsSettings();
  return SimulationAerodynamicsSettings(
    forward: j.number('forward', d.forward),
    backward: j.number('backward', d.backward),
    lateral: j.number('lateral', d.lateral),
    vertical: j.number('vertical', d.vertical),
    propeller: j.number('propeller', d.propeller),
    propellerDragEnabled: j.value<bool>(
      'propellerDragEnabled',
      d.propellerDragEnabled,
    ),
    preset: j.choice('preset', SimulationAerodynamicsPreset.values, d.preset),
  );
}

SimulationRotationSettings _rotationFromJson(Object? source) {
  final j = _SettingsJson(source);
  const d = SimulationRotationSettings();
  return SimulationRotationSettings(
    superRate: j.number('superRate', d.superRate),
    rollInertiaKgM2: j.number('rollInertiaKgM2', d.rollInertiaKgM2),
    pitchInertiaKgM2: j.number('pitchInertiaKgM2', d.pitchInertiaKgM2),
    yawInertiaKgM2: j.number('yawInertiaKgM2', d.yawInertiaKgM2),
    rollTorqueNm: j.number('rollTorqueNm', d.rollTorqueNm),
    pitchTorqueNm: j.number('pitchTorqueNm', d.pitchTorqueNm),
    yawTorqueNm: j.number('yawTorqueNm', d.yawTorqueNm),
    rollAccelerationLimitDegs2: j.number(
      'rollAccelerationLimitDegs2',
      d.rollAccelerationLimitDegs2,
    ),
    pitchAccelerationLimitDegs2: j.number(
      'pitchAccelerationLimitDegs2',
      d.pitchAccelerationLimitDegs2,
    ),
    yawAccelerationLimitDegs2: j.number(
      'yawAccelerationLimitDegs2',
      d.yawAccelerationLimitDegs2,
    ),
    controllerGainPerSecond: j.number(
      'controllerGainPerSecond',
      d.controllerGainPerSecond,
    ),
    motorResponseTimeConstantSeconds: j.number(
      'motorResponseTimeConstantSeconds',
      d.motorResponseTimeConstantSeconds,
    ),
    passiveDampingPerSecond: j.number(
      'passiveDampingPerSecond',
      d.passiveDampingPerSecond,
    ),
    airModeIdleCommand: j.number('airModeIdleCommand', d.airModeIdleCommand),
    airModeEnabled: j.value<bool>('airModeEnabled', d.airModeEnabled),
    rateProfile: j.choice(
      'rateProfile',
      SimulationRateProfile.values,
      d.rateProfile,
    ),
  );
}

SimulationDescentAerodynamicsSettings _descentAerodynamicsFromJson(
  Object? source,
) {
  final j = _SettingsJson(source);
  const d = SimulationDescentAerodynamicsSettings();
  return SimulationDescentAerodynamicsSettings(
    groundEffectIntensity: j.number(
      'groundEffectIntensity',
      d.groundEffectIntensity,
    ),
    propwashIntensity: j.number('propwashIntensity', d.propwashIntensity),
    vortexRingIntensity: j.number('vortexRingIntensity', d.vortexRingIntensity),
    rotorDiameterMeters: j.number('rotorDiameterMeters', d.rotorDiameterMeters),
    groundEffectEnabled: j.value<bool>(
      'groundEffectEnabled',
      d.groundEffectEnabled,
    ),
    propwashEnabled: j.value<bool>('propwashEnabled', d.propwashEnabled),
    vortexRingEnabled: j.value<bool>('vortexRingEnabled', d.vortexRingEnabled),
  );
}

SimulationCollisionSettings _collisionResponseFromJson(Object? source) {
  final j = _SettingsJson(source);
  const d = SimulationCollisionSettings();
  return SimulationCollisionSettings(
    restitution: j.number('restitution', d.restitution),
    friction: j.number('friction', d.friction),
    hardStopNormalSpeedMs: j.number(
      'hardStopNormalSpeedMs',
      d.hardStopNormalSpeedMs,
    ),
    minimumReboundSpeedMs: j.number(
      'minimumReboundSpeedMs',
      d.minimumReboundSpeedMs,
    ),
    terrainProbeMeters: j.number('terrainProbeMeters', d.terrainProbeMeters),
    assistedLanding: j.value<bool>('assistedLanding', d.assistedLanding),
    mode: j.data['mode'] == 'hard-stop'
        ? SimulationCollisionMode.hardStop
        : j.choice('mode', SimulationCollisionMode.values, d.mode),
  );
}

SimulationBatteryProfile _batteryProfileFromJson(Object? source) {
  final j = _SettingsJson(source);
  return SimulationBatteryProfile(
    batteryId: j.value<int>('batteryId', 0),
    cellCount: j.value<int>('cellCount', 0),
    capacityMah: j.value<int>('capacityMah', 0),
    chemistry: j.value<String>('chemistry', ''),
    chargePercent: j.number('chargePercent', 100),
    internalResistanceMilliOhmsPerCell:
        j.optionalNumber('resistanceOhmsPerCell') == null
        ? null
        : j.optionalNumber('resistanceOhmsPerCell')! * 1000,
    nominalVoltageVolts: j.optionalNumber('nominalVoltageVolts'),
    energyWh: j.optionalNumber('energyWh'),
    continuousDischargeC: j.optionalNumber('continuousDischargeC'),
    burstDischargeC: j.optionalNumber('burstDischargeC'),
    burstDurationSeconds: j.optionalNumber('burstDurationSeconds'),
    hoverPowerWatts: j.optionalNumber('hoverPowerWatts'),
    cruisePowerWatts: j.optionalNumber('cruisePowerWatts'),
    cruiseSpeedMetersPerSecond: j.optionalNumber('cruiseSpeedMetersPerSecond'),
    maxPowerWatts: j.optionalNumber('maxPowerWatts'),
    escContinuousCurrentAmpsPerChannel: j.optionalNumber(
      'escContinuousCurrentAmpsPerChannel',
    ),
    motorContinuousCurrentAmpsPerMotor: j.optionalNumber(
      'motorContinuousCurrentAmpsPerMotor',
    ),
    maxSpeedMetersPerSecond: j.optionalNumber('maxSpeedMetersPerSecond'),
    takeoffWeightGrams: j.optionalNumber('takeoffWeightGrams'),
    motorCount: j.optionalInt('motorCount'),
  );
}

SimulationPropulsionProfile _propulsionProfileFromJson(Object? source) {
  final j = _SettingsJson(source);
  final curve = j.data['manufacturerCurve'];
  if (curve != null &&
      (curve is! List ||
          curve.any(
            (row) =>
                row is! Map<String, dynamic> ||
                row.values.any((v) => v is! num || !v.isFinite),
          ))) {
    throw const FormatException('Invalid manufacturer curve');
  }
  return SimulationPropulsionProfile(
    motorKv: j.optionalNumber('motorKv'),
    propellerDiameterInches: j.optionalNumber('propellerDiameterInches'),
    propellerPitchInches: j.optionalNumber('propellerPitchInches'),
    takeoffWeightGrams: j.optionalNumber('takeoffWeightGrams'),
    referenceVoltageVolts: j.optionalNumber('referenceVoltageVolts'),
    maxPowerWatts: j.optionalNumber('maxPowerWatts'),
    escContinuousCurrentAmpsPerChannel: j.optionalNumber(
      'escContinuousCurrentAmpsPerChannel',
    ),
    motorContinuousCurrentAmpsPerMotor: j.optionalNumber(
      'motorContinuousCurrentAmpsPerMotor',
    ),
    rpmEfficiency: j.optionalNumber('rpmEfficiency'),
    propellerEfficiency: j.optionalNumber('propellerEfficiency'),
    motorTimeConstantSeconds: j.optionalNumber('motorTimeConstantSeconds'),
    motorCount: j.optionalInt('motorCount'),
    bladeCount: j.optionalInt('bladeCount'),
    propellerDescription: j.optionalText('propellerDescription'),
    manufacturerCurve: curve == null
        ? null
        : (curve as List)
              .map((row) => Map<String, num>.from(row as Map))
              .toList(),
  );
}
