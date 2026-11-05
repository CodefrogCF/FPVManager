import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/geo/altitude_service.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/simulation/simulation_settings.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  test(
    'virtual route playback sends bounded route data and handles reload',
    () async {
      final db = FpvDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = FlightPlanRepository(db);
      final routeId = await repository.saveRoute(
        name: 'Replay fixture',
        waypoints: const [
          RouteWaypointInput(
            position: Wgs84Coordinate(latitude: 46.7, longitude: 8.4),
            height: AglWaypointHeight(AboveGroundHeight(20)),
            speedMetersPerSecond: 5,
          ),
          RouteWaypointInput(
            position: Wgs84Coordinate(latitude: 46.71, longitude: 8.41),
            height: AglWaypointHeight(AboveGroundHeight(30)),
          ),
        ],
      );
      final globe = GlobeController();
      addTearDown(globe.dispose);
      final renderer = FakeGlobeRenderer(globe)..attach();

      await expectLater(
        globe.startRoutePlayback(
          (await repository.getRoute(routeId))!,
          const SimulationSettings(),
        ),
        throwsStateError,
      );
      renderer.ready();
      await globe.startRoutePlayback(
        (await repository.getRoute(routeId))!,
        const SimulationSettings(cameraFovDegrees: 120),
      );
      final command = renderer.commands.lastWhere(
        (value) => value['type'] == 'start-route-playback',
      );
      expect(command['routeId'], routeId);
      expect((command['points'] as List).length, 2);
      expect((command['settings'] as Map)['cameraFovDegrees'], 120);

      renderer.emit({
        'type': 'route-playback-state',
        'phase': 'playing',
        'seconds': 2,
        'progress': .5,
      });
      expect(globe.playbackPhase, 'playing');
      expect(globe.playbackProgress, .5);
      await globe.controlRoutePlayback('pause');
      expect(renderer.commands.last['action'], 'pause');
      await globe.controlRoutePlayback('speed', speed: 2);
      expect(renderer.commands.last['speed'], 2);
      await expectLater(
        globe.controlRoutePlayback('speed', speed: 9),
        throwsArgumentError,
      );
      globe.rendererLoading();
      expect(globe.playbackPhase, 'idle');
      expect(globe.playbackProgress, 0);
    },
  );
}
