import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;

import 'offline_region.dart';

const regionPackageMaxBytes = 64 * 1024 * 1024;

class OfflineRegionPackage {
  const OfflineRegionPackage._(this.region, this.files, this.manifest);
  final OfflineRegion region;
  final Map<String, Uint8List> files;
  final Map<String, dynamic> manifest;
}

abstract interface class PreparedMapStorage {
  Future<void> importPackage(OfflineRegionPackage package);
}

/// Stored ZIP only: tile payloads are already encoded. Disallowing archive
/// compression avoids an inflater allocation before the size limit is checked.
OfflineRegionPackage decodeRegionPackage(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > regionPackageMaxBytes) {
    throw const FormatException('Choose an offline package up to 64 MiB');
  }
  final directory = ZipDirectory()..read(InputMemoryStream(bytes));
  final names = <String>{};
  var total = 0;
  if (directory.fileHeaders.length > 5001 ||
      directory.numberOfThisDisk != 0 ||
      directory.diskWithTheStartOfTheCentralDirectory != 0) {
    throw const FormatException('Unsupported offline archive');
  }
  final files = <String, Uint8List>{};
  for (final header in directory.fileHeaders) {
    final name = header.filename,
        type = (header.externalFileAttributes >> 16) & 0xf000;
    if (!names.add(name) ||
        name.length > 150 ||
        name.split('/').any((s) => s.isEmpty || s == '.' || s == '..') ||
        name.contains(RegExp(r'[\\:%?#]')) ||
        header.generalPurposeBitFlag & 1 != 0 ||
        header.compressionMethod != 0 ||
        type != 0 && type != 0x8000 ||
        header.uncompressedSize != header.compressedSize ||
        header.uncompressedSize <= 0 ||
        header.uncompressedSize >
            (name == 'manifest.json' ? 1024 * 1024 : 4 * 1024 * 1024) ||
        (total += header.uncompressedSize) > regionPackageMaxBytes) {
      throw const FormatException('Invalid or excessive offline archive entry');
    }
    final local = header.file;
    if (local == null ||
        local.compressionMethod != CompressionType.none ||
        local.filename != name ||
        local.flags & 1 != 0 ||
        local.uncompressedSize != header.uncompressedSize ||
        local.compressedSize != header.compressedSize ||
        local.crc32 != header.crc32) {
      throw const FormatException('Offline local archive header mismatch');
    }
    final body = local.getStream().toUint8List();
    if (body.length != header.uncompressedSize ||
        getCrc32(body) != header.crc32) {
      throw const FormatException('Offline archive checksum mismatch');
    }
    files[name] = body;
  }
  final metadata = files.remove('manifest.json');
  if (metadata == null) throw const FormatException('Offline manifest missing');
  final manifest = jsonDecode(utf8.decode(metadata));
  if (manifest is! Map<String, dynamic> ||
      manifest['format'] != 'fpvmanager-region' ||
      manifest['version'] != 1 ||
      manifest['heightReference'] != 'wgs84Ellipsoid' ||
      manifest['sourceHeightReference'] != 'LN02' ||
      manifest['meshGridSize'] != 65 ||
      manifest['heightGridSha256'] !=
          '533558782c5c30159264e1628de215a2446a9524f8e49af8deb8dcc83d370ae8' ||
      manifest['attribution'] != '© swisstopo' ||
      manifest['region'] is! Map ||
      manifest['files'] is! Map ||
      manifest['sources'] is! List ||
      (manifest['sources'] as List).isEmpty ||
      (manifest['sources'] as List).length > 256) {
    throw const FormatException(
      'Unsupported offline manifest or height reference',
    );
  }
  final prepared = DateTime.tryParse(
    manifest['preparedAtUtc'] is String ? manifest['preparedAtUtc'] : '',
  );
  if (prepared == null ||
      !prepared.isUtc ||
      prepared.isAfter(
        DateTime.now().toUtc().add(const Duration(minutes: 5)),
      )) {
    throw const FormatException('Invalid package timestamp');
  }
  final id = sha256.convert(metadata).toString();
  final region = OfflineRegion.fromJson({
    ...Map<String, dynamic>.from(manifest['region']),
    'packageId': id,
    'packageActive': true,
    'preparedAtUtc': prepared.toIso8601String(),
    'packageTiles': files.length,
  });
  if (region.style != 'topographic') {
    throw const FormatException('Unsupported prepared map style');
  }
  final expected = <String>{'terrain/layer.json'};
  for (final terrain in [false, true]) {
    for (
      var z = 0;
      z <= (terrain ? region.terrainLevel : region.imageryLevel);
      z++
    ) {
      final range = region.range(z, terrain: terrain);
      for (var x = range.left; x <= range.right; x++) {
        for (var y = range.bottom; y <= range.top; y++) {
          expected.add(
            terrain
                ? 'terrain/$z/$x/$y.terrain'
                : 'imagery/topographic/$z/$x/$y.png',
          );
        }
      }
    }
  }
  final declared = manifest['files'] as Map;
  if (files.length != expected.length ||
      declared.length != expected.length ||
      !expected.every(files.containsKey) ||
      !expected.every(declared.containsKey)) {
    throw const FormatException(
      'Offline region is incomplete or contains unexpected files',
    );
  }
  for (final entry in files.entries) {
    final info = declared[entry.key];
    if (info is! Map ||
        info['bytes'] != entry.value.length ||
        info['sha256'] != sha256.convert(entry.value).toString()) {
      throw const FormatException('Offline file integrity mismatch');
    }
    if (entry.key.endsWith('.png')) {
      final decoder = image.PngDecoder(),
          info = decoder.startDecode(entry.value);
      if (info == null ||
          info.width != 256 ||
          info.height != 256 ||
          info.numFrames != 1) {
        throw const FormatException('Invalid offline image');
      }
    } else if (entry.key.endsWith('.terrain')) {
      validatePreparedMesh(entry.value);
    }
  }
  final terrain = jsonDecode(utf8.decode(files['terrain/layer.json']!));
  final availability = [
    for (var z = 0; z <= region.terrainLevel; z++)
      [
        {
          'startX': region.range(z, terrain: true).left,
          'endX': region.range(z, terrain: true).right,
          'startY': region.range(z, terrain: true).bottom,
          'endY': region.range(z, terrain: true).top,
        },
      ],
  ];
  if (terrain is! Map ||
      terrain['format'] != 'quantized-mesh-1.0' ||
      terrain['projection'] != 'EPSG:4326' ||
      terrain['scheme'] != 'tms' ||
      terrain['maxzoom'] != region.terrainLevel ||
      jsonEncode(terrain['tiles']) != jsonEncode(['{z}/{x}/{y}.terrain']) ||
      jsonEncode(terrain['available']) != jsonEncode(availability) ||
      terrain.containsKey('parentUrl') ||
      terrain.containsKey('metadataAvailability')) {
    throw const FormatException(
      'Offline terrain coverage does not match region',
    );
  }
  final dates = <DateTime>[];
  final products = <String>{};
  for (final source in manifest['sources']) {
    final url = source is Map && source['url'] is String
        ? Uri.tryParse(source['url'])
        : null;
    if (url == null ||
        url.scheme != 'https' ||
        url.host != 'data.geo.admin.ch' ||
        url.userInfo.isNotEmpty ||
        url.hasPort ||
        url.hasQuery ||
        url.hasFragment ||
        url.pathSegments.length != 3 ||
        !{
          'ch.swisstopo.swissalti3d',
          'ch.swisstopo.pixelkarte-farbe-pk25.noscale',
        }.contains(url.pathSegments.firstOrNull) ||
        source['sha256'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(source['sha256'])) {
      throw const FormatException('Invalid offline source provenance');
    }
    final collection = url.pathSegments[0];
    final isTerrain = collection == 'ch.swisstopo.swissalti3d';
    if (source['collection'] != collection ||
        source['itemId'] != url.pathSegments[1] ||
        source['assetId'] != url.pathSegments[2] ||
        source['horizontalReference'] != 'EPSG:2056' ||
        source['verticalReference'] != (isTerrain ? 'LN02' : 'notApplicable') ||
        source['resolutionMeters'] != (isTerrain ? 2 : 1.25)) {
      throw const FormatException('Unsupported offline source reference');
    }
    products.add(collection);
    final raw = source['sourceTimeUtc'];
    final time = raw is String && raw.endsWith('Z')
        ? DateTime.tryParse(raw)
        : null;
    if (time == null || time.isAfter(prepared.add(const Duration(days: 1)))) {
      throw const FormatException('Invalid source edition time');
    }
    dates.add(time);
  }
  dates.sort();
  if (products.length != 2) {
    throw const FormatException('Map and terrain source provenance required');
  }
  return OfflineRegionPackage._(
    OfflineRegion.fromJson({
      ...region.toJson(),
      'provenance': {
        'sources': manifest['sources'],
        'sourcePlanRetrievedAtUtc': manifest['sourcePlanRetrievedAtUtc'],
        'sourceHeightReference': manifest['sourceHeightReference'],
        'heightReference': manifest['heightReference'],
        'resampling': manifest['resampling'],
        'heightGridSha256': manifest['heightGridSha256'],
      },
      'sourceDates': dates.first.year == dates.last.year
          ? '${dates.first.year}'
          : '${dates.first.year}–${dates.last.year}',
    }),
    Map.unmodifiable(
      files.map((key, value) => MapEntry(key, value.asUnmodifiableView())),
    ),
    Map.unmodifiable(manifest),
  );
}

