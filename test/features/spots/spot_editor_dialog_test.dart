import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/features/spots/data/spot_location_service.dart';
import 'package:fpvmanager/features/spots/data/spot_photo.dart';
import 'package:fpvmanager/features/spots/data/spot_photo_service.dart';
import 'package:fpvmanager/features/spots/data/spot_repository.dart';
import 'package:fpvmanager/features/spots/spot_editor_dialog.dart';

class _PhotoService implements SpotPhotoService {
  PreparedSpotPhoto? photo;
  int calls = 0;
  @override
  Future<PreparedSpotPhoto?> pickPhoto() async {
    calls++;
    return photo;
  }
}

class _LocationService implements SpotLocationService {
  int calls = 0;
  Future<SpotLocation> Function()? result;
  @override
  Future<SpotLocation> currentLocation() {
    calls++;
    return result!();
  }
}

void main() {
  late FpvDatabase database;
  late SpotRepository repository;
  late _PhotoService photos;
  late _LocationService location;
  late PreparedSpotPhoto photo;
  setUpAll(
    () =>
        photo = prepareSpotPhoto(img.encodeJpg(img.Image(width: 8, height: 4))),
  );
  setUp(() {
    database = FpvDatabase(NativeDatabase.memory());
    repository = SpotRepository(database);
    photos = _PhotoService()..photo = photo;
    location = _LocationService()
      ..result = () async => const SpotLocation(
        position: Wgs84Coordinate(latitude: 47.12345678, longitude: 8.12345678),
        accuracyMeters: 12,
      );
  });
  tearDown(() => database.close());

  Future<void> open(WidgetTester tester, {Spot? spot}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (context) => SpotEditorDialog(
                  repository: repository,
                  spot: spot,
                  photoService: photos,
                  locationService: location,
                ),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
  Future<void> tap(WidgetTester tester, String label) async {
    final target = find.text(label);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('save combines edited text, opt-in GPS and a local photo', (
    tester,
  ) async {
    await open(tester);
    expect(location.calls, 0);
    expect(photos.calls, 0);
    await tester.enterText(field('Spot name'), 'My local spot');
    await tap(tester, 'Use current location');
    expect(location.calls, 1);
    expect(
      tester.widget<TextField>(field('Latitude (WGS84)')).controller!.text,
      '47.12345678',
    );
    expect(find.textContaining('accuracy ±12 m'), findsOneWidget);
    await tap(tester, 'Add photo');
    expect(find.text('Photos (1/6)'), findsOneWidget);
    await tap(tester, 'Save');
    expect(find.text('Add Spot'), findsNothing);
    final spot = (await repository.getAllSpots()).single;
    expect(spot.latitude, 47.12345678);
    expect(await repository.getPhotos(spot.id), hasLength(1));
  });

  testWidgets('cancelling photo changes leaves stored photos intact', (
    tester,
  ) async {
    final id = await repository.createSpot(
      name: 'Original',
      latitude: 47,
      longitude: 8,
      photos: [photo],
    );
    await open(tester, spot: await repository.getSpot(id));
    await tester.ensureVisible(find.byTooltip('Remove photo 1'));
    await tester.tap(find.byTooltip('Remove photo 1'));
    await tester.pumpAndSettle();
    await tap(tester, 'Add photo');
    await tester.enterText(field('Spot name'), 'Discarded');
    await tap(tester, 'Cancel');
    expect((await repository.getSpot(id))!.name, 'Original');
    expect(await repository.getPhotos(id), hasLength(1));
  });

  testWidgets('permission errors preserve manual coordinates and edits', (
    tester,
  ) async {
    location.result = () async => throw const SpotLocationException(
      'Location access was denied. Enter coordinates manually.',
    );
    await open(tester);
    await tester.enterText(field('Spot name'), 'Manual spot');
    await tester.enterText(field('Latitude (WGS84)'), '46.5');
    await tester.enterText(field('Longitude (WGS84)'), '7.5');
    await tap(tester, 'Use current location');
    expect(find.textContaining('Location access was denied'), findsOneWidget);
    expect(
      tester.widget<TextField>(field('Latitude (WGS84)')).controller!.text,
      '46.5',
    );
    await tap(tester, 'Save');
    expect((await repository.getAllSpots()).single.longitude, 7.5);
  });

  testWidgets('late GPS result does not overwrite manual coordinate edits', (
    tester,
  ) async {
    final pending = Completer<SpotLocation>();
    location.result = () => pending.future;
    await open(tester);
    await tester.ensureVisible(find.text('Use current location'));
    await tester.tap(find.text('Use current location'));
    await tester.pump();
    await tester.enterText(field('Latitude (WGS84)'), '46.5');
    pending.complete(
      const SpotLocation(
        position: Wgs84Coordinate(latitude: 47, longitude: 8),
        accuracyMeters: 10,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(field('Latitude (WGS84)')).controller!.text,
      '46.5',
    );
    expect(find.textContaining('Your edits were kept'), findsOneWidget);
  });

  testWidgets('a failed save keeps the complete draft and can be retried', (
    tester,
  ) async {
    await database.customStatement(
      "CREATE TRIGGER fail_save BEFORE INSERT ON spots BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await open(tester);
    await tester.enterText(field('Spot name'), 'Retry me');
    await tap(tester, 'Use current location');
    await tap(tester, 'Add photo');
    await tap(tester, 'Save');
    expect(find.textContaining('Your edits are still here'), findsOneWidget);
    expect(find.text('Photos (1/6)'), findsOneWidget);
    await database.customStatement('DROP TRIGGER fail_save');
    await tap(tester, 'Save');
    final spot = (await repository.getAllSpots()).single;
    expect(spot.name, 'Retry me');
    expect(await repository.getPhotos(spot.id), hasLength(1));
  });

  testWidgets('closing a pending location request ignores its late result', (
    tester,
  ) async {
    final pending = Completer<SpotLocation>();
    location.result = () => pending.future;
    await open(tester);
    await tester.ensureVisible(find.text('Use current location'));
    await tester.tap(find.text('Use current location'));
    await tester.pump();
    await tap(tester, 'Cancel');
    pending.complete(
      const SpotLocation(
        position: Wgs84Coordinate(latitude: 47, longitude: 8),
        accuracyMeters: 10,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(await repository.getAllSpots(), isEmpty);
  });

  testWidgets(
    'small screens and the keyboard keep photos and actions reachable',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await open(tester);
      await tap(tester, 'Add photo');
      expect(find.text('Photos (1/6)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tap(tester, 'Cancel');
      expect(await repository.getAllSpots(), isEmpty);
    },
  );
}
