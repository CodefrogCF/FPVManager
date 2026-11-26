import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;

const sceneryPackageMaxBytes = 64 * 1024 * 1024;
const _maxEntries = 34;

Never _invalid() =>
    throw const FormatException('Invalid or unsupported scenery ZIP');

bool _path(String name) =>
    name == 'manifest.json' ||
    name == 'preview.png' ||
    RegExp(r'^assets/[a-f0-9]{64}\.(glb|fpc)$').hasMatch(name);

/// Strict ZIP32 STORE subset. No inflater, filesystem extraction, data
/// descriptors, extra fields, ZIP64, encryption, comments or overlapping entries.
Map<String, Uint8List> readSceneryZip(Uint8List bytes) {
  if (bytes.length < 22 || bytes.length > sceneryPackageMaxBytes) _invalid();
  final d = ByteData.sublistView(bytes);
  int u16(int p) => d.getUint16(p, Endian.little);
  int u32(int p) => d.getUint32(p, Endian.little);
  final end = bytes.length - 22;
  if (u32(end) != 0x06054b50 ||
      u16(end + 4) != 0 ||
      u16(end + 6) != 0 ||
      u16(end + 20) != 0) {
    _invalid();
  }
  final count = u16(end + 10), start = u32(end + 16);
  if (count < 1 ||
      count > _maxEntries ||
      u16(end + 8) != count ||
      start > end ||
      u32(end + 12) != end - start) {
    _invalid();
  }
  final result = <String, Uint8List>{};
  final ranges = <(int, int)>[];
  var p = start;
  for (var i = 0; i < count; i++) {
    if (p + 46 > end || u32(p) != 0x02014b50) _invalid();
    final flags = u16(p + 8),
        size = u32(p + 24),
        n = u16(p + 28),
        local = u32(p + 42),
        crc = u32(p + 16),
        type = (u32(p + 38) >> 16) & 0xf000;
    if ((flags & ~0x800) != 0 ||
        u16(p + 10) != 0 ||
        size == 0 ||
        size != u32(p + 20) ||
        n == 0 ||
        n > 100 ||
        u16(p + 30) != 0 ||
        u16(p + 32) != 0 ||
        u16(p + 34) != 0 ||
        (type != 0 && type != 0x8000) ||
        p + 46 + n > end ||
        local + 30 + n > start) {
      _invalid();
    }
    final name = ascii.decode(bytes.sublist(p + 46, p + 46 + n));
    if (!_path(name) ||
        result.containsKey(name) ||
        (name == 'manifest.json' && size > 256 * 1024) ||
        (name == 'preview.png' && size > 32 * 1024)) {
      _invalid();
    }
    if (u32(local) != 0x04034b50 ||
        u16(local + 6) != flags ||
        u16(local + 8) != 0 ||
        u32(local + 14) != crc ||
        u32(local + 18) != size ||
        u32(local + 22) != size ||
        u16(local + 26) != n ||
        u16(local + 28) != 0 ||
        ascii.decode(bytes.sublist(local + 30, local + 30 + n)) != name) {
      _invalid();
    }
    final body = local + 30 + n, stop = body + size;
    if (stop > start) _invalid();
    ranges.add((local, stop));
    result[name] = Uint8List.sublistView(bytes, body, stop);
    p += 46 + n;
  }
  if (p != end) _invalid();
  ranges.sort((a, b) => a.$1.compareTo(b.$1));
  var next = 0;
  for (final range in ranges) {
    if (range.$1 != next) _invalid();
    next = range.$2;
  }
  if (next != start || !result.containsKey('manifest.json')) _invalid();
  // Only after proving all entries disjoint and bounded, scan their bytes.
  p = start;
  for (var i = 0; i < count; i++) {
    final n = u16(p + 28),
        name = ascii.decode(bytes.sublist(p + 46, p + 46 + n));
    if (getCrc32(result[name]!) != u32(p + 16)) _invalid();
    p += 46 + n;
  }
  return result;
}

Uint8List writeSceneryZip(Map<String, Uint8List> files) {
  if (files.length > _maxEntries || !files.containsKey('manifest.json')) {
    _invalid();
  }
  final size = files.entries.fold<int>(
    22,
    (n, e) => n + 76 + 2 * e.key.length + e.value.length,
  );
  if (size > sceneryPackageMaxBytes) _invalid();
  final bytes = Uint8List(size);
  final out = ByteData.sublistView(bytes);
  void u16(int p, int v) => out.setUint16(p, v, Endian.little);
  void u32(int p, int v) => out.setUint32(p, v, Endian.little);
  final entries = <(String, int, int, int)>[];
  var p = 0;
  for (final e in files.entries) {
    if (!_path(e.key) ||
        e.value.isEmpty ||
        (e.key == 'manifest.json' && e.value.length > 256 * 1024) ||
        (e.key == 'preview.png' && e.value.length > 32 * 1024)) {
      _invalid();
    }
    final name = ascii.encode(e.key),
        crc = getCrc32(e.value),
        n = e.value.length;
    entries.add((e.key, p, crc, n));
    u32(p, 0x04034b50);
    u16(p + 4, 20);
    u16(p + 12, 33);
    u32(p + 14, crc);
    u32(p + 18, n);
    u32(p + 22, n);
    u16(p + 26, name.length);
    bytes.setRange(p + 30, p + 30 + name.length, name);
    p += 30 + name.length;
    bytes.setRange(p, p + n, e.value);
    p += n;
  }
  final central = p;
  for (final (key, offset, crc, n) in entries) {
    final name = ascii.encode(key);
    u32(p, 0x02014b50);
    u16(p + 4, 20);
    u16(p + 6, 20);
    u16(p + 14, 33);
    u32(p + 16, crc);
    u32(p + 20, n);
    u32(p + 24, n);
    u16(p + 28, name.length);
    u32(p + 42, offset);
    bytes.setRange(p + 46, p + 46 + name.length, name);
    p += 46 + name.length;
  }
  u32(p, 0x06054b50);
  u16(p + 8, entries.length);
  u16(p + 10, entries.length);
  u32(p + 12, p - central);
  u32(p + 16, central);
  return bytes;
}
