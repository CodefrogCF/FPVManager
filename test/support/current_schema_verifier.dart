import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';

/// Validates migrations against an independently created database at the
/// application's CURRENT schema version.
///
/// Historical fixtures are still created using drift's versioned snapshots.
/// The snapshots committed in `test/generated_migrations` currently stop at
/// v10; using `SchemaVerifier.migrateAndValidate(db, 10)` after upgrading to
/// schema v12 incorrectly compares the new schema to an older one.
///
/// This comparison checks all SQLite tables, their columns, foreign keys and
/// indexes. It doesn't replace drift's versioned snapshot generation; when
/// snapshots for v11/v12 are regenerated, prefer drift's SchemaVerifier.
/// Capture the current schema before opening a database under migration.
///
/// The reference database is closed before any migration tests run, avoiding
/// concurrent [FpvDatabase] instances (and Drift's multiple-database warning).
/// This snapshot is then reused by all tests in the same file.
Future<Map<String, Object?>> captureFreshCurrentSchema() async {
  final fresh = FpvDatabase(NativeDatabase.memory());
  try {
    return await _readSchema(fresh);
  } finally {
    await fresh.close();
  }
}

/// Validate a migrated schema against the previously captured fresh schema.
///
/// Do not create a second [FpvDatabase] here: even when using separate
/// in-memory connections, Drift warns about overlapping database instances.
Future<void> migrateAndValidateCurrentSchema(
  FpvDatabase migrated, {
  required Map<String, Object?> expectedSchema,
}) async {
  final actual = await _readSchema(migrated);
  expect(
    actual,
    expectedSchema,
    reason:
        'Migrated database differs from a fresh schema-v${migrated.schemaVersion} database',
  );
  expect(
    await migrated.customSelect('PRAGMA foreign_key_check').get(),
    isEmpty,
    reason: 'Migrated database contains broken foreign-key references',
  );
}

Future<Map<String, Object?>> _readSchema(FpvDatabase database) async {
  final version = await database
      .customSelect('PRAGMA user_version')
      .getSingle();
  final rows = await database.customSelect('''
      SELECT name, type, sql FROM sqlite_master
      WHERE name NOT LIKE 'sqlite_%'
        AND type IN ('table', 'view', 'trigger')
      ORDER BY type, name
    ''').get();

  final result = <String, Object?>{
    'user_version': version.read<int>('user_version'),
  };
  for (final row in rows) {
    final name = row.read<String>('name');
    final type = row.read<String>('type');
    if (type != 'table') {
      result['$type:$name'] = row.read<String>('sql');
      continue;
    }
    final identifier = '"${name.replaceAll('"', '""')}"';
    final columns = await database
        .customSelect('PRAGMA table_xinfo($identifier)')
        .get();
    final fks = await database
        .customSelect('PRAGMA foreign_key_list($identifier)')
        .get();
    final indexes = await database
        .customSelect('PRAGMA index_list($identifier)')
        .get();
    final indexSignatures = <String>[];
    for (final index in indexes) {
      final indexName = index.read<String>('name');
      final quoted = '"${indexName.replaceAll('"', '""')}"';
      final parts = await database
          .customSelect('PRAGMA index_xinfo($quoted)')
          .get();
      // `cid` is the ordinal of a column in the physical table. Historical
      // migrations may append columns in a different order than onCreate,
      // without changing the index's indexed columns or its semantics.
      // Compare stable column *names* and key order instead. Preserve the
      // special cid for rowid/expression entries, where no name exists.
      final keys =
          parts
              .where((part) => part.read<int>('key') == 1)
              .map(
                (part) => <Object?>[
                  part.read<int>('seqno'),
                  part.data['name'] ?? 'unnamed-cid:${part.data['cid']}',
                  part.data['desc'],
                  part.data['coll'],
                ],
              )
              .toList()
            ..sort((a, b) => (a[0] as int).compareTo(b[0] as int));
      // An expression index has no column name. Preserve its SQL definition
      // to avoid considering different expressions equivalent.
      String? expressionSql;
      if (parts.any(
        (part) => part.read<int>('key') == 1 && part.data['cid'] == -2,
      )) {
        final escapedIndexName = indexName.replaceAll("'", "''");
        final expressionIndex = await database
            .customSelect(
              "SELECT sql FROM sqlite_master WHERE type = 'index' AND name = '$escapedIndexName'",
            )
            .getSingleOrNull();
        expressionSql = expressionIndex?.read<String?>('sql');
      }
      indexSignatures.add(
        jsonEncode({
          'name': index.read<String>('origin') == 'c' ? indexName : null,
          'origin': index.read<String>('origin'),
          'unique': index.read<int>('unique'),
          'partial': index.read<int>('partial'),
          'columns': keys,
          'expressionSql': ?expressionSql,
        }),
      );
    }
    indexSignatures.sort();
    final columnSignatures = <String, Object?>{
      for (final c in columns)
        c.read<String>('name'): {
          'type': c.read<String>('type').toUpperCase(),
          'notnull': c.read<int>('notnull'),
          'default': c.data['dflt_value'],
          'primaryKey': c.read<int>('pk'),
          'hidden': c.read<int>('hidden'),
        },
    };
    final foreignKeys =
        fks
            .map(
              (f) => jsonEncode({
                'table': f.read<String>('table'),
                'from': f.read<String>('from'),
                'to': f.data['to'],
                'seq': f.read<int>('seq'),
                'onUpdate': f.read<String>('on_update'),
                'onDelete': f.read<String>('on_delete'),
                'match': f.read<String>('match'),
              }),
            )
            .toList()
          ..sort();
    result['table:$name'] = {
      'columns': columnSignatures,
      'foreignKeys': foreignKeys,
      'indexes': indexSignatures,
    };
  }
  return result;
}
