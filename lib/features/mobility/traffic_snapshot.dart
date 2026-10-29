import 'dart:convert';

import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

import 'road_routing.dart';
import 'traffic_incident.dart';
import 'tmc_reference.dart';

Map<String, dynamic> parseTrafficSnapshot(String input) =>
    readTrafficSnapshot(input).data();
Future<Map<String, dynamic>> parseTrafficStream(
  Stream<List<int>> bytes,
) async => (await readTrafficStream(bytes)).data();

class TrafficSnapshot {
  TrafficSnapshot(
    this.updates, {
    this.publicationTime,
    this.omitted = 0,
    this.sourceRecords = 0,
  });
  final Map<String, Map<String, dynamic>> updates;
  final DateTime? publicationTime;
  final int omitted, sourceRecords;
  TrafficSnapshot merge(TrafficSnapshot patch) {
    final merged = {...updates};
    for (final entry in patch.updates.entries) {
      final old = DateTime.tryParse(
        merged[entry.key]?['timestampUtc'] as String? ?? '',
      );
      final next = DateTime.tryParse(
        entry.value['timestampUtc'] as String? ?? '',
      );
      if (old != null && next != null && next.isBefore(old)) continue;
      merged[entry.key] = entry.value;
    }
    if (merged.length > 20000) {
      throw const FormatException(
        'Traffic session limit exceeded; a new full snapshot is required',
      );
    }
    return TrafficSnapshot(
      merged,
      publicationTime: patch.publicationTime ?? publicationTime,
      omitted: omitted + patch.omitted,
      sourceRecords: sourceRecords,
    );
  }

  Map<String, dynamic> data() {
    final records = updates.values
        .where((r) => r['withdrawn'] != true)
        .toList();
    final positioned = records.where((r) => r['geometry'] != null).toList();
    final unlocated = records.where((r) => r['geometry'] == null).toList();
    return {
      'features': positioned,
      'records': records,
      'unlocated': unlocated.length,
      'unlocatedRecords': unlocated,
      'publishedAtUtc': publicationTime?.toIso8601String(),
      'omitted': omitted,
      'sourceRecords': sourceRecords,
      'coverage': 'ASTRA / VMZ-CH · veröffentlichte Verkehrsmeldungen. TMC-Ortscodes ohne passende Ortstabelle bleiben ohne Kartenposition. Keine vollständige Abdeckung aller Straßen.',
    };
  }
}

