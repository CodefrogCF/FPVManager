import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/localization/generated/fpv_strings_de.dart';
import 'package:fpvmanager/core/localization/generated/fpv_strings_en.dart';

void main() {
  test(
    'battery chemistry choices are typed, translated and brand names retained',
    () {
      final de = FpvStringsDe();
      final en = FpvStringsEn();
      expect(de.batteryChemistryField, 'Akkuchemie');
      expect(en.batteryChemistryField, 'Battery chemistry');
      expect(de.batteryContinuousDischarge, contains('C'));
      expect(de.batteryInternalResistance, contains('mΩ'));
      expect(de.batteryTypeLiIon, startsWith('Li-ion'));
      expect(de.simulationBetaflightaaa2dc4d, 'Betaflight');
      expect(de.globeCancelSpawn701b7923, 'Start abbrechen');
      expect(de.commonPowerPerformance72b3155b, isNot('Leistung & Leistung'));
      expect(de.batteryChargingVoltageHint('4,20'), contains('maximal 4,20'));
      expect(en.batteryChargingVoltageHint('4.20'), contains('4.20'));
      expect(de.batteryNickelChargingHint, contains('Delta-Peak'));
      expect(de.droneCurrentLimitsHint, contains('Phasenstrom'));
      expect(en.droneCurrentLimitsHint, contains('phase current'));
    },
  );
}
