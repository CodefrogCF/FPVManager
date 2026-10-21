import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

import 'obstacle_models.dart';

class ObstacleImportResult {
  const ObstacleImportResult(this.count, this.skipped, this.metadata);
  final int count, skipped;
  final Map<String, String> metadata;
}

/// Reads only the one embedded KML. Never extracts files, loads icons, expands
/// network links, or follows external styles. Memory is bounded by the download,
/// inflater window, one XML token/Placemark and one insertion batch.
class KmzObstacleImporter {
  const KmzObstacleImporter({
    this.maxArchiveBytes = 32 * 1024 * 1024,
    this.maxExpandedBytes = 512 * 1024 * 1024,
    this.maxRecords = 300000,
    this.maxRecordCharacters = 256 * 1024,
    this.batchSize = 250,
  });
  final int maxArchiveBytes,
      maxExpandedBytes,
      maxRecords,
      maxRecordCharacters,
      batchSize;

  Future<ObstacleImportResult> import(
    Uint8List bytes, {
    required Future<void> Function(List<ObstacleFeature>) onBatch,
    bool Function()? cancelled,
    void Function(double)? onProgress,
  }) async {
    final entry = _kmlEntry(bytes);
    final source = InputMemoryStream(
      Uint8List.sublistView(
        bytes,
        entry.offset,
        entry.offset + entry.compressed,
      ),
    );
    final input = entry.method == 8
        ? const ZLibDecoder().decodeLazy(source, raw: true)
        : source;
    var expanded = 0, crc = 0;
    final guard = _XmlByteGuard(maxRecordCharacters);
    Stream<List<int>> chunks() async* {
      while (!input.isEOS) {
        if (cancelled?.call() == true) {
          throw StateError('Obstacle import cancelled');
        }
        final chunk = input.readBytes(32 * 1024).toUint8List();
        if (chunk.isEmpty) break;
        expanded += chunk.length;
        if (expanded > entry.expanded || expanded > maxExpandedBytes) {
          throw const FormatException('KMZ expanded size limit exceeded');
        }
        crc = getCrc32(chunk, crc);
        // Bounds the XML decoder's buffer, including unterminated comments,
        // entities, attributes and CDATA, before giving bytes to the decoder.
        for (final b in chunk) {
          guard.add(b);
        }
        yield chunk;
        onProgress?.call(expanded / entry.expanded);
        await Future<void>.delayed(Duration.zero);
      }
      if (expanded != entry.expanded || crc != entry.crc) {
        throw const FormatException('KML size or CRC checksum mismatch');
      }
    }

    var depth = 0,
        recordDepth = -1,
        recordSize = 0,
        total = 0,
        count = 0,
        skipped = 0;
    var external = 0;
    final metadata = <String, String>{};
    String? metadataKey;
    final text = StringBuffer();
    final record = <XmlEvent>[];
    final batch = <ObstacleFeature>[];
    final events = chunks()
        .transform(utf8.decoder)
        .toXmlEvents(
          validateDocument: true,
          validateNesting: true,
          validateNamespace: true,
          withNamespace: true,
        );
    await for (final group in events) {
      for (final event in group) {
        if (event is XmlDoctypeEvent || event is XmlProcessingEvent) {
          throw const FormatException(
            'KML DTDs and processing instructions are unsupported',
          );
        }
        if (event is XmlStartElementEvent) {
          if (event.attributes.length > 64 || ++depth > 32) {
            throw const FormatException('KML structure limit exceeded');
          }
          if (event.namespaceUri != 'http://www.opengis.net/kml/2.2' &&
              event.namespaceUri != null &&
              event.localName != 'altitudeMode') {
            throw const FormatException('Unsupported KML element namespace');
          }
          if (event.localName == 'NetworkLink') external++;
          if (event.localName == 'Placemark') {
            if (recordDepth != -1 || ++total > maxRecords) {
              throw const FormatException('KML record limit exceeded');
            }
            recordDepth = depth;
            recordSize = 0;
          }
          if (recordDepth == -1 && event.localName == 'SimpleData') {
            metadataKey = event.attributes
                .where((a) => a.name == 'name')
                .firstOrNull
                ?.value;
            text.clear();
          }
        }
        if (recordDepth != -1) {
          recordSize += event is XmlTextEvent
              ? event.value.length
              : event is XmlCDATAEvent
              ? event.value.length
              : event is XmlStartElementEvent
              ? event.name.length +
                    4 +
                    event.attributes.fold<int>(
                      0,
                      (n, a) => n + a.name.length + a.value.length + 4,
                    )
              : event is XmlEndElementEvent
              ? event.name.length + 3
              : event is XmlCommentEvent
              ? event.value.length + 7
              : 16;
          if (recordSize > maxRecordCharacters || record.length >= 20000) {
            throw const FormatException('KML Placemark too large');
          }
          record.add(event);
        } else if (metadataKey != null) {
          if (event is XmlTextEvent) text.write(event.value);
          if (event is XmlCDATAEvent) text.write(event.value);
          if (text.length > 8000) {
            throw const FormatException('KML metadata too large');
          }
        }
        final end = event is XmlEndElementEvent
            ? event.localName
            : event is XmlStartElementEvent && event.isSelfClosing
            ? event.localName
            : null;
        if (end != null) {
          if (recordDepth == depth && end == 'Placemark') {
            final element =
                const XmlNodeDecoder().convert(record).single as XmlElement;
            final feature = _feature(element);
            if (feature == null) {
              skipped++;
            } else {
              batch.add(feature);
              count++;
            }
            record.clear();
            recordDepth = -1;
            if (batch.length >= batchSize) {
              await onBatch(List.of(batch));
              batch.clear();
            }
          } else if (recordDepth == -1 &&
              end == 'SimpleData' &&
              metadataKey != null) {
            if (metadata.length >= 64 || metadataKey.length > 120) {
              throw const FormatException('KML metadata limit exceeded');
            }
            metadata[metadataKey] = text.toString().trim();
            metadataKey = null;
          }
          depth--;
        }
      }
    }
    if (recordDepth != -1 || depth != 0 || count == 0) {
      throw const FormatException('No complete supported obstacle dataset');
    }
    if (batch.isNotEmpty) await onBatch(batch);
    metadata['ignoredNetworkLinks'] = '$external';
    return ObstacleImportResult(count, skipped, Map.unmodifiable(metadata));
  }

