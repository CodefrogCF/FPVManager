import 'package:fpvmanager/core/osint/osint_dataset.dart';
import 'package:fpvmanager/core/osint/osint_provider_state.dart';
import 'package:fpvmanager/core/osint/osint_source.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';

final trafficTime = DateTime.utc(2026, 10, 29, 10);
final trafficSource = OsintSource(
  id: 'traffic-fixture',
  name: 'ASTRA fixture',
  publisher: 'Test',
  dataUri: Uri.parse('https://example.test/traffic'),
  metadataUri: Uri.parse('https://example.test/metadata'),
);

RoadRoute trafficRoute({
  double lon = 8,
  double seconds = 60,
  String ref = 'A1',
  bool reverse = false,
  bool link = false,
}) {
  final points = [MobilityPoint(47, lon), MobilityPoint(47.002, lon)];
  final directed = reverse ? points.reversed.toList() : points;
  return RoadRoute(
    distanceMeters: 222.39,
    durationSeconds: seconds,
    points: directed,
    retrievedUtc: trafficTime,
    sections: [
      RoadSection(
        points: directed,
        references: {ref},
        durationSeconds: seconds,
        distanceMeters: 222.39,
        link: link,
      ),
    ],
  );
}

Map<String, dynamic> trafficPart({
  double lon = 8,
  String id = 'part',
  String category = 'closure',
  double? delay,
  String direction = 'northBound',
}) => {
  'id': id,
  'roadNumbers': ['A1'],
  'directionBound': direction,
  'directionCode': '',
  'category': category,
  'metrics': {'delayTimeValue': ?delay},
  'timestampUtc': trafficTime.toIso8601String(),
  'validFromUtc': trafficTime
      .subtract(const Duration(hours: 1))
      .toIso8601String(),
  'validUntilUtc': trafficTime.add(const Duration(hours: 1)).toIso8601String(),
  'validityStatus': 'active',
  'geometryAccuracy': 'sourcePoint',
  'point': [lon, 47.001],
};
Map<String, dynamic> trafficEvent(
  List<Map<String, dynamic>> parts, {
  String id = 'event',
}) => {
  'id': id,
  'name': 'Published incident',
  'routingEvidenceComplete': true,
  'routingEvidence': parts,
};
Map<String, dynamic> speedSite({double lon = 8, double speed = 8}) => {
  'id': 'site-$lon',
  'name': 'Counter',
  'metadataVersionVerified': true,
  'roadNumbers': ['A1'],
  'directionBound': 'northBound',
  'lane': 'allLanesCompleteCarriageway',
  'geometry': {
    'type': 'Point',
    'coordinates': [lon, 47.001],
  },
  'values': [
    {
      'kind': 'trafficSpeed',
      'unit': 'KilometresPerHour',
      'vehicle': 'anyVehicle',
      'periodSeconds': 60,
      'value': speed,
      'timeUtc': trafficTime.toIso8601String(),
    },
  ],
};

OsintProviderState<Map<String, dynamic>> trafficState(
  Map<String, dynamic> data, {
  bool stale = false,
  bool imported = false,
  bool failed = false,
}) => OsintProviderState(
  update: failed ? OsintUpdateState.failed : OsintUpdateState.ready,
  freshness: stale ? OsintFreshness.stale : OsintFreshness.fresh,
  checkedAtUtc: trafficTime,
  error: failed
      ? const OsintProviderException(
          providerId: 'fixture',
          kind: OsintFailureKind.network,
          message: 'Failed',
        )
      : null,
  dataset: OsintDataset(
    source: trafficSource,
    data: data,
    fetchedAtUtc: trafficTime,
    cacheExpiresAtUtc: trafficTime.add(Duration(minutes: stale ? -1 : 2)),
    publishedAtUtc: trafficTime,
    requiresRevalidation: imported,
  ),
);

Map<String, dynamic> trafficRouteJson({
  double lon = 8,
  double seconds = 60,
  String ref = 'A1',
}) => {
  'distance': 222.39,
  'duration': seconds,
  'geometry': {
    'type': 'LineString',
    'coordinates': [
      [lon, 47],
      [lon, 47.002],
    ],
  },
  'legs': [
    {
      'steps': [
        {
          'distance': 222.39,
          'duration': seconds,
          'name': 'Street',
          'ref': ref,
          'maneuver': {
            'type': 'depart',
            'location': [lon, 47],
          },
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [lon, 47],
              [lon, 47.002],
            ],
          },
        },
      ],
    },
  ],
};

String trafficXml({
  double lon = 8,
  String type = 'RoadOrCarriagewayOrLaneManagement',
  String effect = '<roadOrCarriagewayOrLaneManagementType>roadClosed</roadOrCarriagewayOrLaneManagementType>',
  String extraPart = '',
}) =>
    '''
<d2LogicalModel xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><payloadPublication>
<publicationTime>${trafficTime.toIso8601String()}</publicationTime><situation id="event">
<situationRecord id="main" xsi:type="$type"><situationRecordVersionTime>${trafficTime.toIso8601String()}</situationRecordVersionTime>
<validity><validityStatus>active</validityStatus><overallStartTime>2026-10-29T09:00:00Z</overallStartTime></validity>
$effect<groupOfLocations><roadNumber>A 1</roadNumber><directionBound>northBound</directionBound>
<pointCoordinates><latitude>47.001</latitude><longitude>$lon</longitude></pointCoordinates></groupOfLocations>
</situationRecord>$extraPart</situation></payloadPublication></d2LogicalModel>''';
