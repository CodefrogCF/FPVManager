import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/models/propulsion_current_limits.dart';

void main() {
  test(
    'independent ESC and motor continuous limits use recorded motor count',
    () {
      const model = PropulsionCurrentLimits(
        motorCount: 4,
        escContinuousCurrentAmpsPerChannel: 15,
        motorContinuousCurrentAmpsPerMotor: 8,
      );
      final result = model.assess(40);
      expect(result.estimatedPerUnitInputAmps, 10);
      expect(result.escPossiblyOverloaded, isFalse);
      expect(result.motorPossiblyOverloaded, isTrue);
      final underEsc = model.assess(80);
      expect(underEsc.escPossiblyOverloaded, isTrue);
      expect(underEsc.motorPossiblyOverloaded, isTrue);
    },
  );

  test('missing motor count or manufacturer rating is unknown, not safe', () {
    expect(
      const PropulsionCurrentLimits(escContinuousCurrentAmpsPerChannel: 10)
          .assess(40)
          .escPossiblyOverloaded,
      isNull,
    );
    final outcome = const PropulsionCurrentLimits(motorCount: 4).assess(80);
    expect(outcome.estimatedPerUnitInputAmps, 20);
    expect(outcome.motorPossiblyOverloaded, isNull);
    expect(outcome.escPossiblyOverloaded, isNull);
  });
}