void validatePreparedMesh(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var offset = 88;
  if (bytes.length < 92) {
    throw const FormatException('Truncated prepared terrain');
  }
  for (final at in [0, 8, 16, 32, 40, 48, 56, 64, 72, 80]) {
    final value = data.getFloat64(at, Endian.little);
    if (!value.isFinite || value.abs() > 3e7) {
      throw const FormatException('Invalid terrain header');
    }
  }
  final low = data.getFloat32(24, Endian.little),
      high = data.getFloat32(28, Endian.little);
  if (!low.isFinite ||
      !high.isFinite ||
      low > high ||
      low < -1000 ||
      high > 15000 ||
      data.getFloat64(56, Endian.little) <= 0) {
    throw const FormatException('Invalid prepared elevations');
  }
  int u32() {
    if (offset + 4 > bytes.length) {
      throw const FormatException('Truncated terrain');
    }
    final v = data.getUint32(offset, Endian.little);
    offset += 4;
    return v;
  }

  final count = u32();
  if (count != 65 * 65) {
    throw const FormatException('Unsupported prepared terrain grid');
  }
  for (var axis = 0; axis < 3; axis++) {
    var value = 0;
    for (var i = 0; i < count; i++) {
      if (offset + 2 > bytes.length) {
        throw const FormatException('Truncated vertices');
      }
      final encoded = data.getUint16(offset, Endian.little);
      offset += 2;
      value += encoded.isEven ? encoded ~/ 2 : -((encoded + 1) ~/ 2);
      if (value < 0 || value > 32767) {
        throw const FormatException('Invalid quantized vertex');
      }
    }
  }
  final triangles = u32();
  if (triangles != 64 * 64 * 2) {
    throw const FormatException('Invalid terrain triangles');
  }
  var highest = 0;
  for (var i = 0; i < triangles * 3; i++) {
    if (offset + 2 > bytes.length) {
      throw const FormatException('Truncated indices');
    }
    final code = data.getUint16(offset, Endian.little);
    offset += 2;
    final index = highest - code;
    if (index < 0 || index >= count) {
      throw const FormatException('Invalid terrain index');
    }
    if (code == 0) highest++;
  }
  for (var edge = 0; edge < 4; edge++) {
    final length = u32();
    if (length != 65 || offset + length * 2 > bytes.length) {
      throw const FormatException('Invalid terrain edge');
    }
    for (var i = 0; i < length; i++) {
      if (data.getUint16(offset + i * 2, Endian.little) >= count) {
        throw const FormatException('Invalid terrain edge index');
      }
    }
    offset += length * 2;
  }
  if (offset != bytes.length) {
    throw const FormatException('Unsupported prepared terrain extensions');
  }
}

Map<String, dynamic>? activePreparedRegion(List<OfflineRegion> regions) {
  final active = regions
      .where((r) => r.packageActive && r.packageId != null)
      .toList();
  if (active.length > 1) {
    throw const FormatException('Multiple active offline packages');
  }
  return active.isEmpty ? null : (active.single.toJson()..remove('provenance'));
}

String preparedMime(String key) => key.endsWith('.json')
    ? 'application/json'
    : key.endsWith('.png')
    ? 'image/png'
    : 'application/octet-stream';
bool preparedKey(String key) => RegExp(
  r'^prepared/[0-9a-f]{64}/(terrain/layer\.json|terrain/\d{1,2}/\d{1,7}/\d{1,7}\.terrain|imagery/(topographic|satellite|relief)/\d{1,2}/\d{1,7}/\d{1,7}\.png|sources/\d{1,4}\.json)$',
).hasMatch(key);
