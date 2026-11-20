# Hardware-aware motor and propeller estimates

**Simulation only.** This is a lightweight static-propeller approximation, **not** a measured
Axisflying, HQProp, ESC or Bonka power curve. No real flight performance or safety claim is made.

## Configuration and data flow

`SimulationSettings` sends a **separate** `propulsionProfile` derived from the
selected `Drone` record, independently of battery-HUD selection. Available fields
include motor KV/count, propeller diameter/pitch and description, takeoff mass,
reference voltage, estimated maximum power, and independent per-channel ESC and
per-motor current ratings. Existing database records require no migration.

`web/motor_propeller.js` validates the profile and exposes deterministic
`create()`, `tick()`, `reset()`, `hoverCommand()` and `output()` methods. The
module is loaded in the embedded Cesium WebView, so it runs on Android as well
as browser and Windows. Only **Advanced manual Acro/Angle flight** currently
uses it. **Legacy, GPS and GPS Rescue** retain their previous kinematics;
physics-based automated flight is a later issue.

The current `web/free_flight.js` shares its existing translation, collision,
controller, battery and camera logic. The advanced manual model replaces the
generic thrust acceleration with output from the selected motor/propeller
configuration. Throttle in Acro commands a 0–1 motor fraction; Angle centres
its stick around the estimated hover fraction. Motor shaft speed approaches
its target with an exponential time constant; no instantaneous RPM step.

## Generic model and limits

When no optional manufacturer samples exist, the model estimates loaded RPM as
`KV × voltage × RPM efficiency × throttle` (units:
RPM). Static propeller estimates follow

- `T = C_T × ρ × n² × D⁴` (thrust per propeller, N)
- `P = C_P × ρ × n³ × D⁵ / efficiency` (electrical-input proxy, W)

where `n` is revolutions per second, `D` diameter in metres, and coefficients
are generic **assumptions**, not hardware data. Nominal air density is fixed at
1.225 kg/m³. Rotor performance in forward flight, dynamic inflow, motor torque,
ESC phases, propeller unloading, temperature and air density variation are not
modeled yet. Propeller `bladeCount` is explicit or parsed from a clear
`diameter × pitch × blades` description. The DB `propellerCount` is the number
of propellers and is never interpreted as blades. If blade count cannot be
established, the model assumes three and marks that assumption.

Optional `manufacturerCurve` points support measured throttle, per-motor thrust
(N), input power (W), and optionally RPM. Points must span throttle 0 to 1,
with strictly increasing throttle. Curve measurements are not populated from
product names; a future editor/importer may supply independently verified
values. Curve data currently has no dedicated persistent database field.

Output is restricted by **specified** drone max propulsion power, ESC continuous
DC-input proxy or motor continuous DC-input proxy. For uncalibrated generic
coefficients only, an additional explicit **numerical** power envelope of
4,000 W/kg (capped at 50 kW) and an absolute 12:1 thrust-to-weight ceiling
prevent runaway input values; these are not real manufacturer specifications. These current limits are **not
motor phase-current** measurements. Where the reference voltage or core
configuration is unavailable, Advanced retains the prior generic thrust-to-weight
fallback (identified by an absent `propulsion` status) rather than inventing a
complete motor specification. Real parameters override coefficients only where
actual data are available.

The existing chemistry-aware battery model now accepts estimated
`propulsionPowerWatts` plus a small auxiliary-load estimate, without stacking
its old speed-based power estimate onto the new motor power. The pack-voltage
feedback is approximate and one-way; a fully coupled voltage/current/thrust
solver, burst/thermal limits and sustained real hardware calibration belong
to the upcoming battery/propulsion coupling work. These estimates should not be treated as validated endurance.

## Reference configuration (unverified)

- 7-inch four-motor quadcopter, 1,320 g takeoff mass
- Axisflying 287 1750 KV
- HQProp 7×3.5×3V1S
- MEPSKING Space 60 A ESC
- Bonka U2 6S 4,500 mAh, 99.9 Wh nominal

These are configuration inputs for regression comparisons, **not** measured
thrust or efficiency data for this hardware.
