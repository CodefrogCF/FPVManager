import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/flight_plan_repository.dart';
import 'package:fpvmanager/core/geo/altitude_service.dart';
import 'package:fpvmanager/core/geo/geo_coordinate_service.dart';
import 'package:fpvmanager/core/models/flight_route.dart';
import 'package:fpvmanager/core/models/signal_settings.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/routes/route_editor_controller.dart';
import 'package:fpvmanager/features/signal/radio_analysis_controller.dart';

import '../../helpers/fake_globe_renderer.dart';

void main() {
  late FpvDatabase db;
  late GlobeController globe;
  late FakeGlobeRenderer renderer;
  late RouteEditorController editor;
  late RadioAnalysisController controller;
  setUp(() async {
    db = FpvDatabase(NativeDatabase.memory());
    globe = GlobeController();
    renderer = FakeGlobeRenderer(globe)
      ..attach()
      ..ready();
    final repo = FlightPlanRepository(db),
        id = await repo.createFlightPlan(
          name: 'Route',
          waypoints: [
            for (final lon in [8.005, 8.006])
              RouteWaypointInput(
                position: Wgs84Coordinate(latitude: 47, longitude: lon),
                height: const AglWaypointHeight(AboveGroundHeight(50)),
              ),
          ],
        );
    editor = RouteEditorController(repository: repo, globe: globe, routeId: id);
    await editor.load();
    editor.configurePlanning(
      editor.planning.withSignal(
        const SignalSettings(
          pilot: Wgs84Coordinate(latitude: 47, longitude: 8),
        ),
      ),
    );
    controller = RadioAnalysisController(editor);
  });
  tearDown(() async {
    controller.dispose();
    editor.dispose();
    globe.dispose();
    await db.close();
  });
  test(
    'route edits cancel pending samples and cannot resurrect an old overlay',
    () async {
      final query = Completer<Map<String, dynamic>>();
      renderer.onCommand = (c) {
        if (c['type'] == 'query-route-terrain' && !query.isCompleted) {
          query.complete(c);
        }
      };
      final pending = controller.calculate(), command = await query.future;
      editor.configurePlanning(
        editor.planning.withSignal(
          const SignalSettings(
            pilot: Wgs84Coordinate(latitude: 47, longitude: 8),
            frequencyMhz: 2400,
          ),
        ),
      );
      renderer.acknowledge(
        command,
        result: {
          'heightReference': 'wgs84Ellipsoid',
          'samplingMethod': 'most-detailed',
          'heights': List.filled((command['positions'] as List).length, 500),
        },
      );
      await pending;
      expect(controller.result, isNull);
      expect(controller.loading, isFalse);
      expect(
        renderer.commands
            .where((c) => c['type'] == 'set-signal-analysis')
            .every((c) => (c['rays'] as List).isEmpty),
        isTrue,
      );
    },
  );
  test('sequential bounded queries display paths, then terrain failure clears them', () async {
    renderer.onCommand = (c) {
      if (c['type'] == 'query-route-terrain') {
        renderer.acknowledge(
          c,
          result: {
            'heightReference': 'wgs84Ellipsoid',
            'samplingMethod': 'most-detailed',
            'heights': List.filled((c['positions'] as List).length, 500),
          },
        );
      }
    };
    await controller.calculate();
    expect(controller.result, isNotEmpty);
    final overlay = renderer.commands.lastWhere(
      (c) => c['type'] == 'set-signal-analysis',
    );
    expect(overlay['rays'], isNotEmpty);
    renderer.emit({
      'type': 'terrain-status',
      'state': 'unavailable',
      'reason': 'connectionFailed',
    });
    await Future<void>.delayed(Duration.zero);
    expect(controller.result, isNull);
    expect(
      renderer.commands.lastWhere(
        (c) => c['type'] == 'set-signal-analysis',
      )['rays'],
      isEmpty,
    );
    await controller.calculate();
    expect(controller.error, isNotNull);
    expect(controller.result, isNull);
  });
}
