import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'fpv_database.g.dart';

/// Locally stored FPV flying spots.
class Spots extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  // WGS84 coordinates in decimal degrees.
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();

  TextColumn get notes => text().nullable()();

  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Spots])
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
  int get schemaVersion => 1;
}
