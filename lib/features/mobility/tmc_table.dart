import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'road_routing.dart';
import 'tmc_archive.dart';

class TmcNode {
  const TmcNode(
    this.code,
    this.point,
    this.name,
    this.roads,
    this.positive,
    this.negative,
  );
  final int code;
  final MobilityPoint point;
  final String name;
  final Set<String> roads;
  final int? positive, negative;
  Map<String, dynamic> toJson() => {
    'code': code,
    'point': point.toJson(),
    'name': name,
    'roads': roads.toList(),
    'positive': positive,
    'negative': negative,
  };
}

class TmcTable {
  TmcTable(
    this.version,
    this.nodes, {
    required this.sha256sum,
    this.publication,
  });
  final String version, sha256sum;
  final Map<int, TmcNode> nodes;
  final String? publication;
  Map<String, dynamic> toJson() => {
    'schema': 1,
    'country': '4',
    'table': '9',
    'version': version,
    'sha256': sha256sum,
    'publication': publication,
    'nodes': [for (final n in nodes.values) n.toJson()],
  };
  factory TmcTable.fromJson(Map<String, dynamic> data) {
    if (data['schema'] != 1 ||
        data['country'] != '4' ||
        data['table'] != '9' ||
        data['version'] is! String ||
        !RegExp(r'^7\.\d{1,2}$').hasMatch(data['version']) ||
        data['sha256'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(data['sha256']) ||
        data['nodes'] is! List ||
        (data['nodes'] as List).isEmpty ||
        (data['nodes'] as List).length > 50000) {
      throw const FormatException('Ungültiger TMC-Index');
    }
    final nodes = <int, TmcNode>{};
    for (final raw in data['nodes']) {
      if (raw is! Map ||
          raw['code'] is! int ||
          raw['code'] < 1 ||
          raw['code'] > 63487 ||
          raw['name'] is! String ||
          raw['name'].length > 200 ||
          raw['roads'] is! List ||
          raw['roads'].length > 8 ||
          raw['roads'].any(
            (v) => v is! String || roadReferences(v).length != 1,
          ) ||
          [
            raw['positive'],
            raw['negative'],
          ].any((v) => v != null && (v is! int || v < 1 || v > 63487))) {
        throw const FormatException('Ungültiger TMC-Ort');
      }
      final p = MobilityPoint.fromJson(raw['point']);
      if (p.latitude < 45.5 ||
          p.latitude > 48.5 ||
          p.longitude < 5.5 ||
          p.longitude > 11 ||
          nodes.containsKey(raw['code'])) {
        throw const FormatException('Ungültige / doppelte TMC-Koordinate');
      }
      final n = TmcNode(
        raw['code'],
        p,
        raw['name'],
        Set<String>.unmodifiable((raw['roads'] as List).cast<String>()),
        raw['positive'],
        raw['negative'],
      );
      nodes[n.code] = n;
    }
    return TmcTable(
      data['version'],
      Map.unmodifiable(nodes),
      sha256sum: data['sha256'],
      publication: data['publication'] as String?,
    );
  }

  /// Returns source anchors, not an invented road polyline. Offsets are applied
  /// only after matching an ordered chain to actual OSRM road geometry.
  Map<String, dynamic> resolve(Map reference) {
    Map<String, dynamic> fail(String reason) => {
      'status': 'unresolved',
      'reason': reason,
      'version': version,
    };
    if (reference['unsupported'] != null) {
      return fail('${reference['unsupported']}');
    }
    if (reference['country'] != '4' ||
        reference['table'] != '9' ||
        reference['version'] != version) {
      return fail('TMC-Land, Tabelle oder Version passt nicht');
    }
    if (!{'2', '4'}.contains(reference['method']) ||
        !{'positive', 'negative', 'both'}.contains(reference['direction'])) {
      return fail('TMC-Methode oder Richtung unbekannt');
    }
    final primary = reference['primary'], secondary = reference['secondary'];
    bool valid(Object? p) =>
        p is Map &&
        p['code'] is int &&
        nodes.containsKey(p['code']) &&
        p['offsetMeters'] is num &&
        (p['offsetMeters'] as num).isFinite &&
        p['offsetMeters'] >= 0 &&
        p['offsetMeters'] <= 50000;
    if (!valid(primary) || reference['linear'] == true && !valid(secondary)) {
      return fail('TMC-Punkt oder Offset fehlt / unbekannt');
    }
    final end = nodes[primary['code']]!;
    final forward = reference['direction'] != 'negative';
    final path = <TmcNode>[end];
    final seen = <int>{end.code};
    var current = end, length = 0.0;
    final target = reference['linear'] == true ? secondary['code'] : null;
    final offset = (primary['offsetMeters'] as num).toDouble();
    // With no offsets, a both-directions section has the same extent whichever
    // endpoint is supplied first. Require one unambiguous, reciprocal chain.
    if (reference['linear'] == true &&
        reference['direction'] == 'both' &&
        offset == 0 &&
        secondary['offsetMeters'] == 0 &&
        target != end.code) {
      List<TmcNode>? walk(bool positive) {
        final result = <TmcNode>[end], visited = <int>{end.code};
        var node = end, distance = 0.0;
        var refs = Set<String>.from(end.roads);
        while (node.code != target) {
          final next = nodes[positive ? node.positive : node.negative];
          if (next == null ||
              !visited.add(next.code) ||
              result.length >= 512 ||
              (positive ? next.negative : next.positive) != node.code) {
            return null;
          }
          refs = refs.intersection(next.roads);
          if (refs.isEmpty) return null;
          distance += _distance(node.point, next.point);
          if (distance > 200000) return null;
          result.add(next);
          node = next;
        }
        return result;
      }

      final a = walk(true), b = walk(false);
      if ((a == null) == (b == null)) {
        return {
          'status': 'reference',
          'reason': 'TMC-Abschnitt nicht eindeutig verbunden',
          'version': version,
          'point': end.point.toJson(),
          'name': end.name,
        };
      }
      path
        ..clear()
        ..addAll(a ?? b!);
      current = path.last;
    }
    while (target != null
        ? current.code != target
        : path.length < 2 || length < offset) {
      final code = forward ? current.negative : current.positive;
      final previous = nodes[code];
      if (previous == null ||
          !seen.add(previous.code) ||
          path.length >= 512 ||
          (forward ? previous.positive : previous.negative) != current.code) {
        return {
          'status': 'reference',
          'reason': 'TMC-Kette unvollständig oder widersprüchlich',
          'version': version,
          'point': end.point.toJson(),
          'name': end.name,
        };
      }
      length += _distance(previous.point, current.point);
      path.add(previous);
      current = previous;
      if (length > 200000) {
        return {
          'status': 'reference',
          'reason': 'TMC-Abschnitt zu groß',
          'version': version,
          'point': end.point.toJson(),
          'name': end.name,
        };
      }
    }
    final ordered = path.reversed.toList();
    var roads = Set<String>.from(ordered.first.roads);
    for (final p in ordered.skip(1)) {
      roads = roads.intersection(p.roads);
    }
    if (roads.isEmpty) {
      return {
        'status': 'reference',
        'reason': 'Kein durchgängiger eindeutiger Straßenbezug',
        'version': version,
        'point': end.point.toJson(),
        'name': end.name,
      };
    }
    return {
      'status': 'resolved',
      'version': version,
      'roadNumbers': roads.toList(),
      'anchors': [for (final p in ordered) p.point.toJson()],
      'codes': [for (final p in ordered) p.code],
      'primaryOffset': offset,
      'secondaryOffset': reference['linear'] == true
          ? secondary['offsetMeters']
          : null,
      'linear': reference['linear'] == true,
      'both': reference['direction'] == 'both',
      'name': '${roads.join(" / ")} · ${ordered.first.name} → ${end.name}',
      'point': end.point.toJson(),
      'tableSha256': sha256sum,
    };
  }
}

double _distance(MobilityPoint a, MobilityPoint b) {
  final x =
          (a.longitude - b.longitude) *
          111195 *
          math.cos((a.latitude + b.latitude) * math.pi / 360),
      y = (a.latitude - b.latitude) * 111195;
  return math.sqrt(x * x + y * y);
}

TmcTable importTmcTable(Uint8List bytes) {
  final files = readTmcArchive(bytes);
  final readme = latin1.decode(files['README.DAT']!).trim().split(';');
  if (readme.length < 5) {
    throw const FormatException('TMC-Zeichencodierung fehlt');
  }
  final encoding = readme[4].trim().toUpperCase();
  String text(String file) => switch (encoding) {
    'UTF-8' || 'UTF8' => utf8.decode(files[file]!),
    'ISO-8859-1' || 'LATIN1' || 'LATIN-1' => latin1.decode(files[file]!),
    _ => throw const FormatException('Nicht unterstützte TMC-Zeichencodierung'),
  };
  List<Map<String, String>> rows(String file, List<String> required) {
    final lines = const LineSplitter().convert(text(file));
    if (lines.isEmpty || lines.length > 60000) {
      throw const FormatException('TMC-Zeilenlimit');
    }
    final header = _fields(lines.first);
    if (header.toSet().length != header.length ||
        !header.toSet().containsAll(required)) {
      throw FormatException('TMC-Spalten fehlen: $file');
    }
    final result = <Map<String, String>>[];
    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final cells = _fields(line);
      if (cells.length != header.length) {
        throw FormatException('TMC-Spaltenzahl ungültig: $file');
      }
      result.add({for (var i = 0; i < header.length; i++) header[i]: cells[i]});
    }
    return result;
  }

