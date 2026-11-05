import 'uas_zone_details.dart';
import 'uas_restriction.dart';

/// Local checks of the downloaded content, not a certification of coverage or
/// official validity. Only supported, structurally usable geometry is rendered.
class UasDatasetAssessment {
  const UasDatasetAssessment._({
    required this.geoJson,
    required this.sourceFeatureCount,
    required this.skippedFeatureCount,
    required this.featuresMissingDetails,
    required this.declaredTotal,
    required this.hasNextPage,
    required this.countMismatch,
    required this.categoryCounts,
    required this.timeDependentFeatureCount,
  });

  factory UasDatasetAssessment.inspect(Map<String, dynamic> source) {
    final features = source['features'];
    if (source['type'] != 'FeatureCollection' || features is! List) {
      throw const FormatException('Invalid UAS feature collection');
    }
    // Most official features are valid. Allocate a filtered feature list only
    // when an unusable geometry actually occurs; never duplicate coordinates.
    List<Object?>? filtered;
    var validCount = 0;
    var missing = 0;
    var timed = 0;
    final categories = <UasRestrictionCategory, int>{};
    for (var index = 0; index < features.length; index++) {
      final feature = features[index];
      if (feature is! Map ||
          feature['type'] != 'Feature' ||
          !_geometry(feature['geometry'])) {
        // The prefix was already validated; from now on keep only good items.
        filtered ??= <Object?>[
          for (var prefix = 0; prefix < index; prefix++) features[prefix],
        ];
        continue;
      }
      validCount++;
      filtered?.add(feature);
      final properties = feature['properties'];
      // Avoid stringifying/copying every GeoJSON property just to count types.
      // Zone selection still retains the original source attributes.
      const relevant = [
        'type',
        'restriction',
        'reason',
        'identifier',
        'permanent',
        'startDateTime',
        'endDateTime',
        'startTime',
        'endTime',
        'authorityName',
        'purpose',
        'restrictionConditions',
        'uomDimensions',
        'lowerLimit',
        'upperLimit',
        'lowerVerticalReference',
        'upperVerticalReference',
      ];
      final typedAttributes = <String, String>{};
      if (properties is Map) {
        for (final key in relevant) {
          final value = properties[key];
          if (value is String) typedAttributes[key] = value;
          if (value is num || value is bool) typedAttributes[key] = '$value';
        }
      }
      final restriction = UasRestriction.fromAttributes(typedAttributes);
      categories.update(
        restriction.category,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      if (restriction.hasSchedule) timed++;
      if (properties is! Map ||
          UasZoneDetails.missingSourceFields(properties).isNotEmpty) {
        missing++;
      }
    }
    if (features.isNotEmpty && validCount == 0) {
      throw FormatException(
        'None of the ${features.length} UAS features has usable geometry. '
        'The incomplete dataset was not imported.',
      );
    }
    final total =
        _count(source['numberMatched']) ?? _count(source['totalFeatures']);
    final returned = _count(source['numberReturned']);
    final links = source['links'];
    return UasDatasetAssessment._(
      // Source is already a parsed object. If all features are usable, the
      // renderer may consume the very same object without a shallow copy.
      // Otherwise only a small top-level map and filtered list are created.
      geoJson: filtered == null
          ? source
          : Map.unmodifiable({
              ...source,
              'features': List.unmodifiable(filtered),
            }),
      sourceFeatureCount: features.length,
      skippedFeatureCount: features.length - validCount,
      featuresMissingDetails: missing,
      declaredTotal: total,
      hasNextPage:
          links is List &&
          links.any(
            (link) =>
                link is Map &&
                link['rel'] == 'next' &&
                link['href'] is String &&
                (link['href'] as String).trim().isNotEmpty,
          ),
      categoryCounts: Map.unmodifiable(categories),
      timeDependentFeatureCount: timed,
      countMismatch:
          (total != null && total < features.length) ||
          (returned != null && returned != features.length),
    );
  }

  final Map<String, dynamic> geoJson;
  final int sourceFeatureCount;
  final int skippedFeatureCount;
  final int featuresMissingDetails;
  final int? declaredTotal;
  final bool hasNextPage;
  final bool countMismatch;
  final Map<UasRestrictionCategory, int> categoryCounts;
  final int timeDependentFeatureCount;
  int get renderedFeatureCount => sourceFeatureCount - skippedFeatureCount;

  List<String> get issues => [
    if (sourceFeatureCount == 0) 'The source returned an empty dataset.',
    if (skippedFeatureCount > 0)
      '$skippedFeatureCount of $sourceFeatureCount source features could not be displayed.',
    if (featuresMissingDetails > 0)
      '$featuresMissingDetails displayed features lack key source details.',
    if (declaredTotal != null && declaredTotal! > sourceFeatureCount)
      'Only $sourceFeatureCount of $declaredTotal declared features were received.',
    if (hasNextPage) 'The source declares another page of data.',
    if (countMismatch)
      'Source feature counts do not match the downloaded content.',
  ];
  bool get hasIssues => issues.isNotEmpty;

  static int? _count(Object? value) {
    final count = value is int
        ? value
        : value is String
        ? int.tryParse(value)
        : null;
    return count != null && count >= 0 ? count : null;
  }

  static bool _position(Object? value) {
    if (value is! List ||
        value.length < 2 ||
        value[0] is! num ||
        value[1] is! num) {
      return false;
    }
    final lon = value[0] as num;
    final lat = value[1] as num;
    if (!lon.isFinite || !lat.isFinite || lon.abs() > 180 || lat.abs() > 90) {
      return false;
    }
    // Do not allocate an iterable from skip(2) for every position.
    for (var i = 2; i < value.length; i++) {
      final ordinate = value[i];
      if (ordinate is! num || !ordinate.isFinite) {
        return false;
      }
    }
    return true;
  }

  static bool _line(Object? value, {bool ring = false}) {
    if (value is! List || value.length < (ring ? 4 : 2)) {
      return false;
    }
    num? firstLon;
    num? firstLat;
    num? secondLon;
    num? secondLat;
    var distinct = 0;
    for (final point in value) {
      if (!_position(point)) {
        return false;
      }
      if (!ring || distinct >= 3) {
        continue;
      }
      final position = point as List;
      final lon = position[0] as num;
      final lat = position[1] as num;
      if (distinct == 0) {
        firstLon = lon;
        firstLat = lat;
        distinct = 1;
      } else if (lon != firstLon || lat != firstLat) {
        if (distinct == 1) {
          secondLon = lon;
          secondLat = lat;
          distinct = 2;
        } else if (lon != secondLon || lat != secondLat) {
          distinct = 3;
        }
      }
    }
    if (!ring) {
      return true;
    }
    final first = value.first as List;
    final last = value.last as List;
    return distinct >= 3 && first[0] == last[0] && first[1] == last[1];
  }

  static bool _polygon(Object? value) =>
      value is List &&
      value.isNotEmpty &&
      value.every((ring) => _line(ring, ring: true));

  static bool _geometry(Object? value, [int depth = 0]) {
    if (value is! Map || depth > 4) return false;
    final coordinates = value['coordinates'];
    bool many(bool Function(Object?) check) =>
        coordinates is List &&
        coordinates.isNotEmpty &&
        coordinates.every(check);
    return switch (value['type']) {
      'Point' => _position(coordinates),
      'MultiPoint' => many(_position),
      'LineString' => _line(coordinates),
      'MultiLineString' => many(_line),
      'Polygon' => _polygon(coordinates),
      'MultiPolygon' => many(_polygon),
      'GeometryCollection' =>
        value['geometries'] is List &&
            (value['geometries'] as List).isNotEmpty &&
            (value['geometries'] as List).every(
              (geometry) => _geometry(geometry, depth + 1),
            ),
      _ => false,
    };
  }
}