class TrafficRecord {
  TrafficRecord(XmlElement node) {
    id = node.getAttribute('id') ?? '';
    updated = _utc(_value(node, 'situationRecordVersionTime'));
    from = _utc(_value(node, 'overallStartTime'));
    until = _utc(_value(node, 'overallEndTime'));
    type =
        node.attributes
            .where((a) => a.name.local == 'type')
            .firstOrNull
            ?.value
            .split(':')
            .last ??
        '';
    final comments = <String>[];
    for (final comment in _elements(node, 'generalPublicComment')) {
      final values = _elements(comment, 'value').toList();
      int rank(XmlElement e) {
        final language = (e.getAttribute('lang') ?? '').toLowerCase();
        return language.startsWith('de')
            ? 0
            : language.startsWith('en')
            ? 1
            : language.isEmpty
            ? 2
            : 3;
      }

      values.sort((a, b) => rank(a).compareTo(rank(b)));
      if (values.isNotEmpty) {
        comments.add(_text(values.first.innerText.trim(), 1000));
      }
      if (values.any(
        (v) => RegExp(
          r'^(Aufgehoben|Révoqué|Revocato|Revoked):',
          caseSensitive: false,
        ).hasMatch(v.innerText.trim()),
      )) {
        revoked = true;
      }
    }
    description = _text(comments.toSet().take(3).join(' · '), 1000);
    revoked =
        revoked ||
        _elements(
          node,
          'validityStatus',
        ).any((e) => e.innerText.toLowerCase().contains('revoked')) ||
        _elements(node, 'lifeCycleManagement').any(
          (e) => _elements(e, 'cancel').any(
            (v) => {'true', '1'}.contains(v.innerText.trim().toLowerCase()),
          ),
        );
    validityStatus = (_value(node, 'validityStatus') ?? '').trim();
    suspended = validityStatus == 'suspended';
    recurring =
        _elements(node, 'validPeriod').isNotEmpty ||
        _elements(node, 'exceptionPeriod').isNotEmpty;
    final coded = [
      type,
      ...[
        'abnormalTrafficType',
        'accidentType',
        'roadMaintenanceType',
        'roadOrCarriagewayOrLaneManagementType',
        'poorEnvironmentType',
        'environmentalObstructionType',
        'vehicleObstructionType',
        'generalObstructionType',
      ].expand((n) => _elements(node, n).map((e) => e.innerText)),
    ].join(' ').toLowerCase();
    category =
        coded.contains('roadclosed') ||
            coded.contains('carriagewayclosures') ||
            coded.contains('roadclosure')
        ? TrafficCategory.closure
        : coded.contains('accident')
        ? TrafficCategory.accident
        : [
            'queuingtraffic',
            'stationarytraffic',
            'slowtraffic',
            'trafficcongestion',
          ].any(coded.contains)
        ? TrafficCategory.congestion
        : coded.contains('roadworks') || coded.contains('maintenance')
        ? TrafficCategory.roadworks
        : coded.contains('weather') ||
              coded.contains('poorenv') ||
              coded.contains('winter')
        ? TrafficCategory.weather
        : coded.contains('obstruction')
        ? TrafficCategory.hazard
        : TrafficCategory.other;
    for (final field in [
      'queueLength',
      'delayTimeValue',
      'numberOfLanesRestricted',
      'speedLimit',
    ]) {
      final value = double.tryParse(_value(node, field) ?? '');
      if (value != null && value.isFinite && value >= 0 && value <= 1e9) {
        metrics[field] = value;
      }
    }
    tmcVersion = _text(_value(node, 'alertCLocationTableVersion'), 30);
    tmcCodes = _elements(
      node,
      'specificLocation',
    ).map((e) => _text(e.innerText, 30)).toSet().take(8).toList();
    direction = _text(_value(node, 'alertCDirectionCoded'), 60).trim();
    tmcReference = readTmcReference(node);
    final location = _elements(node, 'groupOfLocations').firstOrNull;
    roadNumbers = location == null
        ? <String>[]
        : _elements(
            location,
            'roadNumber',
          ).map((e) => _text(e.innerText, 80)).toSet().take(8).toList();
    directionBound = location == null
        ? ''
        : _text(
            _value(location, 'directionBound') ??
                _value(location, 'directionBoundAtPoint') ??
                _value(location, 'directionBoundOnLinearSection'),
            60,
          );
    carriageway = location == null
        ? ''
        : _text(_value(location, 'carriageway'), 60);
    lane = location == null ? '' : _text(_value(location, 'lane'), 60);
    // Only source coordinates. An explicit display reference is a point,
    // not a reconstruction of a TMC road segment or its direction.
    for (final point in _elements(node, 'pointCoordinates').take(33)) {
      final lat = double.tryParse(_value(point, 'latitude') ?? ''),
          lon = double.tryParse(_value(point, 'longitude') ?? '');
      if (lat == null || lon == null) continue;
      try {
        coordinates.add(MobilityPoint(lat, lon).toJson());
      } on FormatException {
        /* Try remaining source positions. */
      }
    }
    if (coordinates.isEmpty) {
      for (final point in _elements(node, 'locationForDisplay').take(1)) {
        final lat = double.tryParse(_value(point, 'latitude') ?? ''),
            lon = double.tryParse(_value(point, 'longitude') ?? '');
        if (lat == null || lon == null) continue;
        try {
          coordinates.add(MobilityPoint(lat, lon).toJson());
          displayReference = true;
        } on FormatException {
          /* Unlocated. */
        }
      }
    }
  }
  late final String id,
      type,
      description,
      tmcVersion,
      direction,
      validityStatus;
  late final List<String> tmcCodes;
  late final List<String> roadNumbers;
  late final Map<String, dynamic>? tmcReference;
  late final String directionBound, carriageway, lane;
  late final DateTime? updated, from, until;
  late final TrafficCategory category;
  late final bool suspended, recurring;
  bool revoked = false, displayReference = false;
  final metrics = <String, dynamic>{};
  final coordinates = <List<double>>[];
}