  final metadata = rows('LOCATIONDATASETS.DAT', ['CID', 'TABCD', 'VERSION']);
  if (metadata.length != 1 ||
      metadata.single['CID'] != '51' ||
      metadata.single['TABCD'] != '9' ||
      !RegExp(r'^7\.\d{1,2}$').hasMatch(metadata.single['VERSION']!)) {
    throw const FormatException('Keine unterstützte Schweizer TMC-Tabelle');
  }
  final version = metadata.single['VERSION']!;
  int code(String? s) {
    final v = int.tryParse(s ?? '');
    if (v == null || v < 1 || v > 63487) {
      throw const FormatException('Ungültiger TMC-Code');
    }
    return v;
  }

  void country(Map row) {
    if (row['CID'] != '51' || row['TABCD'] != '9') {
      throw const FormatException('Gemischte TMC-Tabellen');
    }
  }

  final names = <String, String>{};
  for (final row in rows('NAMES.DAT', ['CID', 'NID', 'NAME'])) {
    if (row['CID'] != '51') {
      throw const FormatException('TMC-Länderkennung ungültig');
    }
    final name = row['NAME']!;
    if (name.length > 200 || names.containsKey(row['NID'])) {
      throw const FormatException('Ungültiger TMC-Name');
    }
    names[row['NID']!] = name;
  }
  final roads = <String, Set<String>>{};
  final links = <String, String>{};
  for (final file in ['ROADS.DAT', 'SEGMENTS.DAT']) {
    for (final row in rows(file, ['CID', 'TABCD', 'LCD', 'ROADNUMBER'])) {
      country(row);
      final id = code(row['LCD']).toString();
      if (roads.containsKey(id)) {
        throw const FormatException('Doppelter TMC-Straßencode');
      }
      roads[id] = roadReferences(row['ROADNUMBER']!);
      links[id] = row['ROA_LCD'] ?? '';
    }
  }
  Set<String> roadFor(Map row) {
    final refs = <String>{};
    for (final field in ['ROA_LCD', 'SEG_LCD']) {
      var id = row[field] ?? '';
      final visited = <String>{};
      for (var i = 0; id.isNotEmpty && i < 8 && visited.add(id); i++) {
        refs.addAll(roads[id] ?? {});
        id = links[id] ?? '';
      }
    }
    return refs;
  }

