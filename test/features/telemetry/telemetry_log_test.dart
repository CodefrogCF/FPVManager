import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/models/bounded_csv.dart';
import 'package:fpvmanager/core/models/route_planning_settings.dart';
import 'package:fpvmanager/features/telemetry/telemetry_log.dart';

Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));
const header = 'time_s,airspeed_m_s,voltage_v,current_a\n';
const model = RoutePlanningSettings(
  flightMassGrams: 500,
  referenceMassGrams: 500,
  powerCurve: [PowerCurvePoint(0, 100), PowerCurvePoint(20, 300)],
);

void main() {
  test('time-weighted speed, duration and trapezoidal V×I energy', () {
    final log = TelemetryLog.decode(
      bytes('${header}0,0,10,10\n10,10,10,20\n30,20,10,30\n'),
    );
    expect(log.duration, 30);
    expect(log.averageSpeed, closeTo(350 / 30, 1e-10));
    expect(log.energyWh, closeTo(6500 / 3600, 1e-10));
    expect(log.maxSpeed, 20);
    final comparison = log.compare(model);
    expect(comparison.predictedWh, closeTo(6500 / 3600, 1e-10));
    expect(comparison.factor, closeTo(1, 1e-10));
    final calibrated = model.calibrated(1.2, 'Local telemetry #1');
    expect(calibrated.powerCurve.last.watts, 360);
    expect(model.powerCurve.last.watts, 300);
  });
  test('EdgeTX midnight, explicit units and still-air consent', () {
    final log = TelemetryLog.decode(
      bytes(
        'Date,Time,GSpd(kmh),Curr(A),VFAS(V),unused\n2026-10-24,23:59:59.000,36,10,12,"a,b"\n2026-10-25,00:00:01.000,72,10,12,"a""b"\n',
      ),
    );
    expect(log.duration, 2);
    expect(log.averageSpeed, 15);
    expect(log.isAirspeed, isFalse);
    expect(log.compare(model).problem, isNotNull);
    expect(
      log.compare(model, assumeStillAir: true).predictedWh,
      closeTo(500 / 3600, 1e-10),
    );
  });
  test(
    'unknown fields, gaps, repeated times and absent sensors fail explicitly',
    () {
      for (final content in [
        '${header}0,10,12,10\n0,10,12,10\n',
        '${header}0,10,12,10\n31,10,12,10\n',
        '${header}0,,12,10\n1,10,12,10\n',
        '${header}0,NaN,12,10\n1,10,12,10\n',
        'Time,GSpd(kmh),Curr(A),VFAS(V)\n1,36,10,12\n2,36,10,12\n',
        'time_s,airspeed_m_s,voltage_v,current_a,current_a\n0,10,12,10,10\n1,10,12,10,10\n',
        'Date,Time,GSpd(kmh),Curr(A),VFAS(V)\n2026-02-30,10:00:00.0,36,10,12\n2026-03-02,10:00:01.0,36,10,12\n',
      ]) {
        expect(
          () => TelemetryLog.decode(bytes(content)),
          throwsFormatException,
          reason: content,
        );
      }
    },
  );
  test(
    'calibration refuses extrapolation, missing mass and unreasonable factors',
    () {
      final log = TelemetryLog.decode(
        bytes('${header}0,30,10,10\n1,30,10,10\n'),
      );
      expect(log.compare(model).problem, contains('outside'));
      expect(
        log.compare(const RoutePlanningSettings()).problem,
        contains('mass'),
      );
      expect(() => model.calibrated(10, 'x'), throwsArgumentError);
    },
  );
  test('CSV parser bounds rows, field lengths and quoting', () {
    expect(
      readBoundedCsv(bytes('\uFEFFa,b\r\n"hello\nworld","x""y"\r\n')).last,
      ['hello\nworld', 'x"y'],
    );
    expect(
      () => readBoundedCsv(bytes('a\nb\nc'), maxRows: 2),
      throwsFormatException,
    );
    expect(() => readBoundedCsv(bytes('a\n"unclosed')), throwsFormatException);
    expect(() => readBoundedCsv(bytes('a\n"x"suffix')), throwsFormatException);
    expect(
      () => readBoundedCsv(bytes('a\n${'x' * 4097}')),
      throwsFormatException,
    );
  });
}