class _TrafficAccumulator {
  final updates = <String, Map<String, dynamic>>{};
  DateTime? publicationTime;
  var omitted = 0, sourceRecords = 0;
  void addGroup(String? situationId, List<TrafficRecord> parts) {
    if (situationId == null) {
      for (final part in parts) {
        addGroup(part.id, [part]);
      }
      return;
    }
    if (situationId.isEmpty || situationId.length > 160) {
      omitted += parts.length;
      return;
    }
    sourceRecords += parts.length;
    if (parts.isEmpty) return;
    final newest = parts
        .map((p) => p.updated)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    final previous = _utc(updates[situationId]?['timestampUtc'] as String?);
    if (newest != null && previous != null && newest.isBefore(previous)) return;
    final primary =
        parts.where((p) => p.description.isNotEmpty).firstOrNull ?? parts.first;
    final category = parts
        .map((p) => p.category)
        .reduce((a, b) => a.index < b.index ? a : b);
    final position = parts
        .where((p) => p.coordinates.isNotEmpty && p.coordinates.length <= 32)
        .firstOrNull;
    final points = position?.coordinates ?? <List<double>>[];
    final description = parts
        .map((p) => p.description)
        .where((s) => s.isNotEmpty)
        .toSet()
        .take(3)
        .join(' · ');
    final metrics = <String, dynamic>{};
    for (final part in parts) {
      for (final entry in part.metrics.entries) {
        metrics.putIfAbsent(entry.key, () => entry.value);
      }
    }
    final tmc =
        parts.where((p) => p.tmcCodes.isNotEmpty).firstOrNull ?? primary;
    updates[situationId] = {
      'id': situationId,
      'name': _text(description.isEmpty ? category.label : description, 160),
      'description': _text(description, 1000),
      'category': category.name,
      'sourceTypes': parts.map((p) => p.type).toSet().take(16).toList(),
      'sourceRecordIds': parts.map((p) => _text(p.id, 160)).take(64).toList(),
      'parts': parts.length,
      'metrics': metrics,
      'timestampUtc': newest?.toIso8601String(),
      'validFromUtc': primary.from?.toIso8601String(),
      'validUntilUtc': primary.until?.toIso8601String(),
      'withdrawn': parts.any((p) => p.revoked),
      'suspended': primary.suspended,
      'validityStatus': primary.validityStatus,
      'recurring': parts.any((p) => p.recurring),
      'tmcVersion': tmc.tmcVersion,
      'tmcCodes': tmc.tmcCodes,
      'directionCode': tmc.direction,
      'routingEvidenceComplete': parts.length <= 32,
      // Keep identity, direction, validity and effects from the SAME source part.
      // Display references and straight endpoint connections are not road topology.
      'routingEvidence': [
        for (final p in parts.take(32))
          {
            'id': _text(p.id, 160),
            'roadNumbers': p.roadNumbers,
            'directionBound': p.directionBound,
            'directionCode': p.direction,
            'tmc': p.tmcReference,
            'carriageway': p.carriageway,
            'lane': p.lane,
            'category': p.category.name,
            'metrics': p.metrics,
            'timestampUtc': p.updated?.toIso8601String(),
            'validFromUtc': p.from?.toIso8601String(),
            'validUntilUtc': p.until?.toIso8601String(),
            'validityStatus': p.validityStatus,
            'suspended': p.suspended,
            'recurring': p.recurring,
            'withdrawn': p.revoked,
            'geometryAccuracy': p.displayReference
                ? 'displayReference'
                : p.coordinates.length == 1
                ? 'sourcePoint'
                : 'approximateLine',
            'point': !p.displayReference && p.coordinates.length == 1
                ? p.coordinates.first
                : null,
          },
      ],
      'geometryAccuracy': position?.displayReference == true
          ? 'displayReference'
          : points.length > 1
          ? 'approximateLine'
          : 'sourcePoint',
      'detail': _text(
        'ASTRA / VMZ-CH · ${category.label}\nGeändert: ${newest?.toIso8601String() ?? "unbekannt"}\nGültig: ${primary.from?.toIso8601String() ?? "unbekannt"} – ${primary.until?.toIso8601String() ?? "unbekannt"}\n${points.isEmpty
            ? "Keine Kartenposition. TMC-Tabelle ${tmc.tmcVersion}: ${tmc.tmcCodes.join(", ")}"
            : points.length > 1
            ? "Gerade Verbindung der Quellenpositionen; ungefähre Ausdehnung."
            : position!.displayReference
            ? "Anzeigereferenz der Quelle; keine genaue Straßenausdehnung."
            : "Koordinate der Quelle."}\n${trafficMetricLabels(metrics).join(" · ")}\n$description',
        1200,
      ),
      'geometry': points.isEmpty
          ? null
          : {
              'type': points.length == 1 ? 'Point' : 'LineString',
              'coordinates': points.length == 1 ? points.first : points,
            },
    };
  }

  TrafficSnapshot snapshot() => TrafficSnapshot(
    updates,
    publicationTime: publicationTime,
    omitted: omitted,
    sourceRecords: sourceRecords,
  );
}

