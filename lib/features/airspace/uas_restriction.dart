/// Swiss FOCA UAS geozone interpretation according to the published UAS
/// geographical zone data model (CodeZoneType). This is not a flight clearance.
/// Never derive a legal prohibition from the existence of a polygon alone.
enum UasRestrictionCategory {
  prohibited,
  authorisation,
  conditional,
  informational,
  unknown;

  String get label => switch (this) {
    UasRestrictionCategory.prohibited => 'Prohibited (source classification)',
    UasRestrictionCategory.authorisation => 'Authorisation rule — check applicability',
    UasRestrictionCategory.conditional => 'Conditional operation',
    UasRestrictionCategory.informational => 'Informational / no zone restriction stated',
    UasRestrictionCategory.unknown => 'Unknown — verify with authorities',
  };

  /// Suggested map palette, intended for use by the bundled Cesium renderer.
  /// Unknown types deliberately have the same high visual prominence as other
  /// restricted categories rather than appearing safe.
  String get hexColor => switch (this) {
    UasRestrictionCategory.prohibited => '#d32f2f',
    UasRestrictionCategory.authorisation => '#ef6c00',
    UasRestrictionCategory.conditional => '#f9a825',
    UasRestrictionCategory.informational => '#1976d2',
    UasRestrictionCategory.unknown => '#757575',
  };
}

class UasAuthority {
  const UasAuthority({this.name, this.role, this.website, this.email, this.phone});
  final String? name;
  final String? role;
  final Uri? website;
  final String? email;
  final String? phone;
}

class UasVerticalLimit {
  const UasVerticalLimit({this.value, this.unit, this.reference});
  final double? value;
  final String? unit;
  final String? reference;
  bool get isComplete => value != null && unit != null && reference != null;
}

/// Typed view of *known* fields. The raw source properties remain in
/// [UasZoneDetails.attributes]; parsing gaps are reported, never guessed.
class UasRestriction {
  const UasRestriction({
    required this.category,
    required this.rawType,
    required this.identifier,
    required this.reason,
    required this.restrictionCode,
    required this.conditions,
    required this.permanent,
    required this.validFromUtc,
    required this.validUntilUtc,
    required this.lower,
    required this.upper,
    required this.authority,
    required this.unrecognisedValues,
    required this.hasDailyWindow,
  });

  factory UasRestriction.fromAttributes(Map<String, String> values) {
    String? get(String key) {
      final value = values[key]?.trim();
      return value == null || value.isEmpty || value.toLowerCase() == 'null'
          ? null : value;
    }
    final rawType = get('type'); // CodeZoneType, commonly COMMON.
    final sourceRestriction = get('restriction'); // CodeRestrictionType.
    final normalized = sourceRestriction?.toUpperCase()
        .replaceAll('-', '_').replaceFirst('REQ_AUTHORIZATION', 'REQ_AUTHORISATION');
    final category = switch (normalized) {
      'PROHIBITED' => UasRestrictionCategory.prohibited,
      'REQ_AUTHORISATION' || 'REQ_AUTHORISATION.MTOM_ALL' ||
      'REQ_AUTHORISATION.MTOM_FROM' || 'REQ_AUTHORISATION.CTR' =>
        UasRestrictionCategory.authorisation,
      'CONDITIONAL' => UasRestrictionCategory.conditional,
      'NO_RESTRICTION' => UasRestrictionCategory.informational,
      _ => UasRestrictionCategory.unknown,
    };
    final permanence = get('permanent')?.toUpperCase();
    final fromRaw = get('startDateTime');
    final untilRaw = get('endDateTime');
    DateTime? parseDate(String? raw) {
      if (raw == null || !RegExp(r'(Z|[+-]\d{2}:\d{2})$', caseSensitive: false).hasMatch(raw)) {
        return null; // No timezone: cannot safely infer UTC applicability.
      }
      return DateTime.tryParse(raw)?.toUtc();
    }
    Uri? website;
    final site = get('siteURL');
    if (site != null) {
      final candidate = Uri.tryParse(site);
      if (candidate != null && candidate.scheme == 'https' && candidate.hasAuthority) {
        website = candidate;
      }
    }
    final unknown = <String>[
      if (category == UasRestrictionCategory.unknown)
        'Unknown restriction code: ${sourceRestriction ?? '(missing)'}',
      if (rawType != null && rawType.toUpperCase() != 'COMMON')
        'Unsupported zone definition type: $rawType',
      if (permanence != null && permanence != 'YES' && permanence != 'NO')
        'Unknown permanent value: $permanence',
      if (fromRaw != null && parseDate(fromRaw) == null)
        'Invalid startDateTime: $fromRaw',
      if (untilRaw != null && parseDate(untilRaw) == null)
        'Invalid endDateTime: $untilRaw',
      if (site != null && website == null) 'Website is not an HTTPS address',
    ];
    UasVerticalLimit limit(String prefix) => UasVerticalLimit(
      value: double.tryParse(get('${prefix}Limit') ?? ''),
      unit: get('uomDimensions'),
      reference: get('${prefix}VerticalReference'),
    );
    return UasRestriction(
      category: category,
      rawType: rawType,
      identifier: get('identifier'),
      reason: get('reason'),
      restrictionCode: sourceRestriction,
      conditions: get('restrictionConditions'),
      permanent: permanence == 'YES' ? true : permanence == 'NO' ? false : null,
      validFromUtc: parseDate(fromRaw),
      validUntilUtc: parseDate(untilRaw),
      lower: limit('lower'),
      upper: limit('upper'),
      authority: UasAuthority(
        name: get('authorityName'),
        role: get('purpose'),
        website: website,
        email: get('email'),
        phone: get('phone'),
      ),
      unrecognisedValues: List.unmodifiable(unknown),
      hasDailyWindow: get('startTime') != null || get('endTime') != null,
    );
  }

