import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/scenery/scenery_package.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Python converter output passes the real Dart package importer',
    () async {
      final bytes = await File(
        'test/fixtures/scenery/conversion_open_wall.fpvscenery',
      ).readAsBytes();
      final package = await decodeSceneryPackage(bytes);
      final manifest = package.manifest.toJson();
      expect(package.manifest.id, 'conversion-open-wall');
      expect(package.manifest.enabled, false);
      expect(package.files.length, 2);
      expect(manifest['anchor']['heightM'], 100);
      expect(manifest['collision']['enabled'], true);
      expect(manifest['replacement']['buildings']['enabled'], true);
      expect(manifest['source']['license'], 'CC0-1.0');
      expect(manifest['source']['attribution'], contains('EPSG:25832'));
    },
  );
}
