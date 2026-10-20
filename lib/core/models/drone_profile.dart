import '../database/fpv_database.dart';

enum DroneValueSource {
  unspecified('Source not specified'),
  estimated('Estimated'),
  measured('Measured');

  const DroneValueSource(this.label);
  final String label;
}

enum DroneParameterGroup {
  airframe('Airframe'),
  propellers('Propellers'),
  propulsion('Propulsion'),
  performance('Power & performance');

  const DroneParameterGroup(this.label);
  final String label;
}

/// Storage keys are stable; units are explicit and no flight model is inferred.
enum DroneParameter {
  takeoffWeightGrams('Takeoff weight', 'g', DroneParameterGroup.airframe),
  lengthMm('Length', 'mm', DroneParameterGroup.airframe),
  widthMm('Width', 'mm', DroneParameterGroup.airframe),
  heightMm('Height', 'mm', DroneParameterGroup.airframe),
  propellerDiameterInches(
    'Propeller diameter',
    'in',
    DroneParameterGroup.propellers,
  ),
  propellerPitchInches('Propeller pitch', 'in', DroneParameterGroup.propellers),
  propellerCount(
    'Propeller count',
    '',
    DroneParameterGroup.propellers,
    wholeNumber: true,
  ),
  motorCount(
    'Motor count',
    '',
    DroneParameterGroup.propulsion,
    wholeNumber: true,
  ),
  motorKv('Motor KV', 'rpm/V', DroneParameterGroup.propulsion),
  maxSpeedMetersPerSecond(
    'Maximum speed',
    'm/s',
    DroneParameterGroup.performance,
  ),
  cruiseSpeedMetersPerSecond(
    'Cruise speed',
    'm/s',
    DroneParameterGroup.performance,
  ),
  maxClimbRateMetersPerSecond(
    'Maximum climb rate',
    'm/s',
    DroneParameterGroup.performance,
  ),
  hoverPowerWatts('Hover power', 'W', DroneParameterGroup.performance),
  cruisePowerWatts('Cruise power', 'W', DroneParameterGroup.performance),
  maxPowerWatts('Maximum power', 'W', DroneParameterGroup.performance),
  referenceVoltageVolts(
    'Reference voltage',
    'V',
    DroneParameterGroup.performance,
  );

  const DroneParameter(
    this.label,
    this.unit,
    this.group, {
    this.wholeNumber = false,
  });
  final String label;
  final String unit;
  final DroneParameterGroup group;
  final bool wholeNumber;
  String get fieldLabel => unit.isEmpty ? label : '$label ($unit)';

  double? read(Drone drone) => (switch (this) {
    takeoffWeightGrams => drone.takeoffWeightGrams,
    lengthMm => drone.lengthMm,
    widthMm => drone.widthMm,
    heightMm => drone.heightMm,
    propellerDiameterInches => drone.propellerDiameterInches,
    propellerPitchInches => drone.propellerPitchInches,
    propellerCount => drone.propellerCount,
    motorCount => drone.motorCount,
    motorKv => drone.motorKv,
    maxSpeedMetersPerSecond => drone.maxSpeedMetersPerSecond,
    cruiseSpeedMetersPerSecond => drone.cruiseSpeedMetersPerSecond,
    maxClimbRateMetersPerSecond => drone.maxClimbRateMetersPerSecond,
    hoverPowerWatts => drone.hoverPowerWatts,
    cruisePowerWatts => drone.cruisePowerWatts,
    maxPowerWatts => drone.maxPowerWatts,
    referenceVoltageVolts => drone.referenceVoltageVolts,
  })?.toDouble();

  void validate(double value) {
    if (!value.isFinite ||
        value <= 0 ||
        (wholeNumber &&
            (value != value.truncateToDouble() || value > 9007199254740991))) {
      throw ArgumentError(
        '$label must be a positive ${wholeNumber ? 'whole number' : 'finite number'}',
      );
    }
  }
}

class DroneMeasurement {
  const DroneMeasurement(
    this.value, {
    this.source = DroneValueSource.unspecified,
  });
  final double value;
  final DroneValueSource source;
  String get valueLabel => value.toString().replaceFirst(RegExp(r'\.0$'), '');
}

/// A coherent database snapshot; the persisted record is not duplicated.
class DroneProfile {
  DroneProfile({
    required this.drone,
    required Map<DroneParameter, DroneMeasurement> measurements,
  }) : measurements = Map.unmodifiable(measurements);
  final Drone drone;
  final Map<DroneParameter, DroneMeasurement> measurements;
}

class DroneProfileInput {
  DroneProfileInput({
    required this.name,
    this.type = 'quadcopter',
    this.notes,
    this.configuration,
    this.propellerDescription,
    this.motorDescription,
    this.escDescription,
    this.measurementContext,
    Map<DroneParameter, DroneMeasurement> measurements = const {},
  }) : measurements = Map.unmodifiable(measurements) {
    for (final entry in this.measurements.entries) {
      entry.key.validate(entry.value.value);
    }
  }
  final String name;
  final String type;
  final String? notes;
  final String? configuration;
  final String? propellerDescription;
  final String? motorDescription;
  final String? escDescription;
  final String? measurementContext;
  final Map<DroneParameter, DroneMeasurement> measurements;
  double? value(DroneParameter parameter) => measurements[parameter]?.value;
}
