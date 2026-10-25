@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/offline/offline_map_store_web.dart';
import 'package:fpvmanager/features/offline/offline_region.dart';
import 'package:fpvmanager/features/data_management/backup_codec.dart';

void main() {
  test(
    'password-protected backup payload authenticates through browser WebCrypto',
    () async {
      final payload = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'format': 'fpvmanager-backup',
            'version': 1,
            'schema': 9,
            'createdAt': '2026-10-25T12:00:00Z',
            'tables': {},
          }),
        ),
      );
      final encrypted = await encodeBackup(
        BackupEncodeJob(payload, 'browser backup password'),
      );
      expect(
        (await decodeBackup(
          BackupDecodeJob(encrypted, 'browser backup password'),
        ))['schema'],
        9,
      );
      await expectLater(
        decodeBackup(BackupDecodeJob(encrypted, 'incorrect password')),
        throwsFormatException,
      );
    },
  );
  test('browser map configuration persists independently of personal records and can be removed', () async {
    final store = WebOfflineMapStore();
    await store.clear();
    final region = OfflineRegion(
      id: 'browser-test',
      name: 'Local only',
      west: 8.39,
      east: 8.41,
      south: 46.69,
      north: 46.71,
    );
    await store.setRegions([region]);
    final reopened = WebOfflineMapStore();
    expect((await reopened.regions()).single.toJson(), region.toJson());
    expect(await reopened.tiles(), isEmpty);
    await reopened.clear();
    expect(await store.regions(), isEmpty);
    await store.close();
    await reopened.close();
  });
}
