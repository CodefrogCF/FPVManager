import 'dart:convert';
import 'dart:typed_data';

/// Bounded RFC 4180-style CSV. No formulas, URLs or external resources execute.
List<List<String>> readBoundedCsv(Uint8List bytes, {int maxRows = 20001}) {
  if (bytes.isEmpty || bytes.length > 4 * 1024 * 1024) {
    throw const FormatException('Choose a UTF-8 CSV up to 4 MiB');
  }
  var text = utf8.decode(bytes);
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  if (text.contains('\u0000')) throw const FormatException('Invalid CSV text');
  final rows = <List<String>>[], row = <String>[];
  var cell = StringBuffer(), quoted = false, closed = false;
  void field() {
    row.add(cell.toString());
    if (row.length > 256) throw const FormatException('Too many CSV columns');
    cell = StringBuffer();
    closed = false;
  }

  void line() {
    field();
    if (row.any((s) => s.isNotEmpty)) rows.add(List.of(row));
    row.clear();
    if (rows.length > maxRows) throw const FormatException('Too many CSV rows');
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
          closed = true;
        }
      } else {
        cell.write(c);
      }
    } else if (c == ',') {
      field();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      line();
    } else if (c == '"' && cell.isEmpty && !closed) {
      quoted = true;
    } else {
      if (closed || c == '"') {
        throw const FormatException('Malformed CSV quoting');
      }
      cell.write(c);
    }
    if (cell.length > 4096) throw const FormatException('CSV field too long');
  }
  if (quoted) throw const FormatException('Unclosed CSV quote');
  if (cell.isNotEmpty || row.isNotEmpty || closed) line();
  if (rows.isEmpty) throw const FormatException('Empty CSV');
  return rows;
}
