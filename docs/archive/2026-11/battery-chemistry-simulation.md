# Battery chemistry simulation – shared model

> **Historical implementation note (November 2026).** This document records an earlier development stage. Some limits, defaults or statements have since changed. For current behavior use the [user guide](../../user_guide.md), [flight simulation guide](../../user/flight_simulation.md), [radio model reference](../../developer/radio_and_rescue.md) and [battery reference](../../developer/battery_model.md).


The simulation and route energy planner use the same battery chemistry **reference catalog** at `assets/battery/chemistries.json`.

This is a deterministic educational model, **not** a validated performance or electrical safety prediction. The values are generic illustrative assumptions at approximately room temperature; real packs differ by cell model, number of parallel cells, condition, temperature, age, state of charge, and BMS limitations. The reference `C` values must **never** be treated as verified manufacturer ratings.

## Supported presets

- LiPo – lithium polymer
- LiHV – higher-voltage lithium polymer
- LiIon – lithium ion
- LiFePO4 – lithium iron phosphate
- NiMH – nickel metal hydride
- NiCd – nickel cadmium (legacy)

The catalog provides nominal cell voltage, warning and critical cell-voltage suggestions, an interpolated open-circuit voltage (OCV) curve by charge fraction, an illustrative resistance at 1 Ah, and a conservative **reference**, not certified, continuous C rating. Aliases such as `Li-ion`, `LiIon` and `LFP` resolve to a stable ID. Unsupported values remain intact in saved battery records. Unsupported chemistries produce **unavailable** live voltage estimates rather than being silently treated as LiPo.

## Integration

- `tool/generate_battery_chemistries.py` generates `lib/core/models/generated/battery_chemistries.g.dart` and `web/battery_chemistries.generated.js` from the JSON source of truth. Generated outputs are checked in and loaded as Flutter WebView assets. `--check` accepts Dart formatter changes but detects changed definitions.
- `lib/core/models/battery_chemistry.dart` supplies OCV interpolation and equivalent-circuit voltage/current estimates to the Dart route planner.
- `web/battery_simulation.js` uses the same generated curve/resistance/current parameters. It maintains **coulomb-counted charge (Ah)** and **energy expenditure (Wh)** separately; estimated voltage is derived from remaining charge and power load. Neither amount is regenerated when the load falls.
- `BatteryRouteAssessment` preserves explicitly recorded battery Wh and charge/reserve assumptions. It separately flags segments whose required estimated current exceeds the chemistry's generic reference C limit; no motor power or route energy data is replaced. For incomplete battery energy/charge information, the route budget remains unavailable rather than turning chemistry assumptions into affirmative flight guarantees.
- Simulation HUD voltages/warnings use the selected chemistry by default. Uncheck the chemistry warning option to manually override thresholds (manual values now support low-voltage nickel cells as well as lithium cells).
- An explicit positive battery resistance override replaces the chemistry estimate; the existing UI value `0` selects **automatic chemistry-based resistance** rather than disabling sag. Battery profiles now store optional battery-specific C-ratings, burst durations, and internal resistance as documented in `docs/archive/2026-11/battery-chemistry-profile-fields.md`. Independent ESC/motor current diagnostics and charge references are covered in `docs/archive/2026-11/battery-chemistry-current-limits.md`.
- GPS Rescue's estimated energy shortfall calculation consumes the new battery model's **remaining energy estimate** instead of assuming the battery record contains a nominal voltage.

## Simplified calculations

For a charge fraction `SOC` the model interpolates the OCV curve of the selected chemistry. The approximation for cell resistance is `R_cell = R_reference_1Ah / capacity_Ah` unless overridden. For a series pack, `R_pack = R_cell × series_cells`. It solves `P = I × (V_open - I × R_pack)` using the lower-current root. When the requested power exceeds the theoretical maximum of this simplified circuit, or the generic C limit is exceeded, the result is flagged. This does **not** prove that a real pack would fail or that the simulator can guarantee the requested power. Continuous current is estimated from `C_reference × capacity_Ah`; the reference is only a broad assumption.

The flight simulator integrates estimated power in Wh and estimates discharged Ah from computed current. Depletion is bounded by the entered starting charge and rated pack capacity. A displayed voltage is always a simulated value and may have large errors under high current, low charge, or unusual temperatures. Battery voltage alone is not a direct measurement of remaining energy. Chemistry-derived warning levels are illustrative and not charging or storage instructions.
