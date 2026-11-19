# Battery charging references and independent propulsion current diagnostics

## Chemistry-dependent charging references

The single source of truth is `assets/battery/chemistries.json`. Run
`python tool/generate_battery_chemistries.py` to regenerate the Dart/JavaScript
presets. The optional, information-only charging reference appears below the
battery chemistry selector (German and English).

| Chemistry | Charge termination model | Model maximum per cell |
| --- | --- | ---: |
| LiPo | Lithium CC/CV | 4.20 V |
| LiHV | Lithium CC/CV | 4.35 V |
| Li-ion | Lithium CC/CV (cell-dependent) | 4.20 V |
| LiFePO₄ | Lithium CC/CV | 3.65 V |
| NiMH | Delta-peak and temperature monitoring | No fixed voltage-only limit |
| NiCd | Delta-peak and temperature monitoring | No fixed voltage-only limit |

**These are generic charge references, not charger settings or independently
validated safe limits.** Manufacturer- and cell-specific restrictions take
precedence. Nickel chemistry is especially unsuitable for a fixed-voltage-only
charge termination rule. The discharge simulation, low-voltage alarms, energy
calculation, and charging references are **different concepts**.

## ESC and motor current fields

The drone editor's **Propulsion** section includes optional numeric fields:

- `escContinuousCurrentAmpsPerChannel` – amperes per ESC channel
- `motorContinuousCurrentAmpsPerMotor` – amperes per motor

The values are optional (unset means **unknown**) and retain their existing
measured/estimated/source-not-specified provenance via `DroneParameterSources`.
The number of motors must also be set to enable the comparison. No motor count
or manufacturer rating is invented. The fields persist in the `drones` table as
nullable columns in **database schema v12**. An upgrade from v11 adds the
columns without changing earlier profiles. Old backup files remain importable;
new `.fpvbackup` files include the new nullable fields automatically.

## Evaluation and limitations

`PropulsionCurrentLimits.assess()` in Dart and the equivalent live battery
simulation derive an **equal-share DC-input-equivalent current**:

```
inputEquivalentAmpsPerMotor ≈ estimatedPackDCAmps / knownMotorCount
```

This comparison is **indicative, not a valid measurement of ESC output phase
current or motor winding current**. ESC data sheets commonly specify phase
current; PWM duty cycle, controller efficiency, differential motor loads and
motor winding/phase currents are not reconstructed by this simplistic model.
Therefore a green status is never a verified safe operating limit, and an
exceedance is a **potential** limitation requiring validation with actual
manufacturer and logged flight data.

- A route segment may be flagged as `escLimitedSegments` or
  `motorLimitedSegments` independently of the chemistry's
  `loadLimitedSegments`. The analysis displays a separate warning for each.
- The live battery estimate exposes `escPossiblyOverloaded`,
  `motorPossiblyOverloaded` and `estimatedInputCurrentPerMotorAmps` separately.
- Incomplete motor count, missing ratings or missing battery current remain
  unknown. Nothing silently defaults to four motors or 60 amperes.
- The estimated power demand is **not clipped** to an ESC, motor or battery
  rating. This is a diagnostic comparison, not a control or protection model.
- Continuous ratings are supported; ESC/motor burst curves, thermal effects,
  phase-current reconstruction, battery cell temperature and charger simulation
  remain outside this change.
