import '../database/fpv_database.dart';
import '../database/repository_validation.dart';

enum BatteryAvailability {
  unknown('Not recorded'),
  available('Available'),
  unavailable('Unavailable'),
  retired('Retired');

  const BatteryAvailability(this.label);
  final String label;
  static BatteryAvailability parse(String value) =>
      values.firstWhere((item) => item.name == value, orElse: () => unknown);
}

/// Types are reusable templates; each pack keeps its own specification snapshot.
class BatteryInput {
  BatteryInput({
    required this.name,
    required this.cellCount,
    required this.capacityMah,
    this.chemistry = 'LiPo',
    this.nominalVoltageVolts,
    this.energyWh,
    this.weightGrams,
    this.isType = false,
    this.typeId,
    this.chargePercent,
    this.cycleCount,
    this.availability = BatteryAvailability.unknown,
    this.notes,
    this.conditionNotes,
    Set<int> droneIds = const {},
    Set<int> flightPlanIds = const {},
  }) : droneIds = Set.unmodifiable(droneIds),
       flightPlanIds = Set.unmodifiable(flightPlanIds);

  final String name, chemistry;
  final int cellCount, capacityMah;
  final double? nominalVoltageVolts, energyWh, weightGrams, chargePercent;
  final bool isType;
  final int? typeId, cycleCount;
  final BatteryAvailability availability;
  final String? notes, conditionNotes;
  final Set<int> droneIds, flightPlanIds;

  void validate() {
    RepositoryValidation.text(name, 'name');
    RepositoryValidation.text(chemistry, 'chemistry');
    RepositoryValidation.positive(cellCount, 'cellCount');
    RepositoryValidation.positive(capacityMah, 'capacityMah');
    for (final entry in {
      'nominalVoltageVolts': nominalVoltageVolts,
      'energyWh': energyWh,
      'weightGrams': weightGrams,
    }.entries) {
      RepositoryValidation.positive(entry.value, entry.key);
    }
    if (nominalVoltageVolts != null &&
        !(nominalVoltageVolts! * (capacityMah / 1000)).isFinite) {
      throw ArgumentError(
        'Calculated nominal energy exceeds supported precision',
      );
    }
    RepositoryValidation.positive(cycleCount, 'cycleCount', allowZero: true);
    if (chargePercent != null &&
        (!chargePercent!.isFinite ||
            chargePercent! < 0 ||
            chargePercent! > 100)) {
      throw ArgumentError('Recorded charge must be between 0 and 100 percent');
    }
    for (final value in [cellCount, capacityMah, ?cycleCount]) {
      if (value > 9007199254740991) {
        throw ArgumentError('Integer exceeds supported precision');
      }
    }
    RepositoryValidation.optionalId(typeId);
    for (final id in [...droneIds, ...flightPlanIds]) {
      RepositoryValidation.id(id);
    }
    if (isType &&
        (typeId != null ||
            chargePercent != null ||
            cycleCount != null ||
            conditionNotes != null ||
            availability != BatteryAvailability.unknown ||
            droneIds.isNotEmpty ||
            flightPlanIds.isNotEmpty)) {
      throw ArgumentError('Battery types contain specifications only');
    }
    for (final note in [notes, conditionNotes]) {
      if (note != null && note.length > 4000) {
        throw ArgumentError('Notes exceed 4000 characters');
      }
    }
  }
}

class BatteryProfile {
  BatteryProfile({
    required this.battery,
    this.type,
    required List<Drone> drones,
    required List<FlightPlan> flightPlans,
  }) : drones = List.unmodifiable(drones),
       flightPlans = List.unmodifiable(flightPlans);
  final Battery battery;
  final Battery? type;
  final List<Drone> drones;
  final List<FlightPlan> flightPlans;
  double? get calculatedNominalEnergyWh => battery.nominalVoltageVolts == null
      ? null
      : battery.nominalVoltageVolts! * (battery.capacityMah / 1000);
}

class BatteryAssignmentOptions {
  BatteryAssignmentOptions({
    required List<Battery> types,
    required List<Drone> drones,
    required List<FlightPlan> flightPlans,
  }) : types = List.unmodifiable(types),
       drones = List.unmodifiable(drones),
       flightPlans = List.unmodifiable(flightPlans);
  final List<Battery> types;
  final List<Drone> drones;
  final List<FlightPlan> flightPlans;
}
