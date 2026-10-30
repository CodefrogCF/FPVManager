import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/features/data_management/backup_repository.dart';
import 'package:fpvmanager/features/ground_routes/ground_route.dart';
import 'package:fpvmanager/features/ground_routes/ground_gpx.dart';
import 'package:fpvmanager/features/ground_routes/ground_route_repository.dart';
import 'package:fpvmanager/features/ground_routes/ground_router.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v9.dart' as v9;

GroundRoutePlan sample({GroundTravelMode mode = GroundTravelMode.walking}) =>
    GroundRoutePlan(
      name: 'Alte Brücke',
      mode: mode,
      points: [MobilityPoint(47, 8), MobilityPoint(47.01, 8.02)],
      origin: MobilityPoint(47, 8),
      destination: MobilityPoint(47.01, 8.02),
      source: 'OSRM / FOSSGIS · OSM',
      calculatedAtUtc: DateTime.utc(2026, 10, 30, 12),
      distanceMeters: 2200,
      durationSeconds: 1800,
      attributes: {'surface': null, 'access': null},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('walking and cycling use their own documented routing profile and coalesce duplicates', () async {
    var time = DateTime.utc(2026, 10, 30, 12), calls = 0;
    final router = GroundRouter(
      now: () => time,
      client: MockClient((r) async {
        calls++;
        expect(r.url.host, 'routing.openstreetmap.de');
        expect(r.url.queryParameters['geometries'], 'geojson');
        expect(
          r.url.path,
          calls == 1
              ? contains('/routed-foot/route/v1/foot/')
              : contains('/routed-bike/route/v1/bike/'),
        );
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'distance': 2200,
                'duration': 1800,
                'weight_name': 'duration',
                'geometry': {
                  'type': 'LineString',
                  'coordinates': [
                    [8, 47],
                    [8.02, 47.01],
                  ],
                },
              },
            ],
            'waypoints': [
              {
                'location': [8, 47],
              },
              {
                'location': [8.02, 47.01],
              },
            ],
          }),
          200,
        );
      }),
    );
    addTearDown(router.dispose);
    final first = router.calculate(
          sample().origin,
          sample().destination,
          GroundTravelMode.walking,
        ),
        second = router.calculate(
          sample().origin,
          sample().destination,
          GroundTravelMode.walking,
        );
    expect(identical(first, second), isTrue);
    final walk = await first;
    await second;
    expect(calls, 1);
    expect(walk.mode, GroundTravelMode.walking);
    expect(walk.calculatedAtUtc, time);
    expect(walk.attributes['surface'], isNull);
    expect(walk.elevations, isNull);
    time = time.add(const Duration(seconds: 2));
    final bike = await router.calculate(
      sample().origin,
      sample().destination,
      GroundTravelMode.cycling,
    );
    expect(bike.mode, GroundTravelMode.cycling);
    expect(bike.attributes['profile'], 'bike');
  });
  test('GPX preserves mode, endpoints, provenance, original heights and separate track segments', () {
    for (final mode in GroundTravelMode.values) {
      final original = sample(mode: mode);
      final preview = decodeGroundGpx((
        encodeGroundGpx(original),
        GroundTravelMode.walking,
      ));
      final imported = preview.routes.single;
      expect(imported.mode, mode);
      expect(imported.origin.toJson(), original.origin.toJson());
      expect(imported.source, original.source);
      expect(imported.calculatedAtUtc, original.calculatedAtUtc);
      expect(
        imported.points.map((p) => p.toJson()),
        original.points.map((p) => p.toJson()),
      );
      expect(imported.elevations, isNull);
    }
    final bytes = Uint8List.fromList(
      utf8.encode(
        '<gpx version="1.1"><trk><name>Tour</name><type>custom-activity</type><trkseg><trkpt lat="47" lon="8"><ele>0</ele></trkpt><trkpt lat="47.01" lon="8.02"><ele>412.3</ele></trkpt></trkseg><trkseg><trkpt lat="47.2" lon="8.2"/><trkpt lat="47.3" lon="8.3"/></trkseg></trk></gpx>',
      ),
    );
    final imported = decodeGroundGpx((bytes, GroundTravelMode.cycling));
    expect(imported.routes, hasLength(2));
    expect(imported.warnings, isNotEmpty);
    expect(imported.routes.first.elevations, [0, 412.3]);
    expect(
      imported.routes.first.attributes['elevationReference'],
      contains('datum not supplied'),
    );
    expect(
      imported.routes.first.attributes['originalGpxType'],
      'custom-activity',
    );
    expect(imported.routes.first.calculatedAtUtc, isNull);
  });
  test('GPX rejects external entities, unsupported versions, invalid points and incomplete segments', () {
    for (final text in [
      '<!DOCTYPE gpx [<!ENTITY remote SYSTEM "https://example.org/data">]><gpx/>',
      '<gpx version="2.0"/>',
      '<gpx><rte><rtept lat="NaN" lon="8"/><rtept lat="47" lon="8"/></rte></gpx>',
      '<gpx><trk><trkseg><trkpt lat="47" lon="8"/></trkseg></trk></gpx>',
    ]) {
      expect(
        () => decodeGroundGpx((
          Uint8List.fromList(utf8.encode(text)),
          GroundTravelMode.walking,
        )),
        throwsFormatException,
      );
    }
  });
  test('ground routes survive a file-backed restart and portable backup without becoming flight plans', () async {
    final directory = await Directory.systemTemp.createTemp(
      'fpv-ground-routes-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/personal.sqlite');
    var db = FpvDatabase(NativeDatabase(file)),
        repo = GroundRouteRepository(db);
    final id = await repo.save(sample());
    await repo.save(sample(mode: GroundTravelMode.cycling));
    expect((await repo.watch().first).length, 2);
    expect(await db.select(db.flightPlans).get(), isEmpty);
    final backup = BackupRepository(db),
        doc = await backup.preview(await backup.create());
    expect((doc['tables'] as Map)['ground_routes'], hasLength(2));
    await db.close();
    db = FpvDatabase(NativeDatabase(file));
    repo = GroundRouteRepository(db);
    expect((await repo.read(id))!.mode, GroundTravelMode.walking);
    await repo.delete(id);
    await BackupRepository(db).restore(doc);
    expect((await repo.read(id))!.source, sample().source);
    final tampered = jsonDecode(jsonEncode(doc)) as Map<String, dynamic>;
    ((tampered['tables'] as Map)['ground_routes'] as List).first['mode'] =
        'drone';
    await expectLater(
      BackupRepository(db).restore(tampered),
      throwsFormatException,
    );
    expect((await repo.read(id))!.name, 'Alte Brücke');
    await db.close();
  });
  test('schema v9 planning data survives addition of the independent ground-route table', () async {
    final verifier = SchemaVerifier(GeneratedHelper()),
        schema = await verifier.schemaAt(9),
        old = v9.DatabaseAtV9(schema.newConnection());
    final id = await old
        .into(old.flightPlans)
        .insert(
          v9.FlightPlansCompanion.insert(
            name: 'Existing flight',
            planningJson: const Value('{}'),
          ),
        );
    await old.close();
    final db = FpvDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 10);
    expect((await db.select(db.flightPlans).getSingle()).id, id);
    expect(await db.select(db.groundRoutes).get(), isEmpty);
  });
}
