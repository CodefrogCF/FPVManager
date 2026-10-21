import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

String obstacleKml({
  String type = 'TRANSMISSION_LINE',
  String mode = 'absolute',
  String coordinates = '8.4,46.7,600 8.401,46.701,610',
  String extra = '',
  String metadata = '',
}) =>
    '<kml xmlns="http://www.opengis.net/kml/2.2"><Document>$metadata'
    '<Placemark id="source-1"><name>Fixture cable</name><ExtendedData><SchemaData>'
    '<SimpleData name="uuid">test-uuid</SimpleData><SimpleData name="obstacleType">$type</SimpleData>'
    '<SimpleData name="maxHeightAGL">40</SimpleData><SimpleData name="topElevationAMSL">610</SimpleData>'
    '<SimpleData name="effectiveDate">2026-10-01</SimpleData></SchemaData></ExtendedData>'
    '<MultiGeometry><LineString><altitudeMode>$mode</altitudeMode><coordinates>$coordinates</coordinates></LineString>'
    '<Point><altitudeMode>$mode</altitudeMode><coordinates>8.4,46.7,600</coordinates></Point></MultiGeometry>'
    '</Placemark>$extra</Document></kml>';

Uint8List obstacleKmz(
  String kml, {
  String path = 'full.kml',
  Map<String, String> files = const {},
  int level = 1,
}) {
  // The encoder normalizes paths. Replace the raw local/central filename bytes
  // afterward so security fixtures actually contain the requested hostile path.
  final rawName = utf8.encode(path);
  final archive = Archive()
    ..addFile(ArchiveFile.string('f' * rawName.length, kml));
  for (final e in files.entries) {
    archive.addFile(ArchiveFile.string(e.key, e.value));
  }
  final bytes = Uint8List.fromList(ZipEncoder().encode(archive, level: level));
  final data = ByteData.sublistView(bytes);
  var replacedLocal = false, replacedCentral = false;
  for (var i = 0; i < bytes.length - 46; i++) {
    final signature = data.getUint32(i, Endian.little);
    if (signature == 0x04034b50 && !replacedLocal) {
      bytes.setRange(i + 30, i + 30 + rawName.length, rawName);
      replacedLocal = true;
    }
    if (signature == 0x02014b50 && !replacedCentral) {
      bytes.setRange(i + 46, i + 46 + rawName.length, rawName);
      replacedCentral = true;
    }
  }
  return bytes;
}

Map<String, dynamic> obstacleStac({
  String checksum = '',
  String updated = '2026-10-20T00:00:00Z',
  String format = 'application/vnd.google-earth.kmz',
}) => {
  'type': 'FeatureCollection',
  'features': [
    {
      'id': 'luftfahrthindernis',
      'properties': {'updated': updated},
      'assets': {
        'full_4326.kmz': {
          'href': 'https://data.geo.admin.ch/fixture/full.kmz',
          'type': format,
          'proj:epsg': 4326,
          if (checksum.isNotEmpty) 'file:checksum': checksum,
        },
      },
    },
  ],
  'links': [],
};

String stacJson(Map<String, dynamic> value) => jsonEncode(value);
