/// Source attributes for one selected zone. Codes and vertical references stay
/// as supplied; this model does not determine applicability or permission to fly.
class UasZoneDetails {
  const UasZoneDetails({
    required this.id,
    required this.name,
    required this.attributes,
    this.omittedAttributeCount = 0,
    this.truncatedAttributes = const [],
  });

  final String id;
  final String name;
  final Map<String, String> attributes;
  final int omittedAttributeCount;
  final List<String> truncatedAttributes;

  static const keyFields = {
    'identifier': 'Identifier',
    'name': 'Name',
    'type': 'Zone type',
    'reason': 'Reason / category',
    'restriction': 'Restriction code',
    'restrictionConditions': 'Restriction conditions',
    'permanent': 'Permanence',
    'uomDimensions': 'Height unit',
    'lowerLimit': 'Lower limit',
    'lowerVerticalReference': 'Lower height reference',
    'upperLimit': 'Upper limit',
    'upperVerticalReference': 'Upper height reference',
  };

  static bool hasSourceValue(Object? value) =>
      value is num && value.isFinite ||
      value is String &&
          value.trim().isNotEmpty &&
          value.trim() != 'null' &&
          value.trim() != 'undefined';

  String? value(String key) {
    final raw = attributes[key];
    return hasSourceValue(raw) ? raw!.trim() : null;
  }

  static List<String> missingSourceFields(Map properties) => [
    for (final field in keyFields.entries)
      if (!hasSourceValue(properties[field.key])) field.value,
    if (properties['permanent'] == 'NO') ...[
      if (!hasSourceValue(properties['startDateTime'])) 'Start date/time',
      if (!hasSourceValue(properties['endDateTime'])) 'End date/time',
    ],
  ];

  List<String> get missingFields => missingSourceFields(attributes);

  bool get hasDisplayLimits =>
      omittedAttributeCount > 0 || truncatedAttributes.isNotEmpty;

  String heightLimit({required bool upper}) {
    final prefix = upper ? 'upper' : 'lower';
    final amount = value('${prefix}Limit') ?? 'Not provided';
    final unit = value('uomDimensions') ?? '(unit not provided)';
    final reference =
        value('${prefix}VerticalReference') ?? '(reference not provided)';
    return '$amount $unit · $reference';
  }
}
