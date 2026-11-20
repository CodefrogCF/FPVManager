# Battery, motor and ESC profiles

FPVManager models electrical load and voltage for **flight simulation and route
planning**. Estimates are not physical measurements, validated manufacturer
performance curves or electrical safety limits.

## Create a battery profile

In **Ausrüstung → Akkus**, select one of the predefined chemistries:
**LiPo, LiHV, Li-ion, LiFePO₄, NiMH or NiCd**. Stable internal identifiers
are used regardless of display language. Historical unrecognized chemistry
values are retained as unsupported until you deliberately select another type.

Enter the actual **cell count**, rated **capacity (mAh)**, available nominal
**voltage/energy data** and charge/condition information where known. Optional
manufacturer-specific values include:

| Field | Meaning |
|---|---|
| Continuous C-rating | Approximate continuous current rating relative to capacity |
| Burst C-rating | Optional short-duration rating; needs a burst duration |
| Burst duration (s) | Assumed permissible time above the continuous rating |
| Internal resistance (mΩ/cell) | Battery-specific per-cell estimate or verified value |

Leaving an optional field empty means **unknown**, not unlimited. A resistance
value of **0 mΩ** selects the chemistry-based approximation; it does **not**
model a perfectly resistance-free battery. Positive measured/manufacturer
values override the reference. Changes to a battery-type template do not
silently overwrite an already saved physical pack.

### Charging references are not discharge limits

| Chemistry | Informational charge reference |
|---|---|
| LiPo | Typical lithium CC/CV up to 4.20 V per cell |
| LiHV | Typical lithium CC/CV up to 4.35 V per cell |
| Li-ion | Cell-dependent lithium CC/CV; illustrative 4.20 V per cell |
| LiFePO₄ | Typical CC/CV up to 3.65 V per cell |
| NiMH / NiCd | Delta-peak and temperature monitoring; **no fixed voltage-only charge cutoff** |

These are generic references displayed in the editor, **not charger commands**.
Always follow the exact cell/pack manufacturer's charging instructions.

## Define drone electrical limits

In the drone profile's **Propulsion** section, optionally enter the known
**ESC continuous current per channel** and **motor continuous current per motor**.
The motor count must be known for a per-motor comparison. An unfilled limit
stays **unknown**; it is not treated as adequate.

The current simulator compares an **equal-share approximation of battery DC
input current** against these values. It cannot derive real ESC phase current
or motor winding current, so an indicated overload is a **potential** problem
rather than a verified device-level current measurement. In Advanced manual Acro/Angle flight, known limits can restrict simulated
available propulsion power. Route planning and other flight modes continue to
report potential overload without enforcing an electrical cutoff. These
checks are approximations, not real motor or ESC protection.

## What the flight model does

- Estimates open-circuit voltage by chemistry and state of charge.
- Estimates voltage sag and power-dependent current from reference/overridden
  internal resistance and electrical load.
- Counts discharged **Ah** and used **Wh** separately; a reduction in load does
  not restore depleted capacity.
- Shows chemistry-based low/critical-voltage warnings unless custom thresholds
  are chosen.
- Flags estimated battery, ESC and motor load limits separately in route
  energy assessment and live estimates.
- Uses an approximate **thrust-based** motor load for manual Acro/Angle flight.
  Zero-throttle free fall should consume only minimal electronics/idle power,
  rather than powered forward-flight energy for falling airspeed.
- Uses a separate speed/climb-based approximation for GPS, automatic rescue
  and recorded-route replay where motor thrust is not reconstructed directly.

**Illustrative 7-inch example:** A 6S, 4,500 mAh pack with nominal 22.2 V
contains about **99.9 Wh** of rated energy. A test fixture for a 1,320 g quad
uses 180 / 290 / 1,100 W hover/cruise/maximum **assumptions**, not measured
specifications for Axisflying 287 motors, MEPSKING ESCs or HQProp propellers.
To calibrate actual flight endurance, compare real voltage/current/discharged-mAh
logs from flights of similar speed, wind and battery condition.

## Route energy and known/unknown data

Route energy analysis uses configured drone power curves, battery records and
the shared chemistry model. A nominal chemistry voltage alone does **not**
turn an otherwise unspecified pack into an affirmative known-Wh flight budget.
Recorded Wh is preserved. A segment may be flagged as current-limited even
when its overall energy reserve is undetermined.

A simulated voltage or remaining flight time is **not** real telemetry. Age,
cell construction, temperature, airflow, pilot behavior and cell degradation
can change performance substantially.

See the [flight simulation guide](flight_simulation.md) for the HUD and
[developer battery reference](../developer/battery_model.md) for model data,
formulas and schema compatibility.

## Advanced simulation and loaded battery voltage

When **Advanced** physics is selected with a compatible battery and propulsion
profile, motor speed, thrust and battery discharge influence each other.
A heavily loaded or nearly discharged pack may provide less thrust at the same
throttle input. The simulator uses your configured internal resistance,
continuous/burst C-ratings, ESC limits and motor limits where known. Missing
ratings use explicitly estimated chemistry defaults or stay unknown.

A voltage warning is a **simulation result, not actual telemetry**. If the
battery profile is missing, the simulator keeps a motor-only approximation;
it cannot calculate genuine remaining battery capacity. The Legacy and
GPS/Rescue simulations continue to use their earlier simplified energy
models. Actual flight time and performance must be checked against real logs.
