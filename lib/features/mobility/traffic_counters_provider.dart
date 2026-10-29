import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

import '../../core/osint/api_access_policy.dart';
import '../../core/osint/cached_osint_provider.dart';
import '../../core/osint/osint_dataset.dart';
import '../../core/osint/osint_provider_state.dart';
import '../../core/osint/osint_source.dart';
import 'road_routing.dart';
import 'traffic_snapshot.dart' show readDatexEvents, trafficMaxResponseBytes;

final astraCountersAccess = ApiAccessPolicy(
  id: 'astra-traffic-counters',
  name: 'ASTRA Traffic Counters',
  access: ApiAccessClass.verifiedFreeKey,
  registrationUri: Uri.parse('https://api-manager.opentransportdata.swiss/'),
);

Iterable<XmlElement> _nodes(XmlNode node, String name) =>
    node.descendants.whereType<XmlElement>().where((e) => e.name.local == name);
String? _value(XmlNode node, String name) =>
    _nodes(node, name).firstOrNull?.innerText.trim();
String _attr(String name, String value) =>
    XmlAttribute(XmlName.parts(name), value).toXmlString();
String _short(String? value, [int max = 160]) =>
    (value ?? '').substring(0, (value ?? '').length.clamp(0, max));
DateTime? _time(String? value) =>
    value != null && RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value)
    ? DateTime.tryParse(value)?.toUtc()
    : null;

/// Uses the same bounded XML transport as situation messages. Only one source
/// record is built at a time; namespace resources and external entities are not fetched.
Future<Map<String, dynamic>> parseCounterPublication(
  Stream<List<int>> bytes, {
  required bool table,
}) async {
  final records = <Map<String, dynamic>>[], stack = <String>[];
  List<XmlEvent>? buffer;
  String? recordName, tableId, tableVersion, publication;
  var count = 0, size = 0;
  bool supported = false;
  await readDatexEvents(bytes, (event) {
    if (event is XmlDoctypeEvent) {
      throw const FormatException('DATEX document types are unsupported');
    }
    if (event is XmlStartElementEvent) {
      final name = event.name.split(':').last;
      if (name == 'Fault') {
        throw const FormatException('ASTRA returned a SOAP fault');
      }
      if (stack.length >= 64) {
        throw const FormatException('DATEX nesting limit exceeded');
      }
      if (name ==
          (table ? 'measurementSiteTable' : 'measurementSiteTableReference')) {
        tableId = event.attributes
            .where((a) => a.name == 'id')
            .firstOrNull
            ?.value;
        tableVersion = event.attributes
            .where((a) => a.name == 'version')
            .firstOrNull
            ?.value;
      }
      if (name == (table ? 'measurementSiteTable' : 'siteMeasurements') ||
          event.attributes.any(
            (a) =>
                a.name.split(':').last == 'type' &&
                a.value.split(':').last ==
                    (table
                        ? 'MeasurementSiteTablePublication'
                        : 'MeasuredDataPublication'),
          )) {
        supported = true;
      }
      if (name == 'publicationTime') publication = '';
      if (name == (table ? 'measurementSiteRecord' : 'siteMeasurements')) {
        if (buffer != null || ++count > 20000) {
          throw const FormatException('Too many counter records');
        }
        buffer = [];
        recordName = name;
        size = 0;
      }
      if (!event.isSelfClosing) stack.add(name);
    }
    if (stack.lastOrNull == 'publicationTime' && event is XmlTextEvent) {
      publication = (publication ?? '') + event.value;
      if (publication!.length > 100) {
        throw const FormatException('Invalid source time');
      }
    }
    if (buffer != null) {
      size += event.stop! - event.start!;
      if (size > 256 * 1024 || buffer!.length >= 10000) {
        throw const FormatException('Counter record too large');
      }
      buffer!.add(event);
      if ((event is XmlEndElementEvent && stack.lastOrNull == recordName) ||
          (event is XmlStartElementEvent &&
              event.isSelfClosing &&
              event.name.split(':').last == recordName)) {
        final node =
            const XmlNodeDecoder().convert(buffer!).single as XmlElement;
        records.add(table ? _parseSite(node) : _parseValues(node));
        buffer = null;
        recordName = null;
      }
    }
    if (event is XmlEndElementEvent) stack.removeLast();
  });
  if (!supported ||
      tableId == null ||
      tableVersion == null ||
      buffer != null ||
      stack.isNotEmpty) {
    throw const FormatException('Unsupported counter publication');
  }
  return {
    'records': records,
    'tableId': _short(tableId),
    'tableVersion': _short(tableVersion, 30),
    'publishedAtUtc': _time(publication)?.toIso8601String(),
  };
}

