import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/models/battery_chemistry.dart';
import 'package:fpvmanager/core/models/generated/battery_chemistries.g.dart';

void main() {
  test('all chemistry presets are available and legacy aliases resolve', () {
    expect(batteryChemistryPresets.map((c) => c.id).toList(), [
      'LiPo',
      'LiHV',
      'LiIon',
      'LiFePO4',
      'NiMH',
      'NiCd',
    ]);
    expect(BatteryChemistryDefinition.lookup('Li-ion')?.id, 'LiIon');
    expect(BatteryChemistryDefinition.lookup('LFP')?.id, 'LiFePO4');
    expect(BatteryChemistryDefinition.lookup('legacy unknown'), isNull);
    expect(
      BatteryChemistryDefinition.lookup('LiPo')!.maxChargeVoltsPerCell,
      4.2,
    );
    expect(
      BatteryChemistryDefinition.lookup('LiHV')!.maxChargeVoltsPerCell,
      4.35,
    );
    expect(
      BatteryChemistryDefinition.lookup('LiFePO4')!.maxChargeVoltsPerCell,
      3.65,
    );
    expect(
      BatteryChemistryDefinition.lookup('NiMH')!.maxChargeVoltsPerCell,
      isNull,
    );
    expect(
      BatteryChemistryDefinition.lookup('NiCd')!.requiresPeakChargeDetection,
      isTrue,
    );
    for (final chemistry in batteryChemistryPresets) {
      expect(
        chemistry.openCircuitVolts(1),
        greaterThan(chemistry.openCircuitVolts(0)),
      );
      expect(
        chemistry.openCircuitVolts(.25),
        lessThanOrEqualTo(chemistry.openCircuitVolts(.75)),
      );
      expect(chemistry.currentLimitAmps(4000), greaterThan(0));
    }
  });

  test('different chemistries produce distinct loaded voltage and reference current', () {
    final lipo = BatteryChemistryDefinition.lookup('LiPo')!;
    final liion = BatteryChemistryDefinition.lookup('LiIon')!;
    final a = lipo.estimateLoad(
      cells: 6,
      capacityMah: 4500,
      soc: .5,
      requestedWatts: 500,
    );
    final b = liion.estimateLoad(
      cells: 6,
      capacityMah: 4500,
      soc: .5,
      requestedWatts: 500,
    );
    expect(b.packVolts, lessThan(a.packVolts));
    expect(b.currentLimitAmps, lessThan(a.currentLimitAmps));
    expect(
      liion
          .estimateLoad(
            cells: 6,
            capacityMah: 4500,
            soc: .5,
            requestedWatts: 1500,
          )
          .exceedsReferenceCurrent,
      isTrue,
    );
    expect(
      liion
          .estimateLoad(
            cells: 6,
            capacityMah: 4500,
            soc: .5,
            requestedWatts: 500,
            dischargeC: 80,
            resistanceOhmsPerCell: .001,
          )
          .exceedsReferenceCurrent,
      isFalse,
    );
  });
}
