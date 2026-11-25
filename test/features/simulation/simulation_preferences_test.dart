import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/database/fpv_database.dart';
import 'package:fpvmanager/core/database/repositories/user_preferences_repository.dart';
import 'package:fpvmanager/core/models/scene_time.dart';
import 'package:fpvmanager/core/models/user_preferences.dart';
import 'package:fpvmanager/features/data_management/backup_repository.dart';
import 'package:fpvmanager/features/globe/globe_controller.dart';
import 'package:fpvmanager/features/simulation/controller_settings.dart';
import 'package:fpvmanager/features/simulation/failsafe_settings.dart';
import 'package:fpvmanager/features/simulation/signal_hud_settings.dart';
import 'package:fpvmanager/features/simulation/simulation_aerodynamics_settings.dart';
import 'package:fpvmanager/features/simulation/simulation_battery_profile.dart';
import 'package:fpvmanager/features/simulation/simulation_collision_settings.dart';
import 'package:fpvmanager/features/simulation/simulation_descent_aerodynamics_settings.dart';
import 'package:fpvmanager/features/simulation/simulation_propulsion_profile.dart';
import 'package:fpvmanager/features/simulation/simulation_rotation_settings.dart';
import 'package:fpvmanager/features/simulation/simulation_settings.dart';

import '../../helpers/fake_globe_renderer.dart';