Map<String, dynamic> _parseSite(XmlElement node) {
  final id = _short(node.getAttribute('id'));
  final coordinate = _nodes(node, 'pointCoordinates').firstOrNull;
  List<double>? point;
  if (coordinate != null) {
    final lat = double.tryParse(_value(coordinate, 'latitude') ?? ''),
        lon = double.tryParse(_value(coordinate, 'longitude') ?? '');
    if (lat != null && lon != null) {
      try {
        point = MobilityPoint(lat, lon).toJson();
      } on FormatException {
        /* Unlocated site. */
      }
    }
  }
  final characteristics = <String, dynamic>{};
  for (final item in _nodes(node, 'measurementSpecificCharacteristics')) {
    final index = item.getAttribute('index');
    if (index == null) continue;
    characteristics[_short(index, 20)] = {
      'type': _short(_value(item, 'specificMeasurementValueType'), 60),
      'vehicle': _short(_value(item, 'vehicleType'), 60),
      'periodSeconds': double.tryParse(_value(item, 'period') ?? ''),
    };
    if (characteristics.length > 100) {
      throw const FormatException('Too many measurement definitions');
    }
  }
  return {
    'id': id,
    'version': _short(node.getAttribute('version'), 30),
    'coordinates': point,
    'name': _short(_value(node, 'measurementSiteName') ?? id),
    'lane': _short(_value(node, 'lane'), 60),
    'carriageway': _short(_value(node, 'carriageway'), 60),
    'roadNumbers': _nodes(
      node,
      'roadNumber',
    ).map((e) => _short(e.innerText, 80)).toSet().take(8).toList(),
    'directionBound': _short(
      _value(node, 'directionBound') ??
          _value(node, 'directionBoundAtPoint') ??
          _value(node, 'directionBoundOnLinearSection'),
      60,
    ),
    'directionCode': _short(_value(node, 'alertCDirectionCoded'), 60),
    'characteristics': characteristics,
  };
}

Map<String, dynamic> _parseValues(XmlElement node) {
  final reference = _nodes(node, 'measurementSiteReference').firstOrNull;
  final values = <Map<String, dynamic>>[];
  for (final item in _nodes(node, 'measuredValue')) {
    final index = item.getAttribute('index');
    if (index == null) continue;
    final basic = _nodes(item, 'basicData').firstOrNull;
    final speed = _nodes(item, 'speed').firstOrNull,
        flow = _nodes(item, 'vehicleFlowRate').firstOrNull;
    final value = double.tryParse((speed ?? flow)?.innerText.trim() ?? '');
    final error =
        _nodes(item, 'dataError').isNotEmpty ||
        _nodes(item, 'dataErrorCode').isNotEmpty ||
        _nodes(item, 'fault').isNotEmpty ||
        _nodes(item, 'reasonForDataBeingIncomplete').isNotEmpty;
    final unit = (speed ?? flow)?.attributes
        .where((a) => a.name.local == 'type')
        .firstOrNull
        ?.value
        .split(':')
        .last;
    values.add({
      'index': _short(index, 20),
      'kind': speed != null
          ? 'trafficSpeed'
          : flow != null
          ? 'trafficFlow'
          : 'unsupported',
      'unit': unit,
      'value': !error && value != null && value.isFinite && value >= 0
          ? value
          : null,
      'error': error,
      'timeUtc': _time(_value(item, 'time'))?.toIso8601String(),
      'sourceType': _short(
        basic?.attributes
            .where((a) => a.name.local == 'type')
            .firstOrNull
            ?.value,
        60,
      ),
    });
    if (values.length > 100) {
      throw const FormatException('Too many measured values');
    }
  }
  return {
    'id': _short(reference?.getAttribute('id')),
    'version': _short(reference?.getAttribute('version'), 30),
    'timeUtc': _time(_value(node, 'measurementTimeDefault'))?.toIso8601String(),
    'values': values,
  };
}

