import 'dart:math' as math;

enum TrafficCategory {
  closure('Sperrung'),
  accident('Unfall'),
  congestion('Stau / stockender Verkehr'),
  roadworks('Baustelle'),
  weather('Witterung'),
  hazard('Gefahr'),
  other('Weitere Meldung');

  const TrafficCategory(this.label);
  final String label;
}

List<String> trafficMetricLabels(Map<String, dynamic> metrics) => [
  if (metrics['queueLength'] case final num v)
    'Staulänge: ${(v / 1000).toStringAsFixed(1)} km',
  if (metrics['delayTimeValue'] case final num v)
    'Gemeldete Verzögerung: ${(v / 60).ceil()} min',
  if (metrics['numberOfLanesRestricted'] case final num v)
    'Betroffene Fahrstreifen: ${v.toInt()}',
  if (metrics['speedLimit'] case final num v) 'Tempolimit: ${v.toInt()} km/h',
];

/// Render a bounded nearby subset; the complete normalized list remains searchable.
List<Map<String, dynamic>> trafficMapFeatures(
  List<dynamic> records, {
  required double latitude,
  required double longitude,
  DateTime? now,
}) {
  final time = now ?? DateTime.now().toUtc();
  final candidates = records
      .map((r) => Map<String, dynamic>.from(r as Map))
      .where(
        (r) =>
            TrafficIncident(r).located && TrafficIncident(r).relevantNow(time),
      )
      .toList();
  double distance(Map<String, dynamic> r) {
    final geometry = r['geometry'] as Map;
    final positions = geometry['type'] == 'Point'
        ? [geometry['coordinates']]
        : geometry['coordinates'] as List;
    return positions
        .map((p) {
          final dx =
              (((p[0] as num) - longitude + 540) % 360 - 180) *
              math.cos(latitude * math.pi / 180);
          final dy = (p[1] as num) - latitude;
          return dx * dx + dy * dy;
        })
        .reduce(math.min);
  }

  final ranked =
      candidates.map((r) => (record: r, distance: distance(r))).toList()
        ..sort((a, b) => a.distance.compareTo(b.distance));
  final result = <Map<String, dynamic>>[];
  var vertices = 0;
  for (final item in ranked) {
    final geometry = item.record['geometry'] as Map;
    final count = geometry['type'] == 'Point'
        ? 1
        : (geometry['coordinates'] as List).length;
    if (result.length >= 1000 || vertices + count > 20000) break;
    vertices += count;
    result.add(item.record);
  }
  return result;
}

/// Public source fields, kept separate from retrieval time and road matching.
class TrafficIncident {
  TrafficIncident(this.data);
  final Map<String, dynamic> data;
  TrafficCategory get category => TrafficCategory.values.firstWhere(
    (c) => c.name == data['category'],
    orElse: () => TrafficCategory.other,
  );
  String get title => data['name'] as String? ?? category.label;
  String get description =>
      data['description'] as String? ?? data['detail'] as String? ?? '';
  bool get located => data['geometry'] != null;
  DateTime? get from =>
      DateTime.tryParse(data['validFromUtc'] as String? ?? '');
  DateTime? get until =>
      DateTime.tryParse(data['validUntilUtc'] as String? ?? '');
  DateTime? get updated =>
      DateTime.tryParse(data['timestampUtc'] as String? ?? '');
  String state(DateTime now) {
    if (until != null && !until!.isAfter(now)) return 'Beendet';
    if (data['suspended'] == true) return 'Ausgesetzt';
    if (from != null && from!.isAfter(now)) return 'Geplant';
    if (data['recurring'] == true) return 'Zeitfenster prüfen';
    if (data['validityStatus'] == 'active') return 'Laut Quelle aktiv';
    if (from == null && until == null) return 'Gültigkeit unbekannt';
    return 'Laufende Meldung';
  }

  bool relevantNow(DateTime now) =>
      !{'Beendet', 'Ausgesetzt', 'Geplant'}.contains(state(now));
  Map<String, dynamic> get metrics =>
      Map<String, dynamic>.from(data['metrics'] as Map? ?? {});
  String get searchable =>
      '${category.label} $title $description ${data['id']}'.toLowerCase();
}
