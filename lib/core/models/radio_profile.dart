import '../database/fpv_database.dart';
import '../database/repository_validation.dart';

enum RadioProfileSection {
  link('Link'),
  transmitter('Transmitter & antenna'),
  receiver('Receiver & antenna'),
  documentation('Documentation');

  const RadioProfileSection(this.label);
  final String label;
}

/// Units are part of the contract. Power is conducted transmitter power, not EIRP.
enum RadioParameter {
  frequencyMhz('Frequency', 'MHz', RadioProfileSection.link),
  bandwidthKhz('Channel bandwidth', 'kHz', RadioProfileSection.link),
  maxPowerMw(
    'Maximum transmitter power',
    'mW',
    RadioProfileSection.transmitter,
    zero: true,
  ),
  txGainDbi(
    'Transmitter antenna gain',
    'dBi',
    RadioProfileSection.transmitter,
    signed: true,
  ),
  txLossDb(
    'Transmitter cable / connector loss',
    'dB',
    RadioProfileSection.transmitter,
    zero: true,
  ),
  sensitivityDbm(
    'Receiver sensitivity',
    'dBm',
    RadioProfileSection.receiver,
    signed: true,
  ),
  rxGainDbi(
    'Receiver antenna gain',
    'dBi',
    RadioProfileSection.receiver,
    signed: true,
  ),
  rxLossDb(
    'Receiver cable / connector loss',
    'dB',
    RadioProfileSection.receiver,
    zero: true,
  );

  const RadioParameter(
    this.label,
    this.unit,
    this.group, {
    this.zero = false,
    this.signed = false,
  });
  final String label, unit;
  final RadioProfileSection group;
  final bool zero, signed;
  String get fieldLabel => '$label ($unit)';

  void validate(double value) {
    if (!value.isFinite || (!signed && (zero ? value < 0 : value <= 0))) {
      throw ArgumentError('Invalid $fieldLabel');
    }
  }

  double? read(RadioEquipmentData row) => switch (this) {
    frequencyMhz => row.frequencyMhz,
    maxPowerMw => row.maxPowerMw,
    bandwidthKhz => row.bandwidthKhz,
    sensitivityDbm => row.sensitivityDbm,
    txGainDbi => row.txGainDbi,
    rxGainDbi => row.rxGainDbi,
    txLossDb => row.txLossDb,
    rxLossDb => row.rxLossDb,
  };
}

enum RadioTextField {
  protocol('Protocol / system', RadioProfileSection.link),
  transmitter('Transmitter model', RadioProfileSection.transmitter),
  txAntenna(
    'Transmitter antenna characteristics',
    RadioProfileSection.transmitter,
    limit: 4000,
  ),
  txPolarization('Transmitter polarization', RadioProfileSection.transmitter),
  receiver('Receiver model', RadioProfileSection.receiver),
  rxAntenna(
    'Receiver antenna characteristics',
    RadioProfileSection.receiver,
    limit: 4000,
  ),
  rxPolarization('Receiver polarization', RadioProfileSection.receiver),
  receiverSpecifications(
    'Receiver specifications / operating mode',
    RadioProfileSection.receiver,
    limit: 4000,
  ),
  specificationSource(
    'Specification source / measurement context',
    RadioProfileSection.documentation,
    limit: 4000,
  ),
  notes('Notes', RadioProfileSection.documentation, limit: 4000);

  const RadioTextField(this.label, this.group, {this.limit = 120});
  final String label;
  final RadioProfileSection group;
  final int limit;

  String? read(RadioEquipmentData row) => switch (this) {
    protocol => row.protocol,
    transmitter => row.transmitter,
    txAntenna => row.txAntenna,
    txPolarization => row.txPolarization,
    receiver => row.receiver,
    rxAntenna => row.rxAntenna,
    rxPolarization => row.rxPolarization,
    receiverSpecifications => row.receiverSpecifications,
    specificationSource => row.specificationSource,
    notes => row.notes,
  };
}

const radioCategories = {
  'control': 'Radio control',
  'video': 'Video',
  'telemetry': 'Telemetry',
};
String radioCategoryLabel(String category) =>
    radioCategories[category] ?? category;

class RadioProfileInput {
  RadioProfileInput({
    required this.name,
    required this.category,
    Map<RadioParameter, double> parameters = const {},
    Map<RadioTextField, String> descriptions = const {},
    Set<int> droneIds = const {},
  }) : parameters = Map.unmodifiable(parameters),
       descriptions = Map.unmodifiable(descriptions),
       droneIds = Set.unmodifiable(droneIds);

  final String name, category;
  final Map<RadioParameter, double> parameters;
  final Map<RadioTextField, String> descriptions;
  final Set<int> droneIds;

  void validate() {
    RepositoryValidation.text(name, 'name');
    RepositoryValidation.text(category, 'category');
    for (final entry in parameters.entries) {
      entry.key.validate(entry.value);
    }
    for (final entry in descriptions.entries) {
      if (entry.value.length > entry.key.limit) {
        throw ArgumentError(
          '${entry.key.label} exceeds ${entry.key.limit} characters',
        );
      }
    }
    for (final id in droneIds) {
      RepositoryValidation.id(id);
    }
  }
}

class RadioProfile {
  RadioProfile({required this.equipment, required List<Drone> drones})
    : drones = List.unmodifiable(drones);
  final RadioEquipmentData equipment;
  final List<Drone> drones;
}