String _text(Object? value, [int max = 800]) {
  final text = value?.toString() ?? '';
  return text.substring(0, text.length.clamp(0, max));
}

DateTime? _utc(String? value) {
  if (value == null || !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value)) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
}

Iterable<XmlElement> _elements(XmlNode node, String name) =>
    node.descendants.whereType<XmlElement>().where((e) => e.name.local == name);
String? _value(XmlNode node, String name) =>
    _elements(node, name).firstOrNull?.innerText;

/// Explicit DATEX coordinates only; never guesses positions from TMC codes.
/// Network snapshots are decoded incrementally, retaining one bounded XML record.
const trafficMaxResponseBytes = 32 * 1024 * 1024;
const _trafficMaxRecords = 20000;

TrafficSnapshot readTrafficSnapshot(String input) {
  // Small string callers stay bounded; the file picker streams larger imports.
  if (input.length > 4 * 1024 * 1024) {
    throw const FormatException('DATEX import too large (maximum 4 MiB)');
  }
  final reader = _TrafficXmlReader();
  for (final event in parseEvents(
    input,
    validateNesting: true,
    validateDocument: true,
  )) {
    reader.add(event);
  }
  return reader.finish();
}

Future<TrafficSnapshot> readTrafficStream(Stream<List<int>> bytes) async {
  final reader = _TrafficXmlReader();
  await readDatexEvents(bytes, reader.add);
  return reader.finish();
}

Future<void> readDatexEvents(
  Stream<List<int>> bytes,
  void Function(XmlEvent) onEvent,
) async {
  // Bound individual decoder batches and yield to GPS/UI work even when the
  // HTTP client delivers a whole response as one chunk (including test clients).
  Stream<List<int>> slices() async* {
    var total = 0, work = 0;
    await for (final chunk in bytes) {
      total += chunk.length;
      if (total > trafficMaxResponseBytes) {
        throw const FormatException('ASTRA snapshot exceeds the 32 MiB limit');
      }
      for (var i = 0; i < chunk.length; i += 16384) {
        yield chunk.sublist(i, (i + 16384).clamp(0, chunk.length));
        work += 16384;
        if (work >= 65536) {
          work = 0;
          await Future<void>.delayed(Duration.zero);
        }
      }
    }
  }

  final sink = _TrafficEventSink(onEvent);
  final decoder = XmlEventDecoder(
    validateNesting: true,
    validateDocument: true,
    withLocation: true,
  ).startChunkedConversion(sink);
  var characters = 0;
  await for (final text in slices().transform(utf8.decoder)) {
    characters += text.length;
    decoder.add(text);
    // Bound the decoder's carry for incomplete attributes/comments as well.
    if (characters - sink.offset > 256 * 1024) {
      throw const FormatException(
        'DATEX XML token exceeds the processing limit',
      );
    }
  }
  decoder.close();
}

