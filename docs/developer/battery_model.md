# Chemistry-aware battery and propulsion model

**Status:** current technical reference. Battery and power values are
illustrative estimates; never portray generic C ratings, internal resistance,
flight time or ESC/motor loading as manufacturer-verified measurements.

## Shared source of truth

`assets/battery/chemistries.json` defines LiPo, LiHV, Li-ion, LiFePO4, NiMH and
NiCd reference presets. It contains nominal cell voltages, approximate OCV
curves by state of charge, low-voltage suggestions, resistance assumptions,
reference continuous C values and charge hints. Aliases resolve to stable IDs;
unsupported historical chemistry strings remain stored without being
silently mapped to LiPo.

```sh
python tool/generate_battery_chemistries.py
python tool/generate_battery_chemistries.py --check
```

The generator provides
`lib/core/models/generated/battery_chemistries.g.dart` and
`web/battery_chemistries.generated.js`. Both consumers must use the same
catalog; never make a unilateral Dart/JavaScript change to chemistry values.

## Electrical approximation

- For remaining charge fraction `SOC`, interpolate a chemistry-specific
  **open-circuit voltage** curve.
- Estimate cell resistance from a reference resistance scaled for capacity,
  unless a positive battery-specific per-cell value is supplied.
- For series cells, approximate pack resistance by multiplying the effective
  cell resistance by the series count. Solve the simplified circuit
  `P = I × (V_open - I × R_pack)` for the lower-current root.
- Integrate discharged **Ah** and consumed **Wh** independently. Falling load
  may recover terminal voltage from sag but must not regenerate consumed charge.
- Compare current against continuous/burst C ratings; burst validity requires
  duration and the existing model conservatively counts consecutive excess
  time. Chemistry references do not become proven manufacturer ratings.
- Route feasibility requires explicit energy information (Wh or configured
  voltage and capacity), not chemistry inference alone; recorded Wh is retained.

`lib/core/models/battery_chemistry.dart` implements Dart-side interpolation
and equivalence calculations. `web/battery_simulation.js` applies the shared
parameters to the live flight HUD.

## Manual flight and power proxies

Manual Acro/Angle power uses simulated **motor thrust demand**, not total
velocity magnitude. This prevents zero-throttle free fall from being charged
like powered forward flight. A rough thrust-to-weight power exponent and
speed-related cost remain approximations. Automated GPS flight, simulated
Rescue and route replay retain distinct speed/climb proxies where precise
motor thrust cannot be reconstructed. No unconditional 10% live power uplift
is applied.

A battery resistance override of **0 mΩ/cell** is treated as **unspecified**
for simulation purposes. A positive manufacturer/measurement-derived value
replaces the chemistry estimate. This preserves realistic sag in new packs
without inventing exact internal resistance.

## Independent propulsion diagnostics

Drone profiles can store optional ESC continuous amperes **per channel**, motor
continuous amperes **per motor**, and a motor count. Current analysis uses the
rough comparison:

```text
input-equivalent DC current per motor = estimated pack DC current / motor count
```

This is *not* ESC phase current, PWM waveform reconstruction or actual motor
winding current. Battery, ESC and motor warnings are separate. Missing limits
are reported as unknown, not safe. The estimator does not automatically clamp
requested power to these ratings.

## Storage and compatibility

- Database schema **v11** adds nullable pack C-rating, burst-duration and
  internal-resistance columns.
- Schema **v12** adds nullable ESC/motor continuous-current columns to the drone
  profile.
- Existing batteries, drones, templates and backups must survive upgrades.
  Unknown values remain null; existing unsupported chemistry identifiers are
  preserved.
- Regenerate Drift with `dart run build_runner build --delete-conflicting-outputs`
  and test old → current migrations, backup restore, user-edited values and
  generated schema consistency.

Charging references are **informational only**: lithium CC/CV maximums differ
by chemistry (LiPo 4.20 V, LiHV 4.35 V, Li-ion cell-dependent 4.20 V reference,
LiFePO4 3.65 V per cell), while NiMH/NiCd use delta-peak/temperature-based
termination and have no generic fixed-voltage cutoff. They are not discharging
thresholds or automated charger settings.

See [battery profile user guide](../user/battery_and_power.md) for entry
instructions and [historical notes](../archive/README.md) for implementation
stages.
