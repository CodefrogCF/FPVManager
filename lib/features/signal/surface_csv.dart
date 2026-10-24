import 'dart:typed_data';

import '../../core/geo/geo_coordinate_service.dart';
import '../../core/models/bounded_csv.dart';
import '../../core/models/signal_settings.dart';

List<SurfaceObservation> decodeSurfaceCsv(Uint8List bytes) {
  final rows = readBoundedCsv(bytes, maxRows: 101), header = rows.first;
  const columns = [
    'latitude',
    'longitude',
    'height_m_agl',
    'radius_m',
    'kind',
    'source',
  ];
  if (header.length != columns.length ||
      !List.generate(
        columns.length,
        (i) => header[i] == columns[i],
      ).every((v) => v)) {
    throw const FormatException(
      'Use latitude,longitude,height_m_agl,radius_m,kind,source',
    );
  }
  final observations = <SurfaceObservation>[];
  for (final row in rows.skip(1)) {
    if (row.length != 6) throw const FormatException('Invalid surface CSV row');
    observations.add(
      SurfaceObservation(
        position: Wgs84Coordinate(
          latitude: double.parse(row[0]),
          longitude: double.parse(row[1]),
        ),
        height: double.parse(row[2]),
        radius: double.parse(row[3]),
        kind: row[4].trim(),
        source: row[5].trim(),
      ),
    );
  }
  SignalSettings(
    pilot: const Wgs84Coordinate(latitude: 0, longitude: 0),
    surfaces: observations,
  ).validate();
  return List.unmodifiable(observations);
}
