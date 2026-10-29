import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fpvmanager/features/mobility/tmc_table.dart';

import 'route_traffic_fixtures.dart';

Map<String, String> tmcFiles({String version = '7.5'}) => {
  'LOCATIONDATASETS.DAT': 'CID;TABCD;VERSION\n51;9;$version\n',
  'README.DAT': '0;29/10/2026;;ASTRA;UTF-8;2;7\n',
  'NAMES.DAT':
      'CID;LID;NID;NAME\n51;1;101;Zürich\n51;1;102;Mitte\n51;1;103;Nord\n',
  'ROADS.DAT': 'CID;TABCD;LCD;ROADNUMBER\n51;9;100;A1\n',
  'SEGMENTS.DAT': 'CID;TABCD;LCD;ROADNUMBER;ROA_LCD\n51;9;200;;100\n',
  'POFFSETS.DAT': 'CID;TABCD;LCD;NEG_OFF_LCD;POS_OFF_LCD\n51;9;1;;2\n51;9;2;1;3\n51;9;3;2;\n',
  'POINTS.DAT':
      'CID;TABCD;LCD;XCOORD;YCOORD;N1ID;N2ID;ROA_LCD;SEG_LCD\n'
      '51;9;1;+00800000;+4700020;101;;100;200\n'
      '51;9;2;+00800000;+4700100;102;;100;200\n'
      '51;9;3;+00800000;+4700180;103;;100;200\n',
};
Uint8List tmcZip({
  String version = '7.5',
  Map<String, String> overrides = const {},
  String folder = 'CH_LTEF',
  bool stored = false,
}) {
  final archive = Archive();
  for (final e in {...tmcFiles(version: version), ...overrides}.entries) {
    archive.addFile(
      ArchiveFile(
        '$folder/${e.key}',
        utf8.encode(e.value).length,
        utf8.encode(e.value),
      ),
    );
  }
  return Uint8List.fromList(
    ZipEncoder().encode(archive, level: stored ? 0 : 1),
  );
}

TmcTable fixtureTmcTable() => importTmcTable(tmcZip());
Map<String, dynamic> tmcReference({
  String version = '7.5',
  String direction = 'positive',
  String method = '4',
  bool linear = true,
  int primary = 3,
  int secondary = 1,
  double primaryOffset = 0,
  double secondaryOffset = 0,
}) => {
  'country': '4',
  'table': '9',
  'version': version,
  'method': method,
  'direction': direction,
  'linear': linear,
  'primary': {'code': primary, 'offsetMeters': primaryOffset},
  if (linear) 'secondary': {'code': secondary, 'offsetMeters': secondaryOffset},
};
String tmcXml({
  String version = '7.5',
  String direction = 'positive',
  String method = '4',
  bool linear = true,
  int primary = 3,
  int secondary = 1,
  double primaryOffset = 0,
  double secondaryOffset = 0,
}) {
  String p(String role, int code, double offset) =>
      '<alertCMethod$method${role}PointLocation>'
      '<alertCLocation><specificLocation>$code</specificLocation></alertCLocation>'
      '${method == '4' ? '<offsetDistance><offsetDistance>$offset</offsetDistance></offsetDistance>' : ''}'
      '</alertCMethod$method${role}PointLocation>';
  final shape = linear ? 'Linear' : 'Point';
  final group =
      '<groupOfLocations><alertC$shape xsi:type="AlertCMethod$method$shape">'
      '<alertCLocationCountryCode>4</alertCLocationCountryCode>'
      '<alertCLocationTableNumber>9</alertCLocationTableNumber>'
      '<alertCLocationTableVersion>$version</alertCLocationTableVersion>'
      '<alertCDirection><alertCDirectionCoded>$direction</alertCDirectionCoded></alertCDirection>'
      '${p('Primary', primary, primaryOffset)}${linear ? p('Secondary', secondary, secondaryOffset) : ''}'
      '</alertC$shape></groupOfLocations>';
  return trafficXml().replaceFirst(
    RegExp(r'<groupOfLocations>.*?</groupOfLocations>', dotAll: true),
    group,
  );
}