  final offsets = <int, (int?, int?)>{};
  for (final row in rows('POFFSETS.DAT', [
    'CID',
    'TABCD',
    'LCD',
    'NEG_OFF_LCD',
    'POS_OFF_LCD',
  ])) {
    country(row);
    final id = code(row['LCD']);
    if (offsets.containsKey(id)) {
      throw const FormatException('Doppelte TMC-Verknüpfung');
    }
    offsets[id] = (
      row['POS_OFF_LCD']!.isEmpty ? null : code(row['POS_OFF_LCD']),
      row['NEG_OFF_LCD']!.isEmpty ? null : code(row['NEG_OFF_LCD']),
    );
  }
  final nodes = <int, TmcNode>{};
  for (final row in rows('POINTS.DAT', [
    'CID',
    'TABCD',
    'LCD',
    'XCOORD',
    'YCOORD',
    'N1ID',
    'N2ID',
    'ROA_LCD',
    'SEG_LCD',
  ])) {
    country(row);
    final id = code(row['LCD']);
    final x = int.tryParse(row['XCOORD']!), y = int.tryParse(row['YCOORD']!);
    if (x == null || y == null || nodes.containsKey(id)) {
      throw const FormatException('Ungültiger / doppelter TMC-Punkt');
    }
    final point = MobilityPoint(y / 100000, x / 100000);
    if (point.latitude < 45.5 ||
        point.latitude > 48.5 ||
        point.longitude < 5.5 ||
        point.longitude > 11) {
      throw const FormatException(
        'TMC-Koordinate außerhalb des unterstützten Gebiets',
      );
    }
    final labels = [
      names[row['N1ID']],
      names[row['N2ID']],
    ].whereType<String>().where((n) => n.isNotEmpty).toSet().join(' / ');
    final o = offsets[id];
    nodes[id] = TmcNode(
      id,
      point,
      labels.isEmpty ? 'TMC $id' : labels,
      roadFor(row),
      o?.$1,
      o?.$2,
    );
  }
  if (nodes.isEmpty ||
      nodes.length > 50000 ||
      offsets.keys.any((k) => !nodes.containsKey(k))) {
    throw const FormatException('Ungültiger TMC-Punktindex');
  }
  return TmcTable.fromJson(
    TmcTable(
      version,
      nodes,
      sha256sum: sha256.convert(bytes).toString(),
      publication: readme.length > 1 ? readme[1] : null,
    ).toJson(),
  );
}

List<String> _fields(String line) {
  if (line.length > 8192) throw const FormatException('TMC-Zeile zu lang');
  final fields = <String>[];
  final value = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      if (quoted && i + 1 < line.length && line[i + 1] == '"') {
        value.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (c == ';' && !quoted) {
      fields.add(value.toString().trim());
      value.clear();
    } else {
      value.write(c);
    }
  }
  if (quoted) throw const FormatException('Ungültige TMC-Zeichenkette');
  fields.add(value.toString().trim());
  return fields;
}
