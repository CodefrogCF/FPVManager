import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/geo/altitude_service.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/core/models/route_transfer.dart';
import 'package:fpvmanager/features/routes/transfer/route_file_codec.dart';

void main() {
  Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));
  final route = ImportedRoute('A <ridge> & lake', [
    for (final height in <WaypointHeight?>[
      null,
      const AglWaypointHeight(AboveGroundHeight(40)),
      for (final ref in VerticalReference.values)
        AbsoluteWaypointHeight(
          ReferencedElevation(meters: 600, reference: ref),
        ),
    ])
      RouteWaypointInput(
        position: const Wgs84Coordinate(latitude: 47, longitude: 8),
        height: height,
        speedMetersPerSecond: 12,
      ),
  ]);
  for (final format in RouteFileFormat.values) {
    test(
      '${format.name} round trip retains height references, speed, names and coordinate order',
      () {
        final encoded = encodeRouteFile(route, format),
            decoded = decodeRouteFile(encoded).routes.single;
        expect(decoded.name, route.name);
        expect(decoded.points.length, route.points.length);
        for (var i = 0; i < route.points.length; i++) {
          final a = route.points[i], b = decoded.points[i];
          expect(b.position.latitude, 47);
          expect(b.position.longitude, 8);
          expect(b.height?.runtimeType, a.height?.runtimeType);
          expect(b.height?.meters, a.height?.meters);
          if (a.height is AbsoluteWaypointHeight) {
            expect(
              (b.height as AbsoluteWaypointHeight).elevation.reference,
              (a.height as AbsoluteWaypointHeight).elevation.reference,
            );
          }
          expect(b.speedMetersPerSecond, 12);
        }
        expect(utf8.decode(encoded), isNot(contains('batteryId')));
      },
    );
  }
  test('standard GeoJSON third ordinate is ellipsoid metres and legacy CRS is rejected', () {
    final imported = decodeRouteFile(
      bytes('{"type":"LineString","coordinates":[[8,47,600],[8.1,47,650]]}'),
    );
    final height =
        imported.routes.single.points.first.height as AbsoluteWaypointHeight;
    expect(height.elevation.reference, VerticalReference.wgs84Ellipsoid);
    expect(
      () => decodeRouteFile(
        bytes('{"type":"LineString","crs":{},"coordinates":[[8,47],[8.1,47]]}'),
      ),
      throwsFormatException,
    );
    final json = jsonDecode(
      utf8.decode(encodeRouteFile(route, RouteFileFormat.geoJson)),
    );
    final coordinates = json['features'][0]['geometry']['coordinates'] as List;
    expect(
      (coordinates[1] as List).length,
      2,
    ); // AGL never appears as ellipsoid Z.
    expect((coordinates[2] as List).length, 3);
  });
  test('GPX track gaps remain separate and unspecified elevation datum stays unknown', () {
    final preview = decodeRouteFile(
      bytes(
        '''<gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1"><trk><name>Track</name>
      <trkseg><trkpt lat="47" lon="8"><ele>500</ele></trkpt><trkpt lat="47" lon="8.1"/></trkseg>
      <trkseg><trkpt lat="47" lon="9"/><trkpt lat="47" lon="9.1"/></trkseg></trk></gpx>''',
      ),
    );
    expect(preview.routes.length, 2);
    expect(
      (preview.routes.first.points.first.height as AbsoluteWaypointHeight)
          .elevation
          .reference,
      VerticalReference.unverified,
    );
    expect(preview.warnings.any((s) => s.contains('unverified')), isTrue);
  });
  test('malformed, oversized, nested, ambiguous and unsupported imports fail explicitly', () {
    for (final text in [
      '<!DOCTYPE gpx [<!ENTITY x SYSTEM "https://example.invalid/private">]><gpx/>',
      '<kml xmlns="http://www.opengis.net/kml/2.2"/>',
      '{"type":"LineString","coordinates":[[8,100],[8,47]]}',
      '{"type":"LineString","coordinates":[[8,47]]}',
      '{"type":"Point","coordinates":[8,47]}',
      '{"type":"LineString","coordinates":[[8,47,1e999],[8,47]]}',
      '${'<gpx>' * 65}${'</gpx>' * 65}',
      '${'{"a":' * 65}0${'}' * 65}',
      '{"type":"Feature","properties":{"fpvmanager":{"version":1,"waypoints":[]}},"geometry":{"type":"LineString","coordinates":[[8,47],[8.1,47]]}}',
    ]) {
      expect(
        () => decodeRouteFile(bytes(text)),
        throwsFormatException,
        reason: text,
      );
    }
    expect(
      () => decodeRouteFile(Uint8List(routeFileMaxBytes + 1)),
      throwsFormatException,
    );
    final json = jsonDecode(
      utf8.decode(encodeRouteFile(route, RouteFileFormat.geoJson)),
    );
    json['features'][0]['geometry']['coordinates'][1] = [8, 47, 40];
    expect(
      () => decodeRouteFile(bytes(jsonEncode(json))),
      throwsFormatException,
    );
  });
}
