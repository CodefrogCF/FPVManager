import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/spot_classification.dart';

part 'fpv_database.g.dart';

/// Locally stored FPV flying spots.
@TableIndex(name: 'spots_category_id', columns: {#categoryKey, #id})
@TableIndex(name: 'spots_favorite_id', columns: {#isFavorite, #id})
class Spots extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  // WGS84 coordinates in decimal degrees.
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();

  TextColumn get notes => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get categoryKey => text().withDefault(const Constant(''))();
  TextColumn get searchText => text().withDefault(const Constant(''))();

  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@TableIndex(name: 'spot_tags_tag_spot', columns: {#tag, #spotId})
class SpotTags extends Table {
  IntColumn get spotId =>
      integer().references(Spots, #id, onDelete: KeyAction.cascade)();
  TextColumn get tag => text().withLength(min: 1, max: 32)();
  @override
  Set<Column> get primaryKey => {spotId, tag};
}

/// Normalized local JPEGs, kept out of spot list and marker queries.
@TableIndex(name: 'spot_photos_spot_id', columns: {#spotId})
class SpotPhotos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get spotId =>
      integer().references(Spots, #id, onDelete: KeyAction.cascade)();
  BlobColumn get imageBytes => blob()();
  BlobColumn get thumbnailBytes => blob()();
  IntColumn get width => integer()();
  IntColumn get height => integer()();
}

/// User-owned FPV drones.
class Drones extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  TextColumn get type => text().withDefault(const Constant('quadcopter'))();

  RealColumn get takeoffWeightGrams => real().nullable()();

  RealColumn get maxSpeedMetersPerSecond => real().nullable()();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Individual batteries owned by the user.
class Batteries extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  TextColumn get chemistry => text().withDefault(const Constant('LiPo'))();

  IntColumn get cellCount => integer()();

  IntColumn get capacityMah => integer()();

  RealColumn get weightGrams => real().nullable()();

  IntColumn get cycleCount => integer().withDefault(const Constant(0))();

  TextColumn get notes => text().nullable()();
}

/// Radio control, telemetry and video equipment.
class RadioEquipment extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  TextColumn get category => text()();

  RealColumn get frequencyMhz => real().nullable()();

  RealColumn get maxPowerMw => real().nullable()();

  TextColumn get notes => text().nullable()();
}

/// Saved flight planning projects.
class FlightPlans extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  IntColumn get droneId => integer().nullable().references(
    Drones,
    #id,
    onDelete: KeyAction.setNull,
  )();

  IntColumn get startSpotId => integer().nullable().references(
    Spots,
    #id,
    onDelete: KeyAction.setNull,
  )();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Ordered positions belonging to a flight plan.
class FlightWaypoints extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get planId =>
      integer().references(FlightPlans, #id, onDelete: KeyAction.cascade)();

  IntColumn get sequenceNumber => integer()();

  RealColumn get latitude => real()();
  RealColumn get longitude => real()();

  /// Optional planned height.
  ///
  /// Must not be used for safety calculations
  /// without a verified height reference.
  RealColumn get heightMeters => real().nullable()();

  TextColumn get heightReference =>
      text().withDefault(const Constant('unverified'))();

  TextColumn get altitudeMode =>
      text().withDefault(const Constant('absolute'))();
}

/// Local application preferences.
class AppSettings extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Spots,
    SpotTags,
    SpotPhotos,
    Drones,
    Batteries,
    RadioEquipment,
    FlightPlans,
    FlightWaypoints,
    AppSettings,
  ],
)
class FpvDatabase extends _$FpvDatabase {
  /// Allows dependency injection for unit tests.
  FpvDatabase(super.executor);

  /// Persistent database for Android and Flutter Web.
  FpvDatabase.open()
    : super(
        driftDatabase(
          name: 'fpvmanager',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from > to) {
        throw StateError('Database downgrade is not supported');
      }

      if (from < 2) {
        await m.createTable(drones);
        await m.createTable(batteries);
        await m.createTable(radioEquipment);
        await m.createTable(flightPlans);
        await m.createTable(flightWaypoints);
        await m.createTable(appSettings);
      }
      if (from < 3) {
        await m.createTable(spotPhotos);
        await m.createIndex(spotPhotosSpotId);
      }
      if (from < 4) {
        await m.addColumn(spots, spots.category);
        await m.addColumn(spots, spots.categoryKey);
        await m.addColumn(spots, spots.searchText);
        await m.createTable(spotTags);
        await m.createIndex(spotTagsTagSpot);
        await m.createIndex(spotsCategoryId);
        await m.createIndex(spotsFavoriteId);
        // Dart lowercasing also handles non-ASCII case pairs in legacy text.
        // Backfill in bounded batches rather than materializing all spots.
        var afterId = 0;
        while (true) {
          final rows =
              await (select(spots)
                    ..where((table) => table.id.isBiggerThanValue(afterId))
                    ..orderBy([(table) => OrderingTerm.asc(table.id)])
                    ..limit(200))
                  .get();
          if (rows.isEmpty) break;
          await batch((batch) {
            for (final row in rows) {
              batch.update(
                spots,
                SpotsCompanion(
                  searchText: Value(
                    SpotClassification.searchText(
                      name: row.name,
                      notes: row.notes,
                    ),
                  ),
                ),
                where: (table) => table.id.equals(row.id),
              );
            }
          });
          afterId = rows.last.id;
        }
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
