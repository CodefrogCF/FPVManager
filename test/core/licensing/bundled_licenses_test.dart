import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/licensing/bundled_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'additional component notices are bundled without changing upstream text',
    () async {
      for (final path in const [
        'assets/licenses/image-LICENSE-other.md',
        'assets/licenses/archive-LICENSE-other.md',
      ]) {
        final packaged = await rootBundle.loadString(path);
        expect(packaged, File(path).readAsStringSync());
        expect(packaged, contains('Copyright'));
        expect(packaged.length, greaterThan(4000));
      }
    },
  );

  test(
    'registration is idempotent and extra notices remain readable on reopening',
    () async {
      const packages = {
        'image (bundled components)',
        'archive (bundled components)',
      };
      registerBundledLicenses();
      registerBundledLicenses();
      for (var opening = 0; opening < 2; opening++) {
        final entries = await LicenseRegistry.licenses
            .where((entry) => entry.packages.any(packages.contains))
            .toList();
        expect(entries, hasLength(2));
        expect(entries.expand((entry) => entry.packages).toSet(), packages);
        for (final entry in entries) {
          expect(entry.paragraphs, isNotEmpty);
          final text = entry.paragraphs
              .map((paragraph) => paragraph.text)
              .join('\n');
          expect(text, contains('Copyright'));
          expect(text.length, greaterThan(4000));
        }
      }
    },
  );
}
