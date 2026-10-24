import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/drone_repository.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/globe/ground_view_button.dart';
import 'package:fpvmanager/features/simulation/simulation_settings.dart';
import 'package:fpvmanager/features/simulation/simulation_settings_sheet.dart';

import '../../helpers/fake_globe_renderer.dart';

final _drone = Drone(
  id: 1,
  name: 'Test quad',
  type: 'quadcopter',
  maxSpeedMetersPerSecond: 24,
  maxClimbRateMetersPerSecond: 8,
  createdAt: DateTime.utc(2026),
);

class _Drones implements DroneRepository {
  _Drones({this.fail = false});
  final bool fail;
  @override
  Future<List<Drone>> getAllDrones() async {
    if (fail) throw StateError('unavailable');
    return [_drone];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'profile selection uses recorded limits, defaults and supported bounds',
    () {
      final settings = SimulationSettings.fromDrone(_drone);
      expect(settings.maxSpeed, 24);
      expect(settings.climbSpeed, 8);
      expect(settings.acceleration, 6);
      expect(settings.toCommand().containsKey('droneId'), isFalse);
      for (final mode in SimulationFlightMode.values) {
        expect(
          SimulationSettings(flightMode: mode).toCommand()['flightMode'],
          mode.name,
        );
      }
      final missing = SimulationSettings.fromDrone(
        _drone.copyWith(
          maxSpeedMetersPerSecond: const Value(null),
          maxClimbRateMetersPerSecond: const Value(null),
        ),
      );
      expect(missing.maxSpeed, 15);
      expect(missing.climbSpeed, 5);
      expect(
        SimulationSettings.fromDrone(
          _drone.copyWith(
            maxSpeedMetersPerSecond: const Value(200),
            maxClimbRateMetersPerSecond: const Value(40),
          ),
        ).maxSpeed,
        100,
      );
      for (final invalid in [
        const SimulationSettings(agl: 0),
        const SimulationSettings(maxSpeed: double.nan),
        const SimulationSettings(climbSpeed: 31),
        const SimulationSettings(acceleration: 0),
        const SimulationSettings(deceleration: double.infinity),
        const SimulationSettings(acroThrustToWeight: 1),
        const SimulationSettings(acroThrustCurve: -.1),
        const SimulationSettings(acroMotorTimeConstant: double.nan),
        const SimulationSettings(acroTerminalVelocity: 121),
      ]) {
        expect(invalid.validate, throwsArgumentError);
      }
    },
  );

  test('Acro physics settings preserve independent parameters and compute level-hover throttle', () {
    const physics = SimulationSettings(
      flightMode: SimulationFlightMode.acro,
      acroThrustToWeight: 6,
      acroThrustCurve: .4,
      acroMotorTimeConstant: .08,
      acroTerminalVelocity: 45,
    );
    final command = physics.toCommand();
    expect(command['acroThrustToWeight'], 6);
    expect(command['acroThrustCurve'], .4);
    expect(command['acroMotorTimeConstant'], .08);
    expect(command['acroTerminalVelocity'], 45);
    expect(const SimulationSettings().acroHoverThrottle, .5);
    expect(const SimulationSettings(acroThrustCurve: 0).acroHoverThrottle, .25);
    final hover = physics.acroHoverThrottle;
    expect(6 * (.6 * hover + .4 * hover * hover), closeTo(1, 1e-12));
  });

