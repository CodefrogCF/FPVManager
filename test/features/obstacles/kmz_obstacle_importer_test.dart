import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/obstacles/kmz_obstacle_importer.dart';
import 'package:fpvmanager/features/obstacles/obstacle_models.dart';

import '../../helpers/obstacle_fixture.dart';

void main() {
  Future<List<ObstacleFeature>> read(String kml) async {
    final features = <ObstacleFeature>[];
    await const KmzObstacleImporter().import(
      obstacleKmz(kml),
      onBatch: (b) async => features.addAll(b),
    );
    return features;
  }

  test('source IDs, classifications, multipart geometry and modes survive ingestion', () async {
    final f = (await read(obstacleKml())).single;
    expect(f.id, 'source-1');
    expect(f.attributes['uuid'], 'test-uuid');
    expect(f.category, ObstacleCategory.powerLines);
    expect(f.parts.length, 2);
    expect(f.parts.first.mode, 'absolute');
    expect(f.parts.first.coordinates.last, [8.401, 46.701, 610]);
    expect(f.approximate, isTrue);
    expect(f.west, 8.4);
    expect(f.east, 8.401);
    expect(
      (await read(obstacleKml(type: 'NEW_TYPE'))).single.category,
      ObstacleCategory.unknown,
    );
    expect(
      (await read(obstacleKml(type: 'CATENARY'))).single.category,
      ObstacleCategory.cableways,
    );
    expect(
      (await read(obstacleKml(type: 'POLE'))).single.category,
      ObstacleCategory.masts,
    );
  });
  test(
    'missing heights and relative or unknown references remain explicit',
    () async {
      for (final mode in ['clampToGround', 'relativeToGround', 'futureMode']) {
        final p = (await read(
          obstacleKml(mode: mode, coordinates: '8.4,46.7 8.5,46.8'),
        )).single.parts.first;
        expect(p.mode, mode);
        expect(p.coordinates.first.length, 2);
      }
    },
  );
  test('polygon rings and holes preserve original altitudes', () async {
    const kml =
        '<kml xmlns="http://www.opengis.net/kml/2.2"><Placemark id="p"><Polygon>'
        '<altitudeMode>absolute</altitudeMode><outerBoundaryIs><LinearRing><coordinates>'
        '8,46,500 9,46,500 9,47,500 8,46,500</coordinates></LinearRing></outerBoundaryIs>'
        '<innerBoundaryIs><LinearRing><coordinates>8.1,46.1,500 8.2,46.1,500 8.2,46.2,500 8.1,46.1,500'
        '</coordinates></LinearRing></innerBoundaryIs></Polygon></Placemark></kml>';
    final f = (await read(kml)).single;
    expect(f.parts.map((p) => p.kind), ['PolygonOuter', 'PolygonHole']);
    expect(f.parts.every((p) => p.mode == 'absolute'), isTrue);
  });
  test('external resources are ignored; source publication and validity are retained', () async {
    final r = await const KmzObstacleImporter().import(
      obstacleKmz(
        obstacleKml(
          metadata: '<ExtendedData><SchemaData><SimpleData name="datasetValidFrom">2026-10-20 00:00:00</SimpleData></SchemaData></ExtendedData>',
          extra: '<NetworkLink><Link><href>https://invalid.test/evil.kml</href></Link></NetworkLink>',
        ),
      ),
      onBatch: (_) async {},
    );
    expect(r.metadata['datasetValidFrom'], '2026-10-20 00:00:00');
    expect(r.metadata['ignoredNetworkLinks'], '1');
  });
  test(
    'unsafe archive paths, extra KMLs and symlinks are rejected before import',
    () async {
      for (final path in [
        '../full.kml',
        'C:/full.kml',
        '/full.kml',
        'a\\full.kml',
        'a/./full.kml',
      ]) {
        await expectLater(
          const KmzObstacleImporter().import(
            obstacleKmz(obstacleKml(), path: path),
            onBatch: (_) async {},
          ),
          throwsFormatException,
        );
      }
      await expectLater(
        const KmzObstacleImporter().import(
          obstacleKmz(obstacleKml(), files: {'other.kml': obstacleKml()}),
          onBatch: (_) async {},
        ),
        throwsFormatException,
      );
      final bytes = obstacleKmz(obstacleKml());
      final d = ByteData.sublistView(bytes);
      for (var i = 0; i < bytes.length - 46; i++) {
        if (d.getUint32(i, Endian.little) == 0x02014b50) {
          d.setUint32(i + 38, 0xa0000000, Endian.little);
          break;
        }
      }
      await expectLater(
        const KmzObstacleImporter().import(bytes, onBatch: (_) async {}),
        throwsFormatException,
      );
    },
  );
  test('CRC mismatch, bounded decompression and malformed geometry fail explicitly', () async {
    final bytes = obstacleKmz(obstacleKml());
    final d = ByteData.sublistView(bytes);
    for (var i = 0; i < bytes.length - 46; i++) {
      if (d.getUint32(i, Endian.little) == 0x02014b50) {
        d.setUint32(i + 16, 0, Endian.little);
        d.setUint32(14, 0, Endian.little);
        break;
      }
    }
    await expectLater(
      const KmzObstacleImporter().import(bytes, onBatch: (_) async {}),
      throwsFormatException,
    );
    await expectLater(
      const KmzObstacleImporter(maxExpandedBytes: 100)
          .import(obstacleKmz(obstacleKml()), onBatch: (_) async {}),
      throwsFormatException,
    );
    for (final coordinates in [
      'NaN,46,500 8,46,600',
      '181,46,500 8,46,600',
      '8,46,500',
      '8,46,Infinity 8,46,600',
    ]) {
      await expectLater(
        read(obstacleKml(coordinates: coordinates)),
        throwsFormatException,
      );
    }
  });
  test(
    'DTD, deep XML, oversized comments/quoted tokens and records are bounded',
    () async {
      final inputs = [
        '<!DOCTYPE kml [<!ENTITY x "danger">]>${obstacleKml()}',
        obstacleKml(extra: '${'<Folder>' * 40}${'</Folder>' * 40}'),
        obstacleKml(extra: '<!--${'<x>' * 100000}-->'),
        obstacleKml(extra: '<Folder id="${'x>' * 200000}"/>'),
      ];
      for (final kml in inputs) {
        await expectLater(
          const KmzObstacleImporter().import(
            obstacleKmz(kml, level: 0),
            onBatch: (_) async {},
          ),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'import cancellation stops before publication or further batches',
    () async {
      await expectLater(
        const KmzObstacleImporter().import(
          obstacleKmz(obstacleKml()),
          cancelled: () => true,
          onBatch: (_) async => fail('cancelled import delivered a batch'),
        ),
        throwsStateError,
      );
    },
  );
}
