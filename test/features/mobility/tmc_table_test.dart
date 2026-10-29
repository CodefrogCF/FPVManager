import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/mobility/tmc_table.dart';
import 'package:fpvmanager/features/mobility/traffic_snapshot.dart';
import 'package:fpvmanager/features/mobility/tmc_traffic_resolution.dart';

import '../../helpers/tmc_fixture.dart';

void main() {
  test('LTEF metadata, scaled coordinates, road references, UTF-8 and neighbor direction survive import and cache roundtrip', () {
    for (final stored in [true, false]) {
      final table = TmcTable.fromJson(
        importTmcTable(tmcZip(stored: stored)).toJson(),
      );
      expect(table.version, '7.5');
      expect(table.nodes, hasLength(3));
      expect(table.nodes[1]!.name, 'Zürich');
      expect(table.nodes[1]!.point.toJson(), [8.0, 47.0002]);
      expect(table.nodes[2]!.positive, 3);
      expect(table.nodes[2]!.negative, 1);
      expect(table.nodes[2]!.roads, {'A1'});
      expect(table.publication, '29/10/2026');
    }
  });
  test('DATEX parser retains method, point roles, offsets, country and version in the same source part', () {
    for (final method in ['2', '4']) {
      final data = parseTrafficSnapshot(
        tmcXml(method: method, primaryOffset: 25, secondaryOffset: 30),
      );
      final part = (data['records'] as List).single['routingEvidence'][0];
      final r = part['tmc'] as Map;
      expect(r['country'], '4');
      expect(r['table'], '9');
      expect(r['version'], '7.5');
      expect(r['primary']['code'], 3);
      expect(r['secondary']['code'], 1);
      expect(r['primary']['offsetMeters'], method == '4' ? 25 : 0);
      expect(r['secondary']['offsetMeters'], method == '4' ? 30 : 0);
      expect(neededTmcVersions(data), {'7.5'});
    }
  });
  test('positive, negative and both-direction sections follow reciprocal topology without converting codes into compass directions', () {
    final table = fixtureTmcTable();
    final positive = table.resolve(
      tmcReference(primaryOffset: 20, secondaryOffset: 30),
    );
    expect(positive['status'], 'resolved');
    expect(positive['codes'], [1, 2, 3]);
    expect(positive['primaryOffset'], 20);
    expect(positive['secondaryOffset'], 30);
    final negative = table.resolve(
      tmcReference(direction: 'negative', primary: 1, secondary: 3),
    );
    expect(negative['codes'], [3, 2, 1]);
    final both = table.resolve(
      tmcReference(direction: 'both', primary: 1, secondary: 3),
    );
    expect(both['codes'], [3, 2, 1]);
    expect(both['both'], true);
  });
  test('point offsets remain distances from the primary reference, with a separate chain for subsequent route placement', () {
    final r = fixtureTmcTable().resolve(
      tmcReference(linear: false, primaryOffset: 120),
    );
    expect(r['status'], 'resolved');
    expect(r['codes'], [1, 2, 3]);
    expect(r['primaryOffset'], 120);
    expect(r['point'], [8.0, 47.0018]);
    expect(r['linear'], false);
  });
  test('wrong identity, missing codes, unknown directions and incomplete or cyclic chains cannot produce verified sections', () {
    final table = fixtureTmcTable();
    for (final change in <Map<String, dynamic>>[
      {'version': '7.3'},
      {'country': '51'},
      {'table': '8'},
      {'direction': 'unknown'},
      {
        'primary': {'code': 999, 'offsetMeters': 0},
      },
      {
        'primary': {'code': 3, 'offsetMeters': null},
      },
      {
        'primary': {'code': 3, 'offsetMeters': double.infinity},
      },
      {'unsupported': 'unknown method'},
    ]) {
      expect(
        table.resolve({...tmcReference(), ...change})['status'],
        isNot('resolved'),
        reason: '$change',
      );
    }
    final broken = importTmcTable(
      tmcZip(
        overrides: {
          'POFFSETS.DAT': tmcFiles()['POFFSETS.DAT']!.replaceFirst(
            '51;9;2;1;3',
            '51;9;2;3;3',
          ),
        },
      ),
    );
    expect(broken.resolve(tmcReference())['status'], 'reference');
    expect(
      table.resolve(
        tmcReference(linear: false, primary: 1, primaryOffset: 10),
      )['status'],
      'reference',
    );
  });
  test('wrong coordinate scale, mixed tables, duplicate names and inconsistent metadata reject the whole import', () {
    final files = tmcFiles();
    for (final changes in <Map<String, String>>[
      {
        'LOCATIONDATASETS.DAT': files['LOCATIONDATASETS.DAT']!.replaceFirst(
          '51;9',
          '52;9',
        ),
      },
      {
        'POINTS.DAT': files['POINTS.DAT']!.replaceFirst(
          '+4700020',
          '+470002000',
        ),
      },
      {'NAMES.DAT': '${files['NAMES.DAT']}51;1;101;Changed\n'},
      {'POFFSETS.DAT': '${files['POFFSETS.DAT']}51;9;2;1;3\n'},
      {'README.DAT': '0;date;;ASTRA;unknown\n'},
      {'POINTS.DAT': files['POINTS.DAT']!.replaceFirst('51;9;2', '51;8;2')},
    ]) {
      expect(
        () => importTmcTable(tmcZip(overrides: changes)),
        throwsFormatException,
      );
    }
  });
  test('unsafe archive paths, CRC corruption, missing files and excessive expansion are rejected before publication', () {
    expect(
      () => importTmcTable(Uint8List(8 * 1024 * 1024 + 1)),
      throwsFormatException,
    );
    expect(
      () => importTmcTable(
        tmcZip(overrides: {'POINTS.DAT': 'x' * (8 * 1024 * 1024 + 1)}),
      ),
      throwsFormatException,
    );
    expect(
      () => importTmcTable(tmcZip(overrides: {'POINTS.DAT': ''})),
      throwsFormatException,
    );
    // Replace equally sized directory text in both local and central names.
    final hostile = tmcZip(folder: 'bad');
    for (var i = 0; i < hostile.length - 4; i++) {
      if (hostile[i] == 98 &&
          hostile[i + 1] == 97 &&
          hostile[i + 2] == 100 &&
          hostile[i + 3] == 47) {
        hostile.setRange(i, i + 3, [46, 46, 47]);
      }
    }
    expect(() => importTmcTable(hostile), throwsFormatException);
    final corrupt = tmcZip(stored: true), d = ByteData.sublistView(corrupt);
    d.setUint32(14, d.getUint32(14, Endian.little) ^ 1, Endian.little);
    for (var i = 0; i < corrupt.length - 46; i++) {
      if (d.getUint32(i, Endian.little) == 0x02014b50) {
        d.setUint32(
          i + 16,
          d.getUint32(i + 16, Endian.little) ^ 1,
          Endian.little,
        );
        break;
      }
    }
    expect(() => importTmcTable(corrupt), throwsFormatException);
  });
}