class _TrafficEventSink implements Sink<List<XmlEvent>> {
  _TrafficEventSink(this.onEvent);
  final void Function(XmlEvent) onEvent;
  int offset = 0;
  @override
  void add(List<XmlEvent> events) {
    for (final event in events) {
      onEvent(event);
      offset = event.stop!;
    }
  }

  @override
  void close() {}
}

class _TrafficXmlReader {
  final data = _TrafficAccumulator();
  final stack = <String>[];
  List<XmlEvent>? record;
  var records = 0, recordSize = 0;
  bool supported = false;
  String? publication, situationId;
  List<TrafficRecord>? situationRecords;
  void add(XmlEvent event) {
    if (event is XmlDoctypeEvent) {
      throw const FormatException(
        'DATEX document types/entities are unsupported',
      );
    }
    if (event is XmlStartElementEvent) {
      final name = event.name.split(':').last;
      if (name == 'Fault') {
        throw const FormatException('ASTRA returned a SOAP fault');
      }
      if (name == 'd2LogicalModel' || name == 'payloadPublication') {
        supported = true;
      }
      if (stack.length >= 64) {
        throw const FormatException('DATEX nesting limit exceeded');
      }
      if (name == 'situation' && !event.isSelfClosing) {
        if (situationRecords != null) {
          throw const FormatException('Nested DATEX situation');
        }
        situationId = event.attributes
            .where((a) => a.name == 'id')
            .firstOrNull
            ?.value;
        situationRecords = [];
      }
      if (name == 'situationRecord') {
        if (record != null || ++records > _trafficMaxRecords) {
          throw const FormatException(
            'DATEX record limit exceeded (maximum 20000)',
          );
        }
        record = [];
        recordSize = 0;
      }
      if (name == 'publicationTime' && data.publicationTime == null) {
        publication = '';
      }
      if (!event.isSelfClosing) stack.add(name);
    }
    if (publication != null &&
        stack.lastOrNull == 'publicationTime' &&
        (event is XmlTextEvent || event is XmlCDATAEvent)) {
      publication =
          publication! +
          (event is XmlTextEvent
              ? event.value
              : (event as XmlCDATAEvent).value);
      if (publication!.length > 100) {
        throw const FormatException('Invalid DATEX publication time');
      }
    }
    if (record case final List<XmlEvent> buffer) {
      recordSize += switch (event) {
        XmlStartElementEvent() =>
          event.name.length +
              event.attributes.fold<int>(
                0,
                (n, a) => n + a.name.length + a.value.length,
              ),
        XmlTextEvent() => event.value.length,
        XmlCDATAEvent() => event.value.length,
        XmlCommentEvent() => event.value.length,
        _ => 0,
      };
      if (recordSize > 256 * 1024 || buffer.length >= 10000) {
        throw const FormatException(
          'DATEX record exceeds the processing limit',
        );
      }
      buffer.add(event);
      final complete =
          (event is XmlEndElementEvent &&
              stack.lastOrNull == 'situationRecord') ||
          (event is XmlStartElementEvent &&
              event.isSelfClosing &&
              event.name.split(':').last == 'situationRecord');
      if (complete) {
        final node = TrafficRecord(
          const XmlNodeDecoder().convert(buffer).single as XmlElement,
        );
        if (situationRecords == null || situationId == null) {
          data.addGroup(null, [node]);
        } else {
          if (situationRecords!.length >= 256) {
            throw const FormatException(
              'Too many DATEX parts in one situation',
            );
          }
          situationRecords!.add(node);
        }
        record = null;
      }
    }
    if (event is XmlEndElementEvent) {
      if (stack.lastOrNull == 'situation') {
        data.addGroup(situationId, situationRecords!);
        situationId = null;
        situationRecords = null;
      }
      if (stack.lastOrNull == 'publicationTime' && publication != null) {
        data.publicationTime ??= _utc(publication);
        publication = null;
      }
      stack.removeLast();
    }
  }

  TrafficSnapshot finish() {
    if (!supported || stack.isNotEmpty || record != null) {
      throw const FormatException('Not a supported DATEX situation snapshot');
    }
    return data.snapshot();
  }
}
