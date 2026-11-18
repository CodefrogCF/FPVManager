import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'LICENSE is the canonical Apache text and NOTICE identifies the project',
    () {
      final license = File('LICENSE')
          .readAsStringSync()
          .replaceAll('\r\n', '\n');
      expect(
        sha256.convert(utf8.encode(license)).toString(),
        'cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30',
      );
      final notice = File('NOTICE').readAsStringSync().replaceAll('\r\n', '\n');
      expect(notice.trim(), 'FPVManager\nCopyright 2026 Codefrog');
    },
  );

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
      final notice = await rootBundle.loadString('NOTICE');
      expect(notice, contains('Copyright 2026 Codefrog'));
      expect(text, contains('Apache License'));
      expect(text, contains('Version 2.0, January 2004'));
    },
  );
}