  group('simulation bridge', () {
    late GlobeController globe;
    late FakeGlobeRenderer peer;
    setUp(() {
      globe = GlobeController();
      peer = FakeGlobeRenderer(globe)
        ..attach()
        ..ready();
    });
    tearDown(() => globe.dispose());
    test(
      'supports selection or camera target and rejects unsupported entry',
      () async {
        await globe.enterSimulation(
          const SimulationSettings(agl: 40),
          latitude: 47,
          longitude: 8,
        );
        expect(peer.commands.last, containsPair('latitude', 47));
        expect(peer.commands.last, containsPair('agl', 40));
        await globe.enterSimulation(const SimulationSettings());
        expect(peer.commands.last['type'], 'enter-simulation');
        expect(peer.commands.last.containsKey('latitude'), isFalse);
        for (final point in [(90.0, 8.0), (47.0, 181.0), (double.nan, 8.0)]) {
          await expectLater(
            globe.enterSimulation(
              const SimulationSettings(),
              latitude: point.$1,
              longitude: point.$2,
            ),
            throwsArgumentError,
          );
        }
        await expectLater(
          globe.enterSimulation(const SimulationSettings(), latitude: 47),
          throwsArgumentError,
        );
        peer.emit({
          'type': 'terrain-status',
          'state': 'unavailable',
          'reason': 'tileFailed',
        });
        await expectLater(
          globe.enterSimulation(const SimulationSettings()),
          throwsStateError,
        );
      },
    );
    test(
      'input requires active focused navigation and state resets on reload',
      () async {
        final frame = {'forward': 1.0};
        await globe.sendNavigationInput(frame);
        expect(peer.commands, isEmpty);
        peer.emit({
          'type': 'simulation-state',
          'active': true,
          'pending': false,
        });
        await globe.sendNavigationInput(frame);
        expect(peer.commands, isEmpty);
        peer.emit({'type': 'navigation-focus', 'focused': true});
        await globe.sendNavigationInput(frame);
        expect(peer.commands.single['type'], 'navigation-input');
        peer.emit({'type': 'navigation-focus', 'focused': 'invalid'});
        expect(globe.navigationFocused, isTrue);
        peer.emit({
          'type': 'simulation-state',
          'active': 'invalid',
          'pending': false,
        });
        expect(globe.simulationActive, isTrue);
        await globe.exitNavigation();
        expect(peer.commands.last['type'], 'exit-simulation');
        globe.rendererLoading();
        expect(globe.simulationActive, isFalse);
        expect(globe.navigationFocused, isFalse);
      },
    );
    test('walking reuses device input without enabling flight', () async {
      peer.emit({
        'type': 'ground-view-state',
        'active': true,
        'pending': false,
      });
      peer.emit({'type': 'navigation-focus', 'focused': true});
      await globe.sendNavigationInput({'right': .5});
      expect(peer.commands.single['type'], 'navigation-input');
      expect(globe.simulationActive, isFalse);
    });
    testWidgets(
      'shared map button cancels pending flight and exits active flight',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: GroundViewButton(controller: globe)),
          ),
        );
        peer.emit({
          'type': 'simulation-state',
          'active': false,
          'pending': true,
        });
        await tester.pump();
        await tester.tap(find.byTooltip('Cancel spawn'));
        await tester.pump();
        expect(peer.commands.last['type'], 'exit-simulation');
        peer.emit({
          'type': 'simulation-state',
          'active': true,
          'pending': false,
        });
        await tester.pump();
        await tester.tap(find.byTooltip('Return to globe'));
        await tester.pump();
        expect(peer.commands.last['type'], 'exit-simulation');
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });

  testWidgets(
    'compact settings choose profile, validate height and return explicit spawn parameters',
    (tester) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SimulationSettings? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  chosen = await showSimulationSettings(
                    context,
                    repository: _Drones(),
                    hasSelection: true,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byType(DropdownButtonFormField<SimulationFlightMode>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Acro · Mode 2, rate control').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test quad').last);
      await tester.pumpAndSettle();
      final fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(find.byKey(const ValueKey('simulation-speed')), findsNothing);
      expect(find.byKey(const ValueKey('simulation-climb')), findsNothing);
      await tester.ensureVisible(find.byType(TextFormField).first);
      await tester.enterText(find.byType(TextFormField).first, '0');
      await tester.scrollUntilVisible(
        find.text('Spawn in map'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Spawn in map'));
      await tester.pumpAndSettle();
      expect(chosen, isNull);
      fields.first.controller!.text = '35,5';
      await tester.ensureVisible(find.text('Spawn in map'));
      await tester.tap(find.text('Spawn in map'));
      await tester.pumpAndSettle();
      expect(chosen!.agl, 35.5);
      expect(chosen!.droneId, 1);
      expect(chosen!.flightMode, SimulationFlightMode.acro);
      expect(chosen!.maxSpeed, 24);
      expect(chosen!.climbSpeed, 8);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Acro tuning validates collapsed fields and returns physical parameters without changing assisted limits',
    (tester) async {
      SimulationSettings? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  chosen = await showSimulationSettings(
                    context,
                    repository: _Drones(),
                    hasSelection: false,
                    initial: const SimulationSettings(
                      flightMode: SimulationFlightMode.acro,
                      maxSpeed: 22,
                      climbSpeed: 7,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Estimated level hover: 50%'), findsOneWidget);
      await tester.ensureVisible(find.text('Acro physics'));
      await tester.tap(find.text('Acro physics'));
      await tester.pumpAndSettle();
      final thrust = find.byKey(
        const ValueKey('simulation-acroThrustToWeight'),
      );
      await tester.ensureVisible(thrust);
      await tester.enterText(thrust, '0');
      await tester.ensureVisible(find.text('Acro physics'));
      await tester.tap(find.text('Acro physics'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Spawn in map'));
      await tester.tap(find.text('Spawn in map'));
      await tester.pumpAndSettle();
      expect(chosen, isNull);
      expect(
        tester
            .widget<ExpansionTile>(find.byType(ExpansionTile))
            .controller!
            .isExpanded,
        isTrue,
      );
      await tester.ensureVisible(thrust);
      await tester.enterText(thrust, '6');
      for (final entry in [
        ('acroThrustCurve', '0.4'),
        ('acroMotorTimeConstant', '0.08'),
        ('acroTerminalVelocity', '45'),
      ]) {
        final field = find.byKey(ValueKey('simulation-${entry.$1}'));
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.$2);
      }
      await tester.ensureVisible(find.text('Spawn in map'));
      await tester.tap(find.text('Spawn in map'));
      await tester.pumpAndSettle();
      expect(chosen!.acroThrustToWeight, 6);
      expect(chosen!.acroThrustCurve, .4);
      expect(chosen!.acroMotorTimeConstant, .08);
      expect(chosen!.acroTerminalVelocity, 45);
      expect(chosen!.maxSpeed, 22);
      expect(chosen!.climbSpeed, 7);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'switching flight modes can save despite an invalid unused draft parameter',
    (tester) async {
      for (final source in [
        SimulationFlightMode.gps,
        SimulationFlightMode.acro,
      ]) {
        SimulationSettings? chosen;
        final target = source == SimulationFlightMode.gps
            ? SimulationFlightMode.acro
            : SimulationFlightMode.gps;
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(source),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    chosen = await showSimulationSettings(
                      context,
                      repository: _Drones(),
                      hasSelection: false,
                      initial: SimulationSettings(flightMode: source),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        if (source == SimulationFlightMode.acro) {
          await tester.ensureVisible(find.text('Acro physics'));
          await tester.tap(find.text('Acro physics'));
          await tester.pumpAndSettle();
        }
        final invalid = find.byKey(
          ValueKey(
            source == SimulationFlightMode.gps
                ? 'simulation-speed'
                : 'simulation-acroThrustToWeight',
          ),
        );
        await tester.ensureVisible(invalid);
        await tester.enterText(invalid, '');
        final mode = find.byType(DropdownButtonFormField<SimulationFlightMode>);
        await tester.ensureVisible(mode);
        await tester.tap(mode);
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .text(
                target == SimulationFlightMode.acro
                    ? 'Acro · Mode 2, rate control'
                    : 'GPS · assisted movement',
              )
              .last,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Spawn in map'));
        await tester.tap(find.text('Spawn in map'));
        await tester.pumpAndSettle();
        expect(chosen!.flightMode, target);
        expect(chosen!.validate, returnsNormally);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('unavailable profiles retain a usable manual settings form', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSimulationSettings(
                context,
                repository: _Drones(fail: true),
                hasSelection: false,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Drone profiles unavailable'), findsOneWidget);
    expect(find.textContaining('No selected point'), findsOneWidget);
    await tester.tap(find.byTooltip('Close simulation settings'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