class TrafficCountersProvider
    extends CachedOsintProvider<Map<String, dynamic>> {
  TrafficCountersProvider({
    required this.center,
    required this.readKey,
    http.Client? client,
    super.now,
  }) : transport = MobilityHttp(client: client),
       super(cacheDuration: const Duration(minutes: 1));
  final MobilityPoint center;
  final Future<String?> Function() readKey;
  final MobilityHttp transport;
  Map<String, dynamic>? _table;
  DateTime? _tableAt, _attempt;
  bool get canRefresh =>
      _attempt == null ||
      nowUtc.difference(_attempt!) >= const Duration(minutes: 1);
  static const endpoint =
      'https://api.opentransportdata.swiss/TDP/Soap_Datex2/Pull';
  @override
  OsintSource get source => OsintSource(
    id: 'astra-traffic-counters',
    name: 'ASTRA Verkehrszählstellen',
    publisher: 'ASTRA / VDP',
    dataUri: Uri.parse(endpoint),
    metadataUri: Uri.parse(
      'https://opentransportdata.swiss/en/cookbook/road-traffic-cookbook/rt-road-traffic-counters/',
    ),
    licenseName: 'ASTRA VDP terms; own registered access',
    licenseUri: Uri.parse('https://opentransportdata.swiss/de/tac-fedro/'),
    attribution: 'Datenquelle: Verkehrsdaten-Plattform (VDP) ASTRA',
    coordinateReference: 'EPSG:4326',
  );
  Future<Map<String, dynamic>> _pull(
    String operation,
    String key, {
    List<String> ids = const [],
    String? tableId,
  }) => transport.read(
    Uri.parse(endpoint),
    maxBytes: trafficMaxResponseBytes,
    timeout: const Duration(seconds: 60),
    consume: (bytes) => parseCounterPublication(
      bytes,
      table: operation == 'pullMeasurementSiteTable',
    ),
    headers: {
      'Authorization': key.startsWith('Bearer ') ? key : 'Bearer $key',
      'Content-Type': 'text/xml; charset=utf-8',
      'SOAPAction':
          'http://opentransportdata.swiss/TDP/Soap_Datex2/Pull/v1/$operation',
    },
    body:
        '<?xml version="1.0" encoding="UTF-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body><d2LogicalModel modelBaseVersion="2" xmlns="http://datex2.eu/schema/2/2_0"><exchange><supplierIdentification><country>ch</country><nationalIdentifier>FPVManager</nationalIdentifier></supplierIdentification></exchange>${ids.isEmpty ? '' : '<payloadPublication xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="GenericPublication" lang="en"><publicationTime>${nowUtc.toIso8601String()}</publicationTime><publicationCreator><country>ch</country><nationalIdentifier>FPVManager</nationalIdentifier></publicationCreator><genericPublicationName>MeasuredDataFilter</genericPublicationName><genericPublicationExtension><measuredDataFilter><measurementSiteTableReference targetClass="MeasurementSiteTable" ${_attr('id', tableId ?? 'OTD:TrafficData')} version="0"/>${ids.map((id) => '<siteRequestReference targetClass="MeasurementSiteRecord" ${_attr('id', RegExp.escape(id))} version="0"/>').join()}</measuredDataFilter></genericPublicationExtension></payloadPublication>'}</d2LogicalModel></soap:Body></soap:Envelope>',
  );

  List<Map<String, dynamic>> _sites(Map<String, dynamic> table) {
    final ranked = <({Map<String, dynamic> site, double distance})>[];
    for (final raw in table['records'] as List) {
      final site = Map<String, dynamic>.from(raw as Map),
          point = raw['coordinates'];
      if (point is! List || (site['id'] as String).isEmpty) continue;
      final dx =
              (((point[0] as num) - center.longitude + 540) % 360 - 180) *
              math.cos(center.latitude * math.pi / 180) *
              111195,
          dy = ((point[1] as num) - center.latitude) * 111195;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance <= 30000) ranked.add((site: site, distance: distance));
    }
    ranked.sort((a, b) => a.distance.compareTo(b.distance));
    return ranked.take(100).map((r) => r.site).toList();
  }

  @override
  Future<OsintDataset<Map<String, dynamic>>> download() async {
    if (kIsWeb) {
      throw const FormatException(
        'Der ASTRA-Zählstellenzugang ist für direkte Browserabrufe nicht freigegeben. Android verwenden.',
      );
    }
    if (!canRefresh) {
      throw const FormatException(
        'Messwerte können einmal pro Minute aktualisiert werden.',
      );
    }
    final key = (await readKey())?.trim();
    if (key == null ||
        key.isEmpty ||
        key.length > 4096 ||
        key.contains(RegExp(r'[\r\n]'))) {
      throw const FormatException(
        'Den eigenen Token für Traffic Counters speichern.',
      );
    }
    _attempt = nowUtc;
    try {
      var table =
          _tableAt == null ||
              nowUtc.difference(_tableAt!) > const Duration(hours: 24)
          ? null
          : _table;
      table ??= await _pull('pullMeasurementSiteTable', key);
      final sites = _sites(table);
      if (sites.isEmpty) {
        throw const FormatException(
          'Keine verorteten Messstellen im gewählten 30-km-Umfeld.',
        );
      }
      final measured = await _pull(
        'pullMeasuredData',
        key,
        ids: sites.map((s) => s['id'] as String).toList(),
        tableId: table['tableId'] as String,
      );
      if (measured['tableId'] != table['tableId'] ||
          measured['tableVersion'] != table['tableVersion']) {
        table = await _pull('pullMeasurementSiteTable', key);
        if (measured['tableId'] != table['tableId'] ||
            measured['tableVersion'] != table['tableVersion']) {
          throw const FormatException(
            'Messdaten und Ortstabelle haben unterschiedliche Versionen. Letzter gültiger Stand bleibt erhalten.',
          );
        }
      }
      final byId = {for (final s in _sites(table)) s['id']: s};
      final features = <Map<String, dynamic>>[];
      var unknown = 0;
      for (final raw in measured['records'] as List) {
        final site = byId[raw['id']];
        if (site == null || raw['version'] != site['version']) {
          unknown++;
          continue;
        }
        final values = <Map<String, dynamic>>[];
        for (final item in raw['values'] as List) {
          final definition = site['characteristics'][item['index']];
          final supported =
              definition != null &&
              definition['type'] == item['kind'] &&
              (item['unit'] == null ||
                  item['unit'] ==
                      (item['kind'] == 'trafficSpeed'
                          ? 'KilometresPerHour'
                          : 'VehiclesPerHour'));
          values.add({
            ...Map<String, dynamic>.from(item as Map),
            'vehicle': supported ? definition['vehicle'] : 'unbekannt',
            'periodSeconds': supported ? definition['periodSeconds'] : null,
            'value': supported ? item['value'] : null,
          });
        }
        final lines = values
            .map(
              (v) =>
                  '${v['vehicle']}: ${v['value'] ?? "nicht verfügbar"} ${v['kind'] == 'trafficSpeed' ? 'km/h' : 'Fahrzeuge/h'}',
            )
            .join('\n');
        features.add({
          'id': site['id'],
          'name': site['name'],
          'detail': _short(
            'ASTRA / VDP · Messstelle ${site['id']}\nMesszeit: ${raw['timeUtc'] ?? "unbekannt"}\n$lines\nPunktuelle Messung; keine flächendeckende Verkehrslage.',
            1200,
          ),
          'timestampUtc': raw['timeUtc'],
          'values': values,
          'lane': site['lane'],
          'carriageway': site['carriageway'],
          'roadNumbers': site['roadNumbers'],
          'directionBound': site['directionBound'],
          'directionCode': site['directionCode'],
          'metadataVersionVerified': true,
          'geometry': {'type': 'Point', 'coordinates': site['coordinates']},
        });
      }
      if (features.isEmpty) {
        throw FormatException(
          unknown > 0
              ? 'Messwerte konnten keiner passenden Detektorversion zugeordnet werden. Letzter gültiger Stand bleibt erhalten.'
              : 'Die Quelle liefert derzeit keine Messwerte für die angefragten Detektoren. Letzter gültiger Stand bleibt erhalten.',
        );
      }
      _tableAt = identical(_table, table) ? _tableAt : nowUtc;
      _table = table;
      return OsintDataset(
        source: source,
        data: {
          'features': features,
          'unknown': unknown,
          'requested': sites.length,
          'tableVersion': table['tableVersion'],
          'center': [center.longitude, center.latitude],
          'radiusKm': 30,
        },
        fetchedAtUtc: nowUtc,
        publishedAtUtc: _time(measured['publishedAtUtc'] as String?),
        cacheExpiresAtUtc: nowUtc.add(cacheDuration),
        persistable: false,
      );
    } on MobilityHttpException catch (error) {
      throw OsintProviderException(
        providerId: id,
        kind: OsintFailureKind.http,
        httpStatus: error.statusCode,
        message: switch (error.statusCode) {
          401 || 403 =>
            'ASTRA Traffic Counters: HTTP ${error.statusCode}. Eigenen Zählstellen-Token und Freischaltung prüfen.',
          429 => 'ASTRA Traffic Counters: Abruflimit erreicht. Später erneut versuchen.',
          _ =>
            'ASTRA Traffic Counters: HTTP ${error.statusCode}. Quelle derzeit nicht verfügbar; später erneut versuchen.',
        },
      );
    } on http.ClientException {
      throw const FormatException(
        'ASTRA-Verkehrszähler derzeit nicht erreichbar.',
      );
    }
  }

  @override
  void dispose() {
    transport.dispose();
    super.dispose();
  }
}
