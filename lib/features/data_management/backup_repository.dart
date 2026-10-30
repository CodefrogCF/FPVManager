import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

import '../../core/database/fpv_database.dart';
import '../../core/database/repositories/user_preferences_repository.dart';
import '../../core/database/repositories/flight_plan_repository.dart';
import '../../core/models/route_planning_settings.dart';
import '../../core/models/spot_classification.dart';
import '../preflight/checklist.dart';
import 'backup_codec.dart';

/// Explicitly excludes secrets, consent and provider caches, including future
/// unknown settings. Those must never silently enter a portable export.
bool backupSetting(String key) =>
    const {
      'map.style',
      'map.uas.visible',
      'map.uas.fillOpacity',
      'map.spots.visible',
      'simulation.touchControls.visible',
      'map.roads.visible',
      'map.labels.visible',
      'map.roads.opacity',
      'map.scene.buildings',
      'map.scene.vegetation',
      'map.scene.lighting',
      'navigation.scene.buildings',
      'navigation.scene.vegetation',
      'map.overlayOrder',
      'map.obstacles.wms.visible',
      'map.obstacles.wms.opacity',
      'map.obstacles.vectors.visible',
      'map.obstacles.vectors.models',
      'map.obstacles.vectors.categories',
      'map.obstacles.hazards.visible',
      'map.obstacles.hazards.bufferMeters',
      'weather.settings.v1',
    }.contains(key) ||
    RegExp(r'^mobility\.access\.[1-9][0-9]*\.v1$').hasMatch(key);

class BackupRepository {
  const BackupRepository(this.database);
  final FpvDatabase database;

