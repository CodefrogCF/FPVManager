import 'package:flutter/foundation.dart';

import '../../core/geo/geo_coordinate_service.dart';
import '../../core/geo/polygon_intersections.dart';
import '../../core/osint/osint_dataset.dart';
import '../../core/osint/osint_provider.dart';
import '../../core/osint/osint_source.dart';
import 'uas_dataset_assessment.dart';
import 'uas_zone_details.dart';

class UasAirspaceIntersection {
  const UasAirspaceIntersection(this.zone, this.geometry);
  final UasZoneDetails zone;
  final PolygonIntersection geometry;
}

/// A horizontal check of one input snapshot, never a flight authorization.
class UasAirspaceCheck {
  UasAirspaceCheck({
    required this.source,
    required this.fetchedAtUtc,
    required this.freshness,
    required this.checkedFeatureCount,
    required List<UasAirspaceIntersection> intersections,
    required List<String> limitations,
    this.datasetIdentity,
  }) : intersections = List.unmodifiable(intersections),
       limitations = List.unmodifiable(limitations);

  final OsintSource source;
  final DateTime fetchedAtUtc;
  final OsintFreshness freshness;
  final int checkedFeatureCount;
  final List<UasAirspaceIntersection> intersections;
  final List<String> limitations;
  final Object? datasetIdentity;
}

/// Uses the shared provider without changing map visibility or importing data
/// into the renderer. The report identifies the dataset actually checked.
class UasAirspaceChecker {
  UasAirspaceChecker(this.provider);
  final OsintProvider<Map<String, dynamic>> provider;

  /// Inspect the snapshot already displayed by the renderer, without a fetch.
  static Future<List<UasZoneDetails>> zonesAt(
    OsintDataset<Map<String, dynamic>> dataset,
    Wgs84Coordinate position,
  ) async {
    final result = await compute(_check, (dataset.data, [position]));
    return List.unmodifiable(result.$1.map((hit) => hit.zone));
  }

  Future<UasAirspaceCheck> check(
    List<Wgs84Coordinate> positions, {
    bool forceRefresh = false,
  }) async {
    final path = List<Wgs84Coordinate>.unmodifiable(positions);
    PolygonIntersectionIndex.validatePath(path);
    final dataset = await provider.fetch(forceRefresh: forceRefresh);
    final result = await compute(_check, (dataset.data, path));
    final status = provider.status;
    return UasAirspaceCheck(
      source: dataset.source,
      fetchedAtUtc: dataset.fetchedAtUtc,
      freshness: dataset.freshnessAt(status.checkedAtUtc),
      checkedFeatureCount: result.$3,
      datasetIdentity: dataset,
      intersections: result.$1,
      limitations: [
        ...result.$2,
        if (status.error != null)
          'The latest source refresh failed; cached data was checked.',
      ],
    );
  }
}

(List<UasAirspaceIntersection>, List<String>, int) _check(
  (Map<String, dynamic>, List<Wgs84Coordinate>) input,
) {
  final assessment = UasDatasetAssessment.inspect(input.$1);
  final index = PolygonIntersectionIndex.fromGeoJson(assessment.geoJson);
  final features = assessment.geoJson['features'] as List;
  return (
    [
      for (final hit in index.check(input.$2))
        UasAirspaceIntersection(
          UasZoneDetails.fromFeature(
            features[hit.featureIndex] as Map,
            fallbackId: 'feature-${hit.featureIndex + 1}',
          ),
          hit,
        ),
    ],
    [
      ...assessment.issues,
      if (index.unassessedFeatureCount > 0)
        '${index.unassessedFeatureCount} features could not be fully checked '
            'as polygons (unsupported or unusable geometry).',
    ],
    index.assessedFeatureCount,
  );
}
