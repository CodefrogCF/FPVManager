import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/routes/transfer/route_file_service.dart';

void main() {
  test('native Android route selection is not restricted by MIME type', () {
    expect(
      routeImportTypeGroups(platform: TargetPlatform.android, isWeb: false),
      isEmpty,
    );
  });

  test('desktop, iOS and web retain the supported route filters', () {
    for (final platform in TargetPlatform.values) {
      for (final isWeb in [false, true]) {
        if (!isWeb && platform == TargetPlatform.android) continue;
        final group = routeImportTypeGroups(
          platform: platform,
          isWeb: isWeb,
        ).single;
        expect(group.extensions, ['geojson', 'json', 'gpx']);
        expect(group.mimeTypes, contains('application/geo+json'));
        expect(group.uniformTypeIdentifiers, contains('public.json'));
      }
    }
  });
}
