import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Reads selected DAT files without extracting paths or eagerly inflating ZIPs.
Map<String, Uint8List> readTmcArchive(Uint8List bytes) {
  const needed = {
    'LOCATIONDATASETS.DAT',
    'README.DAT',
    'POINTS.DAT',
    'POFFSETS.DAT',
    'ROADS.DAT',
    'SEGMENTS.DAT',
    'NAMES.DAT',
  };
  if (bytes.length < 22 || bytes.length > 8 * 1024 * 1024) {
    throw const FormatException('TMC-ZIP: maximal 8 MiB');
  }
  final d = ByteData.sublistView(bytes);
  int u16(int n) => d.getUint16(n, Endian.little);
  int u32(int n) => d.getUint32(n, Endian.little);
  var end = bytes.length - 22;
  while (end >= 0 && end >= bytes.length - 65557 && u32(end) != 0x06054b50) {
    end--;
  }
  if (end < 0 || end < bytes.length - 65557) {
    throw const FormatException('Ungültiges TMC-ZIP');
  }
  final count = u16(end + 10), start = u32(end + 16), size = u32(end + 12);
  if (u16(end + 4) != 0 ||
      u16(end + 6) != 0 ||
      u16(end + 8) != count ||
      count == 0 ||
      count > 256 ||
      start + size != end ||
      end + 22 + u16(end + 20) != bytes.length) {
    throw const FormatException('Nicht unterstütztes TMC-ZIP-Verzeichnis');
  }
  var cursor = start, expandedTotal = 0;
  final paths = <String>{}, ranges = <(int, int)>[];
  final result = <String, Uint8List>{};
  String? folder;
  for (var i = 0; i < count; i++) {
    if (cursor + 46 > end || u32(cursor) != 0x02014b50) {
      throw const FormatException('Ungültiger ZIP-Eintrag');
    }
    final flags = u16(cursor + 8),
        method = u16(cursor + 10),
        crc = u32(cursor + 16),
        compressed = u32(cursor + 20),
        expanded = u32(cursor + 24),
        nameLength = u16(cursor + 28),
        extra = u16(cursor + 30),
        comment = u16(cursor + 32),
        local = u32(cursor + 42);
    final next = cursor + 46 + nameLength + extra + comment;
    if (next > end ||
        nameLength == 0 ||
        nameLength > 400 ||
        u16(cursor + 34) != 0 ||
        (flags & 0x41) != 0 ||
        !{0, 8}.contains(method) ||
        ((u32(cursor + 38) >> 16) & 0xf000) == 0xa000 ||
        expanded > 8 * 1024 * 1024 ||
        (expandedTotal += expanded) > 32 * 1024 * 1024) {
      throw const FormatException('Unsicherer oder zu großer ZIP-Eintrag');
    }
    final rawName = Uint8List.sublistView(
      bytes,
      cursor + 46,
      cursor + 46 + nameLength,
    );
    final name = utf8.decode(rawName), pieces = name.split('/');
    final file = name.endsWith('/')
        ? pieces.take(pieces.length - 1).toList()
        : pieces;
    if (file.isEmpty ||
        file.any((p) => p.isEmpty || p == '.' || p == '..') ||
        name.contains(RegExp(r'[\\:\x00-\x1f]')) ||
        !paths.add(name.toLowerCase()) ||
        local + 30 > start ||
        u32(local) != 0x04034b50) {
      throw const FormatException('Ungültiger ZIP-Pfad');
    }
    final ln = u16(local + 26),
        le = u16(local + 28),
        dataStart = local + 30 + ln + le;
    if (u16(local + 6) != flags ||
        u16(local + 8) != method ||
        ln != nameLength ||
        dataStart + compressed > start ||
        utf8.decode(
              Uint8List.sublistView(bytes, local + 30, local + 30 + ln),
            ) !=
            name ||
        ((flags & 8) == 0 &&
            (u32(local + 14) != crc ||
                u32(local + 18) != compressed ||
                u32(local + 22) != expanded))) {
      throw const FormatException('Widersprüchlicher ZIP-Eintrag');
    }
    for (final r in ranges) {
      if (local < r.$2 && dataStart + compressed > r.$1) {
        throw const FormatException('Überlappende ZIP-Einträge');
      }
    }
    ranges.add((local, dataStart + compressed));
    final key = pieces.last.toUpperCase();
    if (needed.contains(key)) {
      final parent = pieces.take(pieces.length - 1).join('/');
      if (result.containsKey(key) || folder != null && folder != parent) {
        throw const FormatException('Mehrdeutige TMC-Dateien');
      }
      folder = parent;
      final source = InputMemoryStream(
        Uint8List.sublistView(bytes, dataStart, dataStart + compressed),
      );
      final input = method == 8
          ? const ZLibDecoder().decodeLazy(source, raw: true)
          : source;
      final output = BytesBuilder(copy: false);
      var length = 0, checksum = 0;
      while (!input.isEOS) {
        final part = input.readBytes(16384).toUint8List();
        if (part.isEmpty) break;
        length += part.length;
        if (length > expanded || length > 8 * 1024 * 1024) {
          throw const FormatException('TMC-Entpacklimit überschritten');
        }
        checksum = getCrc32(part, checksum);
        output.add(part);
      }
      if (length != expanded || checksum != crc) {
        throw const FormatException('TMC-Prüfsumme oder Dateigröße ungültig');
      }
      result[key] = output.takeBytes();
    }
    cursor = next;
  }
  if (cursor != end || !result.keys.toSet().containsAll(needed)) {
    throw const FormatException(
      'Unvollständiges TMC-LTEF-Paket (DAT-Dateien fehlen)',
    );
  }
  return result;
}
