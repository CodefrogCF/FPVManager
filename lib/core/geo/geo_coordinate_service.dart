// Swiss coordinate conversions based on the
// official swisstopo approximate formulas (2016).

// Intended for navigation and visualization.
// Not suitable for surveying or safety-critical
// obstacle-clearance calculations.

class Wgs84Coordinate {
  const Wgs84Coordinate({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class Lv95Coordinate {
  const Lv95Coordinate({required this.easting, required this.northing});

  final double easting;
  final double northing;
}

/// Vertical reference systems are explicitly typed
/// to prevent accidental mixing of height values.
enum VerticalReference {
  wgs84Ellipsoid,
  besselEllipsoid,
  ln02,
  lhn95,
  unverified,
}

extension VerticalReferenceLabel on VerticalReference {
  String get label => switch (this) {
    VerticalReference.wgs84Ellipsoid => 'WGS84 ellipsoid',
    VerticalReference.besselEllipsoid => 'Bessel ellipsoid',
    VerticalReference.ln02 => 'AMSL (Swiss LN02)',
    VerticalReference.lhn95 => 'AMSL (Swiss LHN95)',
    VerticalReference.unverified => 'unverified reference',
  };
}

/// AGL is relative to terrain at a particular location,
/// not an independent geodetic reference datum.
enum FlightAltitudeMode { absolute, aboveGroundLevel }

class ReferencedElevation {
  const ReferencedElevation({required this.meters, required this.reference});

  final double meters;
  final VerticalReference reference;
}

class GeoCoordinateService {
  const GeoCoordinateService();

  /// Conservative geographical coverage for the
  /// approximate Swiss coordinate formulas.
  ///
  /// This is a bounding box, not the Swiss border.
  bool supportsWgs84(Wgs84Coordinate coordinate) {
    return coordinate.latitude.isFinite &&
        coordinate.longitude.isFinite &&
        coordinate.latitude >= 45.5 &&
        coordinate.latitude <= 48.5 &&
        coordinate.longitude >= 5.5 &&
        coordinate.longitude <= 11.0;
  }

  bool supportsLv95(Lv95Coordinate coordinate) {
    return coordinate.easting.isFinite &&
        coordinate.northing.isFinite &&
        coordinate.easting >= 2400000 &&
        coordinate.easting <= 2900000 &&
        coordinate.northing >= 1000000 &&
        coordinate.northing <= 1400000;
  }

  /// Approximate WGS84 -> LV95 conversion.
  ///
  /// Latitude and longitude are decimal degrees.
  /// Easting and northing are returned in meters.
  Lv95Coordinate wgs84ToLv95(Wgs84Coordinate coordinate) {
    if (!supportsWgs84(coordinate)) {
      throw ArgumentError('Coordinate outside supported Swiss region');
    }

    // Convert degrees to arcseconds and normalize
    // relative to the Bern reference position.
    final latitudeAux = (coordinate.latitude * 3600 - 169028.66) / 10000;

    final longitudeAux = (coordinate.longitude * 3600 - 26782.5) / 10000;

    final phi = latitudeAux;
    final lambda = longitudeAux;

    // Official swisstopo approximation.
    final easting =
        2600072.37 +
        211455.93 * lambda -
        10938.51 * lambda * phi -
        0.36 * lambda * phi * phi -
        44.54 * lambda * lambda * lambda;

    final northing =
        1200147.07 +
        308807.95 * phi +
        3745.25 * lambda * lambda +
        76.63 * phi * phi -
        194.56 * lambda * lambda * phi +
        119.79 * phi * phi * phi;

    return Lv95Coordinate(easting: easting, northing: northing);
  }

  /// Approximate LV95 -> WGS84 conversion.
  Wgs84Coordinate lv95ToWgs84(Lv95Coordinate coordinate) {
    if (!supportsLv95(coordinate)) {
      throw ArgumentError('Coordinate outside supported LV95 region');
    }

    final e = (coordinate.easting - 2600000) / 1000000;

    final n = (coordinate.northing - 1200000) / 1000000;

    // Longitude auxiliary value.
    final longitudeAux =
        2.6779094 +
        4.728982 * e +
        0.791484 * e * n +
        0.1306 * e * n * n -
        0.0436 * e * e * e;

    // Latitude auxiliary value.
    final latitudeAux =
        16.9023892 +
        3.238272 * n -
        0.270978 * e * e -
        0.002528 * n * n -
        0.0447 * e * e * n -
        0.0140 * n * n * n;

    return Wgs84Coordinate(
      latitude: latitudeAux * 100 / 36,
      longitude: longitudeAux * 100 / 36,
    );
  }
}
