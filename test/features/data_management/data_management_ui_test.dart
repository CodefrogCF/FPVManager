import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/data_management/backup_codec.dart';
import 'package:fpvmanager/features/data_management/backup_file_service.dart';
import 'package:fpvmanager/features/data_management/data_management_screen.dart';
import 'package:fpvmanager/features/offline/offline_region.dart';

class MemoryMaps implements OfflineMapStorage {
  @override
  bool get rendererReady => true;
  List<OfflineRegion> values = [];
  @override
  Future<List<OfflineRegion>> regions() async => values;
  @override
  Future<List<OfflineTileInfo>> tiles() async => [];
  @override
  Future<void> setRegions(List<OfflineRegion> regions) async {
    values = regions;
  }

  @override
  Future<void> clear() async {
    values = [];
  }

  @override
  Future<void> close() async {}
}

class MemoryBackupFiles extends BackupFileService {
  final saved = Completer<Uint8List>();
  @override
  Future<bool> save(Uint8List bytes) async {
    saved.complete(bytes);
    return true;
  }
}

void main() {
  testWidgets(
    'offline controls and password choice fit a narrow screen; unprotected export is explicit',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FpvDatabase(NativeDatabase.memory()),
          files = MemoryBackupFiles(),
          maps = MemoryMaps();
      addTearDown(db.close);
      await tester.runAsync(() => db.customSelect('SELECT 1').get());
      await tester.pumpWidget(
        MaterialApp(
          home: DataManagementScreen(
            database: db,
            files: files,
            offlineStorage: maps,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final add = find.text('Add offline region');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      final save = find.text('Save region for caching');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(maps.values, hasLength(1));
      expect(tester.takeException(), isNull);
      final encrypt = find.widgetWithText(
        SwitchListTile,
        'Protect backup with a password',
      );
      await tester.scrollUntilVisible(
        encrypt,
        250,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 40,
      );
      await tester.pumpAndSettle();
      await tester.tap(encrypt);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Unprotected backups contain readable'),
        findsOneWidget,
      );
      final create = find.text('Create backup');
      await tester.scrollUntilVisible(
        create,
        200,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 40,
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(create));
      for (
        var attempt = 0;
        attempt < 150 && !files.saved.isCompleted;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(
        files.saved.isCompleted,
        isTrue,
        reason:
            'Export should complete; error feedback: ${find.textContaining('Operation failed').evaluate().length}',
      );
      final bytes = await files.saved.future;
      await tester.pumpAndSettle();
      expect(bytes, isNotNull);
      expect(isEncryptedBackup(bytes), isFalse);
      expect(
        find.text('Backup exported. Keep it in a safe location.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Android backups use the document destination without a storage permission',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('com.codefrog.fpvmanager/route_files');
      MethodCall? call;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (value) async {
            call = value;
            return false;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      expect(
        await const BackupFileService().save(Uint8List.fromList([1, 2, 3])),
        isFalse,
      );
      expect(call!.method, 'saveBackup');
      expect((call!.arguments as Map)['mimeType'], 'application/octet-stream');
      expect((call!.arguments as Map)['name'], endsWith('.fpvbackup'));
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