  ObstacleFeature? _feature(XmlElement element) {
    final attrs = <String, String>{};
    for (final item in element.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'SimpleData',
    )) {
      final name = item.getAttribute('name');
      if (name == null ||
          name.length > 120 ||
          item.innerText.length > 8000 ||
          attrs.length >= 64) {
        throw const FormatException('Invalid obstacle attribute');
      }
      attrs[name] = item.innerText.trim();
    }
    for (final field in ['maxHeightAGL', 'topElevationAMSL', 'radius']) {
      final raw = attrs[field];
      if (raw == null || raw.isEmpty) continue;
      final value = double.tryParse(raw);
      if (value == null ||
          !value.isFinite ||
          value > 100000 ||
          value < (field == 'topElevationAMSL' ? -1500 : 0)) {
        throw FormatException('Invalid obstacle $field');
      }
    }
    final id = element.getAttribute('id') ?? attrs['uuid'];
    if (id == null || id.isEmpty || id.length > 160) {
      throw const FormatException('Missing or invalid obstacle ID');
    }
    final name =
        element.childElements
            .where((e) => e.name.local == 'name')
            .firstOrNull
            ?.innerText ??
        id;
    if (name.length > 500) {
      throw const FormatException('Obstacle name too long');
    }
    final parts = <ObstaclePart>[];
    var vertices = 0;
    for (final geom in element.descendants.whereType<XmlElement>().where(
      (e) => const {'Point', 'LineString', 'LinearRing'}.contains(e.name.local),
    )) {
      final raw = geom.childElements
          .where((e) => e.name.local == 'coordinates')
          .firstOrNull
          ?.innerText
          .trim();
      if (raw == null || raw.isEmpty) {
        throw const FormatException('Missing obstacle coordinates');
      }
      final coordinates = <List<double>>[];
      for (final tuple in raw.split(RegExp(r'\s+'))) {
        final p = tuple.split(',').map(double.parse).toList();
        if (p.length < 2 ||
            p.length > 3 ||
            p.any((n) => !n.isFinite) ||
            p[0].abs() > 180 ||
            p[1].abs() > 90 ||
            p.length == 3 && (p[2] < -1500 || p[2] > 15000) ||
            ++vertices > 4096) {
          throw const FormatException(
            'Invalid or excessive obstacle coordinates',
          );
        }
        coordinates.add(p);
      }
      var kind = geom.name.local;
      if (kind == 'Point' ? coordinates.length != 1 : coordinates.length < 2) {
        throw const FormatException('Invalid obstacle geometry');
      }
      var mode = geom.childElements
          .where((e) => e.name.local == 'altitudeMode')
          .firstOrNull
          ?.innerText
          .trim();
      if (kind == 'LinearRing') {
        final polygon = geom.ancestors
            .whereType<XmlElement>()
            .where((e) => e.name.local == 'Polygon')
            .firstOrNull;
        mode ??= polygon?.childElements
            .where((e) => e.name.local == 'altitudeMode')
            .firstOrNull
            ?.innerText
            .trim();
        kind = geom.parentElement?.name.local == 'innerBoundaryIs'
            ? 'PolygonHole'
            : 'PolygonOuter';
        if (coordinates.length < 4 ||
            coordinates.first[0] != coordinates.last[0] ||
            coordinates.first[1] != coordinates.last[1]) {
          throw const FormatException('Invalid obstacle ring');
        }
      }
      parts.add(ObstaclePart(kind, mode ?? 'clampToGround', coordinates));
      if (parts.length > 64) {
        throw const FormatException('Too many obstacle parts');
      }
    }
    return parts.isEmpty
        ? null
        : ObstacleFeature(id: id, name: name, attributes: attrs, parts: parts);
  }

  _KmlEntry _kmlEntry(Uint8List bytes) {
    if (bytes.length < 22 || bytes.length > maxArchiveBytes) {
      throw const FormatException('KMZ download size limit exceeded');
    }
    final d = ByteData.sublistView(bytes);
    var eocd = bytes.length - 22;
    while (eocd >= 0 &&
        eocd >= bytes.length - 65557 &&
        d.getUint32(eocd, Endian.little) != 0x06054b50) {
      eocd--;
    }
    if (eocd < 0 || eocd < bytes.length - 65557) {
      throw const FormatException('Invalid KMZ directory');
    }
    int u16(int n) => d.getUint16(n, Endian.little);
    int u32(int n) => d.getUint32(n, Endian.little);
    final count = u16(eocd + 10), start = u32(eocd + 16), size = u32(eocd + 12);
    if (u16(eocd + 4) != 0 ||
        u16(eocd + 6) != 0 ||
        u16(eocd + 8) != count ||
        count == 0 ||
        count > 128 ||
        start + size != eocd ||
        eocd + 22 + u16(eocd + 20) != bytes.length) {
      throw const FormatException('Unsupported or excessive KMZ directory');
    }
    var pos = start, total = 0;
    final names = <String>{}, ranges = <(int, int)>[], kml = <_KmlEntry>[];
    for (var i = 0; i < count; i++) {
      if (pos + 46 > eocd || u32(pos) != 0x02014b50) {
        throw const FormatException('Invalid KMZ entry');
      }
      final flags = u16(pos + 8),
          method = u16(pos + 10),
          compressed = u32(pos + 20),
          expanded = u32(pos + 24);
      final length = u16(pos + 28),
          extra = u16(pos + 30),
          comment = u16(pos + 32),
          local = u32(pos + 42);
      if (pos + 46 + length + extra + comment > eocd || local + 30 > start) {
        throw const FormatException('Truncated KMZ entry');
      }
      final name = utf8.decode(
        Uint8List.sublistView(bytes, pos + 46, pos + 46 + length),
      );
      total += expanded;
      if (name.isEmpty ||
          name.length > 240 ||
          name.contains('\\') ||
          name.contains(':') ||
          name.startsWith('/') ||
          name.contains('\u0000') ||
          name.split('/').any((s) => s == '..' || s == '.') ||
          !names.add(name.toLowerCase()) ||
          flags & 0x41 != 0 ||
          ![0, 8].contains(method) ||
          u16(pos + 34) != 0 ||
          (u32(pos + 38) >> 16) & 0xf000 == 0xa000 ||
          total > maxExpandedBytes ||
          expanded > maxExpandedBytes ||
          compressed > maxArchiveBytes ||
          expanded > (compressed + 1024) * 200 ||
          u32(local) != 0x04034b50 ||
          u16(local + 6) != flags ||
          u16(local + 8) != method) {
        throw const FormatException('Unsafe or unsupported KMZ entry');
      }
      final offset = local + 30 + u16(local + 26) + u16(local + 28);
      if (offset + compressed > start ||
          offset > start ||
          utf8.decode(
                Uint8List.sublistView(
                  bytes,
                  local + 30,
                  local + 30 + u16(local + 26),
                ),
              ) !=
              name ||
          flags & 8 == 0 &&
              (u32(local + 18) != compressed ||
                  u32(local + 22) != expanded ||
                  u32(local + 14) != u32(pos + 16))) {
        throw const FormatException('Inconsistent KMZ entry');
      }
      for (final r in ranges) {
        if (local < r.$2 && offset + compressed > r.$1) {
          throw const FormatException('Overlapping KMZ entries');
        }
      }
      ranges.add((local, offset + compressed));
      if (name.toLowerCase().endsWith('.kml')) {
        kml.add(_KmlEntry(offset, compressed, expanded, method, u32(pos + 16)));
      }
      pos += 46 + length + extra + comment;
    }
    if (pos != eocd || kml.length != 1 || kml.single.expanded == 0) {
      throw const FormatException('Expected one supported full KML dataset');
    }
    return kml.single;
  }
}

