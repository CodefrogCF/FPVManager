import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('project attribution precedes the unchanged official Apache text', () {
    final license = File('LICENSE').readAsStringSync().replaceAll('\r\n', '\n');
    const attribution = 'FPVManager\nCopyright 2026 Codefrog\n\n';
    expect(license, startsWith(attribution));
    expect(
      sha256
          .convert(utf8.encode(license.substring(attribution.length)))
          .toString(),
      'cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30',
    );
    expect(File('NOTICE').readAsStringSync().trim(), attribution.trim());
  });

  test(
    'Flutter includes the project Apache licence once in its generated notices',
    () async {
      // Test bindings do not install the production ServicesBinding licence
      // collector. Check the actual generated asset read by that collector.
      final data = await rootBundle.load('NOTICES.Z');
      final text = utf8.decode(
        gzip.decode(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        ),
      );
      expect(
        RegExp(r'^fpvmanager$', multiLine: true).allMatches(text),
        hasLength(1),
      );
      expect(text, contains('Copyright 2026 Codefrog'));
      expect(text, contains('Apache License'));
      expect(text, contains('Version 2.0, January 2004'));
    },
  );
}