  Future<Uint8List> create({String? password}) async {
    final payload = await database.transaction(() async {
      final tables = <String, List<Map<String, dynamic>>>{};
      var total = 0, rows = 0, encodedSize = 8192;
      for (final table in database.allTables) {
        final name = table.actualTableName;
        final output = tables[name] = [];
        // Preflight sizes in SQLite before a BLOB is materialized in Dart.
        final sizes = await database
            .customSelect(
              'SELECT COUNT(*) AS n, '
              'COALESCE(SUM(${table.$columns.map((c) => 'COALESCE(length(CAST("${c.$name}" AS BLOB)),0)').join('+')}),0) AS size FROM "$name"',
            )
            .getSingle();
        rows += sizes.read<int>('n');
        total += sizes.read<int>('size');
        if (total > backupMaxBytes - 128 || rows > backupMaxRows) {
          throw const FormatException(
            'Personal data exceeds the portable backup limit (64 MiB / 100,000 rows)',
          );
        }
        for (var offset = 0; offset < sizes.read<int>('n'); offset += 100) {
          final batch = await database
              .customSelect(
                'SELECT * FROM "$name" LIMIT 100 OFFSET ?',
                variables: [Variable(offset)],
              )
              .get();
          for (final row in batch) {
            if (name == 'app_settings' &&
                !backupSetting(row.read<String>('key'))) {
              continue;
            }
            final converted = {
              for (final entry in row.data.entries)
                entry.key: entry.value is Uint8List
                    ? {'base64': base64Encode(entry.value as Uint8List)}
                    : entry.value,
            };
            encodedSize += utf8.encode(jsonEncode(converted)).length + 1;
            if (encodedSize > backupMaxBytes - 128) {
              throw const FormatException('Backup exceeds 64 MiB');
            }
            output.add(converted);
          }
        }
      }
      return Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'format': 'fpvmanager-backup',
            'version': 1,
            'schema': database.schemaVersion,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'tables': tables,
          }),
        ),
      );
    });
    return compute(encodeBackup, BackupEncodeJob(payload, password));
  }

  Future<Map<String, dynamic>> preview(
    Uint8List bytes, {
    String? password,
  }) async {
    final document = await compute(
      decodeBackup,
      BackupDecodeJob(bytes, password),
    );
    await _validate(document);
    return document;
  }

  Future<void> _validate(Map<String, dynamic> document) async {
    final schema = document['schema'];
    if (schema is! int || schema < 1 || schema > database.schemaVersion) {
      throw const FormatException('This backup needs a newer application');
    }
    final input = document['tables'] as Map;
    final tables = {for (final t in database.allTables) t.actualTableName: t};
    final requiredTables = <String>{
      'spots',
      if (schema >= 2) ...[
        'drones',
        'batteries',
        'radio_equipment',
        'flight_plans',
        'flight_waypoints',
        'app_settings',
      ],
      if (schema >= 3) 'spot_photos',
      if (schema >= 4) 'spot_tags',
      if (schema >= 5) 'drone_parameter_sources',
      if (schema >= 6) ...['battery_drones', 'battery_flight_plans'],
      if (schema >= 7) 'radio_equipment_drones',
      if (schema >= 9) ...['preflight_checklists', 'telemetry_flights'],
    };
    if (requiredTables.any((key) => !input.containsKey(key))) {
      throw const FormatException('Incomplete backup for its database version');
    }
    if (input.keys.any((key) => !tables.containsKey(key)) ||
        !input.containsKey('spots') ||
        (schema == database.schemaVersion &&
            input.keys.toSet().difference(tables.keys.toSet()).isNotEmpty)) {
      throw const FormatException('Invalid backup tables');
    }
    if (schema == database.schemaVersion &&
        tables.keys.any((k) => !input.containsKey(k))) {
      throw const FormatException('Incomplete current-version backup');
    }
    for (final entry in input.entries) {
      final name = entry.key as String;
      final info = await database
          .customSelect('PRAGMA table_info("$name")')
          .get();
      final columns = {for (final row in info) row.read<String>('name'): row};
      for (final raw in entry.value as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        if (row.isEmpty || row.keys.any((k) => !columns.containsKey(k))) {
          throw const FormatException('Invalid backup columns');
        }
        for (final e in row.entries) {
          final type = columns[e.key]!.read<String>('type').toUpperCase(),
              v = e.value;
          if (v == null) {
            if (columns[e.key]!.read<int>('notnull') == 1) {
              throw const FormatException('Required backup value is missing');
            }
          } else if (type == 'INTEGER'
              ? v is! int || v.abs() > 9007199254740991
              : type == 'REAL'
              ? v is! num || !v.isFinite
              : type == 'TEXT'
              ? v is! String
              : type == 'BLOB'
              ? v is! Map || v.length != 1 || v['base64'] is! String
              : true) {
            throw const FormatException('Invalid backup field type');
          }
          if (type == 'BLOB' &&
              v != null &&
              base64Decode((v as Map)['base64'] as String).length >
                  (name == 'telemetry_flights'
                      ? 4 * 1024 * 1024
                      : 1024 * 1024)) {
            throw const FormatException('Backup image exceeds the image limit');
          }
        }
        if (columns.containsKey('id') &&
            (row['id'] is! int || (row['id'] as int) <= 0)) {
          throw const FormatException('Invalid record identifier');
        }
        if (name == 'spot_photos') {
          for (final field in ['image_bytes', 'thumbnail_bytes']) {
            final encoded = row[field];
            if (encoded is! Map || encoded['base64'] is! String) {
              throw const FormatException('Missing backup image');
            }
            final bytes = base64Decode(encoded['base64'] as String),
                edge = field == 'image_bytes' ? 1600 : 256;
            if (bytes.length >
                (field == 'image_bytes' ? 1024 * 1024 : 64 * 1024)) {
              throw const FormatException('Image exceeds limit');
            }
            final info = image.JpegDecoder(maxPixels: edge * edge)
                .startDecode(bytes);
            if (info == null ||
                info.width < 1 ||
                info.height < 1 ||
                info.width > edge ||
                info.height > edge ||
                field == 'image_bytes' &&
                    (info.width != row['width'] ||
                        info.height != row['height'])) {
              throw const FormatException(
                'Invalid backup image dimensions or format',
              );
            }
          }
        }
        if (row['name'] case final String name) {
          if (name.trim().isEmpty || name.length > 120) {
            throw const FormatException('Invalid record name');
          }
        }
        for (final e in {'latitude': 90.0, 'longitude': 180.0}.entries) {
          if (row[e.key] case final num value) {
            if (!value.isFinite || value.abs() > e.value) {
              throw const FormatException('Invalid coordinates');
            }
          }
        }
        if (name == 'app_settings' &&
            (row['key'] is! String || !backupSetting(row['key'] as String))) {
          throw const FormatException(
            'Backup contains an unsupported or protected setting',
          );
        }
        for (final field in ['planning_json', 'items_json']) {
          if (row[field] case final String text) {
            validateBackupJsonText(text);
            if (field == 'items_json') decodeChecklist(text);
            if (field == 'planning_json') RoutePlanningSettings.decode(text);
          }
        }
        if (name == 'flight_waypoints') {
          FlightPlanRepository.validatePersistedWaypoint(
            FlightWaypoint(
              id: row['id'] as int,
              planId: row['plan_id'] as int,
              sequenceNumber: row['sequence_number'] as int,
              latitude: (row['latitude'] as num).toDouble(),
              longitude: (row['longitude'] as num).toDouble(),
              heightMeters: (row['height_meters'] as num?)?.toDouble(),
              speedMetersPerSecond: (row['speed_meters_per_second'] as num?)
                  ?.toDouble(),
              heightReference:
                  row['height_reference'] as String? ?? 'unverified',
              altitudeMode: row['altitude_mode'] as String? ?? 'absolute',
            ),
          );
        }
        if (name == 'app_settings' &&
            (row['key'] == 'weather.settings.v1' ||
                (row['key'] as String).startsWith('mobility.access.'))) {
          validateBackupJsonText(row['value'] as String);
        }
        if (name == 'app_settings' &&
            [
              'map.overlayOrder',
              'map.obstacles.vectors.categories',
            ].contains(row['key'])) {
          validateBackupJsonText(row['value'] as String, expectList: true);
        }
      }
    }
    UserPreferencesRepository.validatePersistedRows([
      for (final row in input['app_settings'] as List? ?? [])
        AppSetting(
          key: (row as Map)['key'] as String,
          value: row['value'] as String,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
    ]);
    final sequences = <int, Set<int>>{};
    for (final row in input['flight_waypoints'] as List? ?? []) {
      if (!(sequences[row['plan_id'] as int] ??= {}).add(
        row['sequence_number'] as int,
      )) {
        throw const FormatException('Duplicate waypoint sequence');
      }
    }
    for (final sequence in sequences.values) {
      if (!sequence.contains(0) ||
          sequence.reduce((a, b) => a > b ? a : b) != sequence.length - 1) {
        throw const FormatException('Incomplete waypoint sequence');
      }
    }
  }

  /// Whole personal-database replacement; caller obtains explicit confirmation
  /// after preview. Any validation/SQL/FK failure rolls the complete change back.
  Future<void> restore(Map<String, dynamic> document) async {
    await _validate(document);
    final input = document['tables'] as Map;
    await database.transaction(() async {
      await database.customStatement('PRAGMA defer_foreign_keys=ON');
      for (final table in database.allTables.toList().reversed) {
        if (table.actualTableName == 'app_settings') {
          final current = await database.select(database.appSettings).get();
          for (final row in current.where((r) => backupSetting(r.key))) {
            await (database.delete(
              database.appSettings,
            )..where((t) => t.key.equals(row.key))).go();
          }
        } else {
          await database.customStatement(
            'DELETE FROM "${table.actualTableName}"',
          );
        }
      }
      for (final table in database.allTables) {
        final name = table.actualTableName;
        for (final raw in (input[name] as List? ?? [])) {
          final row = Map<String, dynamic>.from(raw as Map);
          // Earlier database versions omitted these derived display indexes.
          if (name == 'spots' && (document['schema'] as int) < 4) {
            row['category_key'] = '';
            row['search_text'] = SpotClassification.searchText(
              name: row['name'] as String,
              notes: row['notes'] as String?,
            );
          }
          final values = [
            for (final v in row.values)
              v is Map ? base64Decode(v['base64'] as String) : v,
          ];
          await database.customStatement(
            'INSERT INTO "$name" (${row.keys.map((k) => '"$k"').join(',')}) VALUES (${List.filled(row.length, '?').join(',')})',
            values,
          );
        }
      }
      if ((await database.customSelect('PRAGMA foreign_key_check').get())
          .isNotEmpty) {
        throw const FormatException('Backup contains broken record references');
      }
    });
    database.notifyUpdates({
      for (final t in database.allTables) TableUpdate.onTable(t),
    });
  }
}