class _KmlEntry {
  const _KmlEntry(
    this.offset,
    this.compressed,
    this.expanded,
    this.method,
    this.crc,
  );
  final int offset, compressed, expanded, method, crc;
}

class _XmlByteGuard {
  _XmlByteGuard(this.limit);
  final int limit;
  int length = 0, quote = 0, mode = 0, previous = 0, beforePrevious = 0;
  String prefix = '';
  void add(int byte) {
    if (mode == 0 && byte == 60) {
      mode = 1;
      length = 0;
      prefix = '';
      quote = 0;
      previous = beforePrevious = 0;
    }
    if (++length > limit) throw const FormatException('KML token too large');
    if (mode == 0) return;
    if (mode == 1 && length <= 9) {
      prefix += String.fromCharCode(byte);
      if (prefix == '<!--') mode = 2;
      if (prefix == '<![CDATA[') mode = 3;
      if (prefix.toUpperCase() == '<!DOCTYPE') {
        throw const FormatException('KML DTDs are unsupported');
      }
    }
    if (mode >= 2) {
      if (byte == 62 &&
          previous == (mode == 2 ? 45 : 93) &&
          beforePrevious == previous) {
        mode = 0;
        length = 0;
      }
      beforePrevious = previous;
      previous = byte;
      return;
    }
    if (quote != 0) {
      if (byte == quote) quote = 0;
      return;
    }
    if (byte == 34 || byte == 39) {
      quote = byte;
      return;
    }
    if (byte == 62) {
      mode = 0;
      length = 0;
    }
  }
}