  /// A map color for the actual Swiss CodeRestrictionType (not CodeZoneType).
  /// Distinct shades represent different authorisation conditions, not safety.
  String get mapHexColor => switch (restrictionCode?.trim().toUpperCase()
      .replaceAll('-', '_').replaceFirst('REQ_AUTHORIZATION', 'REQ_AUTHORISATION')) {
    'REQ_AUTHORISATION.MTOM_ALL' => '#ef6c00',
    'REQ_AUTHORISATION.MTOM_FROM' => '#b8860b',
    'REQ_AUTHORISATION.CTR' => '#7b1fa2',
    _ => category.hexColor,
  };

  String get restrictionMeaning => switch (restrictionCode?.trim().toUpperCase()
      .replaceAll('-', '_').replaceFirst('REQ_AUTHORIZATION', 'REQ_AUTHORISATION')) {
    'REQ_AUTHORISATION.MTOM_ALL' =>
      'Prior authorisation is required regardless of UAS weight when this rule applies.',
    'REQ_AUTHORISATION.MTOM_FROM' =>
      'Prior authorisation is required starting at the source-defined take-off mass. Verify the applicable threshold.',
    'REQ_AUTHORISATION.CTR' =>
      'CTR authorisation rule (above 120 m AGL according to the BAZL model). Other local rules may apply below this height.',
    'NO_RESTRICTION' =>
      'No additional restriction indicated by this particular zone. Other overlapping and temporary rules may apply.',
    'PROHIBITED' => 'Explicit prohibition indicated by the source; consult official rules and applicability.',
    'CONDITIONAL' => 'Conditional operation; read all source conditions and official guidance.',
    'REQ_AUTHORISATION' => 'Authorisation rule; verify affected aircraft, altitude and validity.',
    _ => 'Unknown restriction code; official manual verification required.',
  };

  final UasRestrictionCategory category;
  final String? rawType;
  final String? identifier;
  final String? reason;
  /// CodeRestrictionType (e.g. REQ_AUTHORISATION.CTR); source value retained.
  final String? restrictionCode;
  final String? conditions;
  final bool? permanent;
  final DateTime? validFromUtc;
  final DateTime? validUntilUtc;
  final UasVerticalLimit lower;
  final UasVerticalLimit upper;
  final UasAuthority authority;
  final List<String> unrecognisedValues;
  final bool hasDailyWindow;

  bool get hasSchedule =>
      permanent == false || validFromUtc != null || validUntilUtc != null ||
      hasDailyWindow ||
      unrecognisedValues.any((entry) => entry.startsWith('Invalid startDateTime') ||
          entry.startsWith('Invalid endDateTime'));
  bool get hasUnverifiedTimeRules => hasSchedule;
  // The app intentionally does not evaluate activation, daily time windows,
  // altitude datum conversion or licence / aircraft class exemptions.
}
