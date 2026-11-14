/// Advisory 3D infrastructure assessment. A zero-hit result is never a
/// representation of complete national obstacle coverage or flight approval.
class InfrastructureRoutePoint {
  const InfrastructureRoutePoint({
    required this.latitude,
    required this.longitude,
    required this.heightMetersWgs84,
    required this.segment,
  });
  final double latitude, longitude;
  final double? heightMetersWgs84;
  final int segment;

  Map<String, Object?> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'height': heightMetersWgs84,
    'segment': segment,
  };
}

class InfrastructureClearanceFinding {
  const InfrastructureClearanceFinding({
    required this.segment,
    required this.id,
    required this.name,
    required this.kind,
    required this.quality,
    required this.source,
    required this.sourceId,
    required this.status,
    required this.clearanceMeters,
  });
  final int segment;
  final String id, name, kind, quality, source, sourceId, status;
  final double clearanceMeters;
  bool get modelContact => clearanceMeters <= 0;

  factory InfrastructureClearanceFinding.fromJson(Map<String, dynamic> json) {
    final segment = json['segment'];
    final clearance = json['clearanceMeters'];
    if (segment is! int ||
        segment < 0 ||
        segment > 1000 ||
        clearance is! num ||
        !clearance.isFinite ||
        !const ['deck', 'support', 'tunnel'].contains(json['kind']) ||
        !const [
          'simulation-only',
          'external-unverified',
          'surveyed',
          'derived',
          'approximate',
          'unknown',
        ].contains(json['quality']) ||
        !const ['model-contact', 'near-model'].contains(json['status'])) {
      throw const FormatException('Invalid infrastructure clearance finding');
    }
    String field(String key) {
      final value = json[key];
      if (value is! String || value.length > 256) {
        throw const FormatException('Invalid infrastructure provenance');
      }
      return value;
    }

    return InfrastructureClearanceFinding(
      segment: segment,
      id: field('id'),
      name: field('name'),
      kind: field('kind'),
      quality: field('quality'),
      source: field('source'),
      sourceId: field('sourceId'),
      status: field('status'),
      clearanceMeters: clearance.toDouble(),
    );
  }
}

class InfrastructureClearanceReport {
  const InfrastructureClearanceReport({
    required this.findings,
    required this.incomplete,
    required this.processingLimited,
    required this.unknownHeightSamples,
    required this.checkedSamples,
    required this.modelCount,
    required this.coverage,
    required this.message,
  });
  final List<InfrastructureClearanceFinding> findings;
  final bool incomplete, processingLimited;
  final int unknownHeightSamples, checkedSamples, modelCount;
  final String coverage, message;

  factory InfrastructureClearanceReport.fromJson(Map<String, dynamic> json) {
    final findings = json['findings'];
    final checked = json['checkedSamples'];
    final unknown = json['unknownHeightSamples'];
    final count = json['modelCount'];
    final incomplete = json['incomplete'];
    final limited = json['processingLimited'];
    final coverage = json['coverage'];
    final message = json['message'];
    if (findings is! List ||
        findings.length > 80 ||
        checked is! int ||
        checked < 0 ||
        checked > 32768 ||
        unknown is! int ||
        unknown < 0 ||
        unknown > checked + 1 ||
        count is! int ||
        count < 0 ||
        count > 49 ||
        incomplete is! bool ||
        limited is! bool ||
        !const ['unassessed', 'local-models-only'].contains(coverage) ||
        message is! String ||
        message.length > 512) {
      throw const FormatException('Invalid infrastructure coverage report');
    }
    return InfrastructureClearanceReport(
      findings: List.unmodifiable([
        for (final value in findings)
          InfrastructureClearanceFinding.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
      ]),
      incomplete: incomplete,
      processingLimited: limited,
      unknownHeightSamples: unknown,
      checkedSamples: checked,
      modelCount: count,
      coverage: coverage,
      message: message,
    );
  }
}
