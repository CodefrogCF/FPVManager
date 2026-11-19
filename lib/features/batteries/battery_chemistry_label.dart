import 'package:flutter/widgets.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/battery_chemistry.dart';

/// Display-only localization for stable, language-neutral chemistry identifiers.
/// Unknown legacy strings are returned unchanged, never guessed or rewritten.
String localizedBatteryChemistry(BuildContext context, String raw) {
  switch (BatteryChemistryDefinition.lookup(raw)?.id) {
    case 'LiPo':
      return context.localized(
        'LiPo — Lithium polymer',
        (s) => s.batteryTypeLiPo,
      );
    case 'LiHV':
      return context.localized(
        'LiHV — High-voltage lithium polymer',
        (s) => s.batteryTypeLiHV,
      );
    case 'LiIon':
      return context.localized(
        'Li-ion — Lithium-ion',
        (s) => s.batteryTypeLiIon,
      );
    case 'LiFePO4':
      return context.localized(
        'LiFePO4 — Lithium iron phosphate',
        (s) => s.batteryTypeLiFePO4,
      );
    case 'NiMH':
      return context.localized(
        'NiMH — Nickel-metal hydride',
        (s) => s.batteryTypeNiMH,
      );
    case 'NiCd':
      return context.localized(
        'NiCd — Nickel-cadmium',
        (s) => s.batteryTypeNiCd,
      );
    default:
      return raw;
  }
}
