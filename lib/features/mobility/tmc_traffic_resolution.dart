import 'tmc_table.dart';

class TmcTrafficInput {
  const TmcTrafficInput(this.data, this.tables, this.provenance);
  final Map<String, dynamic> data;
  final Map<String, TmcTable> tables;
  final Map<String, Map<String, dynamic>> provenance;
}

Set<String> neededTmcVersions(Map<String, dynamic> data) {
  final versions = <String>{};
  for (final record in (data['records'] as List? ?? const []).take(20000)) {
    if (record is! Map) continue;
    for (final part in (record['routingEvidence'] as List? ?? const []).take(
      32,
    )) {
      final ref = part is Map ? part['tmc'] : null;
      if (ref is Map &&
          ref['country'] == '4' &&
          ref['table'] == '9' &&
          ref['version'] is String &&
          RegExp(r'^7\.\d{1,2}$').hasMatch(ref['version'])) {
        versions.add(ref['version']);
      }
    }
  }
  return versions;
}

Map<String, dynamic> resolveTrafficTmc(TmcTrafficInput input) {
  final output = <Map<String, dynamic>>[];
  var resolved = 0, unknown = 0, vertices = 0, work = 0;
  var incomplete = false;
  for (final record in (input.data['records'] as List? ?? const []).take(
    20000,
  )) {
    final raw = Map<String, dynamic>.from(record as Map);
    final parts = <Map<String, dynamic>>[];
    final descriptions = <String>{};
    Map? display;
    for (final original in (raw['routingEvidence'] as List? ?? const []).take(
      32,
    )) {
      final part = Map<String, dynamic>.from(original as Map);
      final ref = part['tmc'];
      if (ref is Map) {
        final version = ref['version'];
        final table = input.tables[version];
        var result = work >= 250000
            ? <String, dynamic>{
                'status': 'unresolved',
                'reason': 'TMC-Verarbeitungslimit erreicht',
                'version': version,
              }
            : table?.resolve(ref) ??
                  {
                    'status': 'unresolved',
                    'version': version,
                    'reason':
                        ref['unsupported'] ??
                        (ref['country'] != '4' || ref['table'] != '9'
                            ? 'TMC-Land oder Tabelle fehlt / nicht unterstützt'
                            : 'Passende TMC-Tabelle $version fehlt'),
                  };
        if (work >= 250000) incomplete = true;
        if (table != null) work += (result['anchors'] as List?)?.length ?? 512;
        final count = (result['anchors'] as List?)?.length ?? 0;
        if (vertices + count > 100000) {
          incomplete = true;
          result = {
            'status': 'unresolved',
            'reason': 'TMC-Geometrielimit erreicht',
            'version': version,
          };
        } else {
          vertices += count;
        }
        final meta = input.provenance[version];
        part['tmcResolved'] = {
          ...result,
          'sourceVerified': meta?['verified'] == true,
          'retrievedUtc': meta?['retrievedUtc'],
          'publication': meta?['publication'],
        };
        if (result['status'] == 'resolved') {
          resolved++;
          descriptions.add(
            '${result['name']} · TMC $version${meta?['verified'] == true ? "" : " · Dateiimport, nicht online bestätigt"}',
          );
          display ??= result;
        } else {
          unknown++;
          descriptions.add('${result['reason']}');
          if (result['point'] != null) display ??= result;
        }
      }
      parts.add(part);
    }
    raw['routingEvidence'] = parts;
    if (descriptions.isNotEmpty) {
      raw['tmcStatus'] = descriptions.take(8).join('\n');
      if ((raw['geometry'] == null ||
              raw['geometryAccuracy'] == 'displayReference') &&
          display != null) {
        final anchors = display['anchors'] as List?;
        final zeroOffsets =
            display['primaryOffset'] == 0 &&
            (display['secondaryOffset'] ?? 0) == 0;
        final line =
            display['linear'] == true && anchors != null && zeroOffsets;
        raw['geometry'] = {
          'type': line ? 'LineString' : 'Point',
          'coordinates': line ? anchors : display['point'],
        };
        raw['geometryAccuracy'] = line ? 'tmcAnchors' : 'tmcReference';
      }
      raw['detail'] =
          '${raw['detail'] ?? raw['description'] ?? ""}\nTMC: ${raw['tmcStatus']}\nTMC-Anker zeigen den Tabellenbezug; gerade Verbindungen sind kein genauer Straßenverlauf. Offsets werden erst entlang einer eindeutig zugeordneten Route angewendet.';
    }
    output.add(raw);
  }
  final positioned = output.where((r) => r['geometry'] != null).toList();
  final unlocated = output.where((r) => r['geometry'] == null).toList();
  return {
    ...input.data,
    'records': output,
    'features': positioned,
    'unlocatedRecords': unlocated,
    'unlocated': unlocated.length,
    'tmcResolved': resolved,
    'tmcUnresolved': unknown,
    'tmcResolutionIncomplete': incomplete,
    'coverage': 'ASTRA / VMZ-CH · TMC-Versionen werden getrennt aufgelöst. Ankerverbindungen sind keine exakten Straßenverläufe. Hauptstraßennetz; keine vollständige Verkehrsabdeckung.',
  };
}