SimulationSettings chosen(SimulationPhysicsModel physics) => SimulationSettings(
  agl: 45,
  maxSpeed: 32,
  climbSpeed: 7,
  acceleration: 9,
  deceleration: 8,
  droneId: 2,
  flightMode: SimulationFlightMode.acro,
  physicsModel: physics,
  physicsStepHz: 240,
  cameraTiltDegrees: 24,
  cameraFovDegrees: 110,
  graphicsProfile: SimulationGraphicsProfile.quality,
  hudStyle: SimulationHudStyle.betaflight,
  showCoordinates: true,
  signalHud: const SignalHudSettings(
    djiWarning: false,
    betaflightBars: false,
    analogNoise: true,
    terrainIllustration: true,
    weakThreshold: .6,
    criticalThreshold: .3,
    lostThreshold: .1,
    analogIntensity: .8,
  ),
  failsafe: const FailsafeSettings(
    enabled: true,
    mode: 'gpsRescue',
    lossThreshold: .15,
    recoveryThreshold: .5,
    activationDelaySeconds: 3,
    recoveryDelaySeconds: 4,
    rescueAltitudeMeters: 80,
    returnSpeedMetersPerSecond: 12,
    climbSpeedMetersPerSecond: 6,
    autoRecover: true,
  ),
  showBatteryVoltage: true,
  showBatteryCellVoltage: true,
  lowBatteryCellVoltage: 3.4,
  criticalBatteryCellVoltage: 3.1,
  batterySagResistanceOhmsPerCell: .012,
  batteryUseChemistryThresholds: false,
  batteryProfile: const SimulationBatteryProfile(
    batteryId: 4,
    cellCount: 6,
    capacityMah: 1600,
    chemistry: 'LiPo',
    chargePercent: 75,
    nominalVoltageVolts: 22.2,
    energyWh: 35.52,
    continuousDischargeC: 40,
    burstDischargeC: 60,
    burstDurationSeconds: 5,
    internalResistanceMilliOhmsPerCell: 12,
    hoverPowerWatts: 180,
    cruisePowerWatts: 250,
    cruiseSpeedMetersPerSecond: 15,
    maxPowerWatts: 1200,
    motorCount: 4,
    escContinuousCurrentAmpsPerChannel: 45,
    motorContinuousCurrentAmpsPerMotor: 35,
    maxSpeedMetersPerSecond: 45,
    takeoffWeightGrams: 800,
  ),
  propulsionProfile: const SimulationPropulsionProfile(
    motorKv: 1700,
    motorCount: 4,
    propellerDiameterInches: 7,
    propellerPitchInches: 4,
    propellerDescription: '7x4x3',
    takeoffWeightGrams: 800,
    referenceVoltageVolts: 22.2,
    maxPowerWatts: 1200,
    escContinuousCurrentAmpsPerChannel: 45,
    motorContinuousCurrentAmpsPerMotor: 35,
    bladeCount: 3,
    rpmEfficiency: .8,
    propellerEfficiency: .7,
    motorTimeConstantSeconds: .05,
    manufacturerCurve: [
      {'rpm': 1000, 'thrust': 20},
    ],
  ),
  controller: const ControllerSettings(
    layout: ControllerLayout.radio,
    throttleZero: ControllerThrottleZero.bottom,
    rollAxis: 4,
    pitchAxis: 5,
    throttleAxis: 6,
    yawAxis: 7,
    invertRoll: true,
    invertPitch: true,
    invertThrottle: true,
    invertYaw: true,
  ),
  acroThrustToWeight: 5,
  acroThrustCurve: .8,
  acroMotorTimeConstant: .07,
  acroTerminalVelocity: 35,
  acroRollRate: 420,
  acroPitchRate: 430,
  acroYawRate: 250,
  acroRateExpo: .3,
  aerodynamics: const SimulationAerodynamicsSettings(
    preset: SimulationAerodynamicsPreset.custom,
    forward: .4,
    backward: .6,
    lateral: .8,
    vertical: 1.2,
    propeller: .2,
    propellerDragEnabled: false,
  ),
  rotation: const SimulationRotationSettings(
    rateProfile: SimulationRateProfile.linear,
    superRate: .6,
    rollInertiaKgM2: .02,
    pitchInertiaKgM2: .025,
    yawInertiaKgM2: .04,
    rollTorqueNm: 1.2,
    pitchTorqueNm: 1.3,
    yawTorqueNm: .5,
    rollAccelerationLimitDegs2: 4100,
    pitchAccelerationLimitDegs2: 4200,
    yawAccelerationLimitDegs2: 2400,
    controllerGainPerSecond: 18,
    motorResponseTimeConstantSeconds: .04,
    passiveDampingPerSecond: .2,
    airModeEnabled: false,
    airModeIdleCommand: .16,
  ),
  descentAerodynamics: const SimulationDescentAerodynamicsSettings(
    groundEffectEnabled: true,
    propwashEnabled: true,
    vortexRingEnabled: true,
    groundEffectIntensity: .8,
    propwashIntensity: .7,
    vortexRingIntensity: .6,
    rotorDiameterMeters: .2,
  ),
  collisionResponse: const SimulationCollisionSettings(
    mode: SimulationCollisionMode.hardStop,
    restitution: .2,
    friction: .3,
    hardStopNormalSpeedMs: 25,
    minimumReboundSpeedMs: 2,
    terrainProbeMeters: .8,
    assistedLanding: false,
  ),
  sceneTime: SceneTime(enabled: true, fixedUtc: DateTime.utc(2026, 6, 3, 14)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final physics in SimulationPhysicsModel.values) {
    test(
      'complete $physics settings survive JSON without changing flight commands',
      () {
        final settings = chosen(physics);
        final restored = SimulationSettings.fromJson(
          jsonDecode(jsonEncode(settings.toJson())),
        );
        expect(restored.toJson(), settings.toJson());
        expect(restored.toCommand(), settings.toCommand());
        expect(restored.droneId, 2);
        expect(restored.toCommand().containsKey('droneId'), false);
      },
    );
  }

  test('older partial configurations use defaults only for missing fields', () {
    expect(
      SimulationSettings.fromJson(<String, dynamic>{}).toJson(),
      const SimulationSettings().toJson(),
    );
    final settings = SimulationSettings.fromJson({
      'maxSpeed': 30,
      'physicsModel': 'legacy',
      'rotation': {'superRate': .4},
      'futureOption': true,
    });
    expect(settings.maxSpeed, 30);
    expect(settings.physicsModel, SimulationPhysicsModel.legacy);
    expect(settings.rotation.superRate, .4);
    expect(settings.rotation.rollTorqueNm, 1);
  });

  test(
    'invalid stored simulator data is rejected instead of resetting silently',
    () {
      for (final raw in <Object?>[
        null,
        [],
        {'maxSpeed': '30'},
        {'maxSpeed': double.nan},
        {'physicsModel': 'unknown'},
        {'physicsStepHz': 119},
        {'droneId': -1},
        {'showCoordinates': null},
        {'rotation': []},
        {
          'rotation': {'superRate': 2},
        },
        {
          'collisionResponse': {'mode': 'invalid'},
        },
        {
          'controller': {'rollAxis': 1},
        },
        {
          'batteryProfile': {'batteryId': 4},
        },
        {
          'sceneTime': {'timeUtc': 'bad'},
        },
      ]) {
        expect(
          () => SimulationSettings.fromJson(raw),
          throwsFormatException,
          reason: '$raw',
        );
      }
    },
  );

  test('SQLite close/reopen retains configuration and unrelated changes; reset removes it', () async {
    final temp = await Directory.systemTemp.createTemp('fpv-simulator-prefs-');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/preferences.sqlite');
    var db = FpvDatabase(NativeDatabase(file));
    final settings = chosen(SimulationPhysicsModel.advanced);
    var repo = UserPreferencesRepository(db);
    await repo.savePreferences(
      UserPreferences(
        simulation: settings,
        signalHud: settings.signalHud,
        failsafe: settings.failsafe,
      ),
    );
    await repo.savePreferences(
      (await repo.getPreferences()).copyWith(labelsVisible: true),
    );
    await db.close();
    db = FpvDatabase(NativeDatabase(file));
    addTearDown(db.close);
    repo = UserPreferencesRepository(db);
    final stored = await repo.getPreferences();
    expect(
      stored.simulation.toCommand()
        ..remove('failsafe')
        ..remove('signalHud'),
      settings.toCommand()
        ..remove('failsafe')
        ..remove('signalHud'),
    );
    expect(stored.signalHud.toJson(), settings.signalHud.toJson());
    expect(stored.failsafe.toJson(), settings.failsafe.toJson());
    expect(stored.labelsVisible, true);
    await repo.resetPreferences();
    expect(
      (await repo.getPreferences()).simulation.toJson(),
      const SimulationSettings().toJson(),
    );
  });

  test('controller retains full settings, flight quick controls and scene time across restart and restore', () async {
    final db = FpvDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = UserPreferencesRepository(db);
    var controller = GlobeController();
    await controller.initializePreferences(repo);
    final settings = chosen(SimulationPhysicsModel.legacy);
    await controller.setSimulationSettings(settings);
    controller.dispose();
    controller = GlobeController();
    addTearDown(() async {
      controller.dispose();
      await controller.preferencesSettled;
    });
    final peer = FakeGlobeRenderer(controller)..attach();
    await controller.initializePreferences(repo);
    expect(controller.simulationSettings.toJson(), settings.toJson());
    peer.ready();
    peer.emit({
      'type': 'simulation-state',
      'active': false,
      'pending': false,
      ...const SimulationSettings().toCommand(),
    });
    await controller.preferencesSettled;
    expect(
      controller.simulationSettings.toJson(),
      settings.toJson(),
      reason: 'An idle/reloaded renderer must not persist its initial defaults',
    );
    peer.emit({
      'type': 'simulation-state',
      'active': true,
      'pending': false,
      'cameraTiltDegrees': 35,
      'cameraFovDegrees': 115,
      'graphicsProfile': 'performance',
      'showCoordinates': false,
      'controller': const ControllerSettings().toJson(),
    });
    final time = SceneTime(enabled: true, fixedUtc: DateTime.utc(2027, 7, 1));
    peer.emit({'type': 'scene-time-state', ...time.toJson()});
    await controller.preferencesSettled;
    final stored = (await repo.getPreferences()).simulation;
    expect(stored.cameraTiltDegrees, 35);
    expect(stored.cameraFovDegrees, 115);
    expect(stored.graphicsProfile, SimulationGraphicsProfile.performance);
    expect(stored.sceneTime.toJson(), time.toJson());
    expect(stored.controller.toJson(), const ControllerSettings().toJson());
    expect(stored.physicsModel, SimulationPhysicsModel.legacy);
    expect(stored.rotation.toJson(), settings.rotation.toJson());
    expect(stored.batteryProfile!.batteryId, 4);
    expect(
      (await repo.getPreferences()).failsafe.toJson(),
      settings.failsafe.toJson(),
    );
    await repo.savePreferences(
      const UserPreferences(simulation: SimulationSettings(maxSpeed: 40)),
    );
    await controller.retryLoadingPreferences();
    expect(controller.simulationSettings.maxSpeed, 40);
    expect(
      controller.simulationSettings.cameraTiltDegrees,
      0,
      reason: 'Restored preferences override values from the previous flight',
    );
  });

  for (final password in <String?>[null, 'test-only password']) {
    test(
      'simulator and equipment survive ${password == null ? 'plain' : 'encrypted'} backup restore',
      () async {
        final db = FpvDatabase(NativeDatabase.memory());
        final settings = chosen(SimulationPhysicsModel.advanced);
        late final Map<String, dynamic> document;
        try {
          await db.customStatement(
            "INSERT INTO drones(id,name) VALUES(2,'Test aircraft')",
          );
          await db.customStatement(
            "INSERT INTO batteries(id,name,cell_count,capacity_mah) VALUES(4,'Test battery',6,1600)",
          );
          await UserPreferencesRepository(db).savePreferences(
            UserPreferences(
              simulation: settings,
              signalHud: settings.signalHud,
              failsafe: settings.failsafe,
            ),
          );
          final backup = BackupRepository(db);
          document = await backup.preview(
            await backup.create(password: password),
            password: password,
          );
        } finally {
          await db.close();
        }
        // Restore into an independent database after the exporting app closes.
        final target = FpvDatabase(NativeDatabase.memory());
        addTearDown(target.close);
        final restored = BackupRepository(target);
        await restored.restore(document);
        final controller = GlobeController();
        addTearDown(controller.dispose);
        await controller.initializePreferences(
          UserPreferencesRepository(target),
        );
        expect(controller.simulationSettings.toJson(), settings.toJson());
        expect((await target.select(target.drones).get()).single.id, 2);
        expect((await target.select(target.batteries).get()).single.id, 4);
      },
    );
  }

  test('older backup without simulator keys loads defaults; malformed new data cannot replace current data', () async {
    final db = FpvDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final backup = BackupRepository(db);
    final old = await backup.preview(await backup.create());
    await UserPreferencesRepository(db).savePreferences(
      UserPreferences(simulation: chosen(SimulationPhysicsModel.legacy)),
    );
    await backup.restore(old);
    expect(
      (await UserPreferencesRepository(
        db,
      ).getPreferences()).simulation.toJson(),
      const SimulationSettings().toJson(),
    );
    await UserPreferencesRepository(db)
        .savePreferences(const UserPreferences());
    final invalid = await backup.preview(await backup.create());
    final rows = (invalid['tables'] as Map)['app_settings'] as List;
    (rows.firstWhere((row) => row['key'] == 'simulation.settings.v1')
        as Map)['value'] = jsonEncode({
      'rotation': {'superRate': 4},
    });
    await expectLater(backup.restore(invalid), throwsFormatException);
    expect(
      (await UserPreferencesRepository(
        db,
      ).getPreferences()).simulation.rotation.superRate,
      .55,
    );
  });
}
