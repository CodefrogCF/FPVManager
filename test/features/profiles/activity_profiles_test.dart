import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/models/activity_profile.dart';
import 'package:fpvmanager/core/models/user_preferences.dart';
import 'package:fpvmanager/features/data_management/backup_repository.dart';
import 'package:fpvmanager/features/profiles/activity_profiles_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('portable profiles round-trip config with a fresh identity and no personal data', () {
    final source = activityProfileTemplates().first;
    final text = encodeActivityProfile(source);
    final imported = decodeActivityProfile(text);
    expect(imported.id, isNot(source.id));
    expect(imported.toJson(portable: true), source.toJson(portable: true));
    expect((jsonDecode(text) as Map)['profile'], isNot(contains('id')));
    expect(text, isNot(contains('apiKey')));
    expect(text, isNot(contains('spots')));
  });

  test('imports reject credentials, future versions, unknown modules, duplicates and excessive nesting', () {
    final original = jsonDecode(
      encodeActivityProfile(activityProfileTemplates().first),
    ) as Map<String, dynamic>;
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (m) => m['token'] = 'SECRET',
      (m) => m['version'] = 2,
      (m) => (m['profile'] as Map)['apiKey'] = 'SECRET',
      (m) => ((m['profile'] as Map)['map'] as Map)['locationEnabled'] = true,
      (m) => (m['profile'] as Map)['tools'] = ['unimplementedHikingRouter'],
      (m) => (m['profile'] as Map)['actions'] = ['search', 'search'],
      (m) => (m['profile'] as Map)['name'] = '',
      (m) => ((m['profile'] as Map)['map'] as Map)['savedPlaces'] = 'true',
    ]) {
      final candidate =
          jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
      mutate(candidate);
      expect(
        () => decodeActivityProfile(jsonEncode(candidate)),
        throwsFormatException,
      );
    }
    expect(
      () => decodeActivityProfile('${'[' * 30}0${']' * 30}'),
      throwsFormatException,
    );
    expect(
      () => decodeActivityProfile(' ' * (activityProfileMaxBytes + 1)),
      throwsFormatException,
    );
    expect(() => decodeActivityProfile('{'), throwsFormatException);
  });

  test('catalogue rejects dangling selections, duplicate IDs and too many profiles', () {
    final p = activityProfileTemplates().first;
    for (final c in [
      ActivityProfileCatalog(profiles: [p], selectedId: 'missing'),
      ActivityProfileCatalog(profiles: [p, p]),
      ActivityProfileCatalog(
        profiles: List.generate(33, (i) => p.copyWith(id: '$i')),
      ),
    ]) {
      expect(
        () => ActivityProfileCatalog.decode(c.encode()),
        throwsFormatException,
      );
    }
  });

  test('create edit duplicate select skip delete persist across a real database reopen', () async {
    final directory = await Directory.systemTemp.createTemp(
      'fpv-activity-profiles-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/profiles.sqlite');
    var db = FpvDatabase(NativeDatabase(file));
    var c = ActivityProfilesController(ActivityProfilesRepository(db));
    await c.load();
    expect(c.catalog!.firstUseDone, isFalse);
    final custom = ActivityProfile(
      id: 'custom',
      name: 'Abendrunde',
      tools: [ActivityTool.places],
      map: const ActivityMapDefaults(style: GlobeMapStyle.relief),
    );
    await c.put(custom);
    await c.put(custom.copyWith(name: 'Bergtour'));
    final duplicate = custom.copyWith(id: 'copy', name: 'Kopie');
    await c.put(duplicate);
    await c.select('custom');
    c.dispose();
    await db.close();
    db = FpvDatabase(NativeDatabase(file));
    c = ActivityProfilesController(ActivityProfilesRepository(db));
    await c.load();
    expect(c.selected!.name, 'Bergtour');
    expect(c.catalog!.firstUseDone, isTrue);
    expect(c.selected!.map.style, GlobeMapStyle.relief);
    await c.select(null);
    expect(c.selected, isNull);
    await c.select('custom');
    await c.remove('custom');
    expect(c.selected, isNull);
    expect(c.catalog!.profiles.any((p) => p.id == 'copy'), isTrue);
    c.dispose();
    await db.close();
  });

  test(
    'failed storage retains previous catalogue and supports recovery',
    () async {
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = _FailingRepository(db);
      final c = ActivityProfilesController(repository);
      addTearDown(c.dispose);
      await c.load();
      repository.fail = true;
      await expectLater(c.select('fpv'), throwsStateError);
      expect(c.selected, isNull);
      expect(c.error, isNotNull);
      repository.fail = false;
      await c.select('fpv');
      expect(c.selected!.id, 'fpv');
      expect(c.error, isNull);
      await db.customStatement(
        'UPDATE app_settings SET value = ? WHERE key = ?',
        ['{}', activityProfilesKey],
      );
      final reopened = ActivityProfilesController(
        ActivityProfilesRepository(db),
      );
      addTearDown(reopened.dispose);
      await reopened.load();
      expect(reopened.catalog, isNull);
      expect(reopened.error, isNotNull);
      await repository.save(c.catalog!);
      await reopened.load();
      expect(reopened.selected!.id, 'fpv');
    },
  );

  test('personal backups restore profiles and selection; invalid profile rows reject atomically', () async {
    final db = FpvDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final profiles = ActivityProfilesController(ActivityProfilesRepository(db));
    addTearDown(profiles.dispose);
    await profiles.load();
    await profiles.select('hiking');
    await db.customStatement(
      "INSERT INTO spots(name,latitude,longitude) VALUES('Keep me',46.8,8.3)",
    );
    final backup = BackupRepository(db);
    final document = await backup.preview(await backup.create());
    final settings = (document['tables'] as Map)['app_settings'] as List;
    expect(settings.any((r) => r['key'] == activityProfilesKey), isTrue);
    await profiles.select('fpv');
    await backup.restore(document);
    await profiles.load();
    expect(profiles.selected!.id, 'hiking');
    final bad = jsonDecode(jsonEncode(document)) as Map<String, dynamic>;
    for (final row in (bad['tables'] as Map)['app_settings'] as List) {
      if (row['key'] == activityProfilesKey) row['value'] = '{"version":999}';
    }
    await expectLater(backup.restore(bad), throwsFormatException);
    expect((await db.select(db.spots).get()).single.name, 'Keep me');
    expect((await ActivityProfilesRepository(db).load()).selectedId, 'hiking');
    settings.removeWhere((r) => r['key'] == activityProfilesKey);
    await backup.restore(document);
    expect((await ActivityProfilesRepository(db).load()).firstUseDone, isFalse);
  });
}

class _FailingRepository extends ActivityProfilesRepository {
  _FailingRepository(super.database);
  bool fail = false;
  @override
  Future<void> save(ActivityProfileCatalog catalog) async {
    if (fail) throw StateError('storage unavailable');
    return super.save(catalog);
  }
}
