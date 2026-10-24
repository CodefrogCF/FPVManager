import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

Future<({String name, Uint8List bytes})?> pickLocalCsv() async {
  final file = await openFile(
    acceptedTypeGroups: [
      const XTypeGroup(
        label: 'CSV',
        extensions: ['csv'],
        mimeTypes: [
          'text/csv',
          'text/comma-separated-values',
          'application/csv',
        ],
        uniformTypeIdentifiers: ['public.comma-separated-values-text'],
      ),
    ],
  );
  if (file == null) return null;
  final size = await file.length();
  if (size <= 0 || size > 4 * 1024 * 1024) {
    throw const FormatException('Choose a CSV up to 4 MiB');
  }
  final data = BytesBuilder(copy: false);
  await for (final chunk in file.openRead(0, size)) {
    if (data.length + chunk.length > 4 * 1024 * 1024) {
      throw const FormatException('CSV exceeds 4 MiB');
    }
    data.add(chunk);
  }
  return (name: file.name, bytes: data.takeBytes());
}
