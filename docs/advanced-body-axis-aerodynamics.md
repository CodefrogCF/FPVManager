# Advanced body-axis aerodynamics

## Scope

Only **Advanced** physics uses the new directional quadratic drag. Advanced
Acro, Angle and GPS-assisted/Rescue flight share the same implementation
(`web/body_axis_aerodynamics.js`). Legacy flight dynamics, including GPS and
GPS Rescue, and replay retain their existing algorithms. Fixed physics
substeps and hardware/battery coupling are unchanged.

## Coordinates, assumptions and units

* World velocity and wind are in **north/east/up m/s**; body axes are **forward
  (x), right (y), down (z)**. The existing unit quaternion transforms between
  the two systems. Camera tilt is deliberately excluded.
* The aircraft's **air-relative**, not ground-relative, velocity determines
  resistance. The generated acceleration is always opposite to the
  corresponding component of airflow; passive drag cannot add kinetic energy.
* The reference free-fall terminal speed `acroTerminalVelocity` (default
  **22.5 m/s**) calibrates the overall coefficient
  `k0 = g / terminalVelocity²` in **1/m**. Each independent body-axis term is
  `dv_i/dt = -k_i · v_i · abs(v_i)` (m/s²). The forward coefficient differs from
  the backward coefficient, with a symmetric lateral term.
* For each physics substep, the solver applies half of gravity/motor thrust,
  transforms airspeed into the current body frame, then integrates the above
  quadratic drag analytically per axis (including integrated displacement),
  rotates the result to world coordinates and applies the second half of the
  external acceleration. This splitting prevents forward-Euler drag overshoot,
  even at high airspeeds or during abrupt changes in attitude.
* No fictitious lift, motor thrust or powered-flight speed cap is applied to
  zero-throttle Advanced Acro/Angle descents. Motor inertia, electrical power
  and voltage sag continue to be calculated by the pre-existing propulsion
  modules, not by this aerodynamic module.

### Conservative, uncalibrated presets

| Preset | Forward | Backward | Lateral | Vertical | Low-power propeller |
| --- | ---: | ---: | ---: | ---: | ---: |
| Conservative (default) | 0.35 | 0.55 | 0.70 | 1.00 | +0.12 |
| Streamlined | 0.20 | 0.40 | 0.50 | 0.85 | +0.08 |
| High drag | 0.60 | 0.85 | 1.00 | 1.30 | +0.20 |

These **dimensionless** ratios multiply `k0`, not aerodynamic `Cd`, `CdA` or
newtons. An additional **Custom** preset exposes separate forward, reverse,
lateral, vertical and propeller coefficients (0–5, vertical 0.1–5). The
low-power propeller term is optional, affects body-Z drag only, and ramps down
linearly to zero at 35% commanded motor power. It is a rough disk/autorotation
surrogate, **not** an RPM-based or blade-element model. At zero motor command
it can only increase passive aerodynamic resistance.

The terminal-velocity parameter is the **upright body-Z reference with
propeller drag disabled**, not a guarantee of terminal speed in every
orientation, battery state, altitude or aircraft configuration. A simplified
full-throttle speed hint in the settings is only a drag/thrust estimate and
does not incorporate the actual manufacturer curve, RPM, battery limits,
propeller inflow or the air density at altitude.

## 7-inch reference quadcopter

Initial aircraft context: **1,320 g**, 4 × Axisflying 287 1750 KV,
HQProp 7×3.5×3V1S, MEPSKING 60 A ESC and Bonka 6S 4500 mAh battery. None of
the directional ratios above are derived from measured forces for this quad.
The advanced motor and battery configuration and their established power limits
remain independently applied. Mass and thrust are handled by the propulsion
model; aerodynamic acceleration is calibrated to the configured terminal-speed
parameter rather than to unverified frame projected-area measurements.

To calibrate, collect time-aligned flight-controller orientation and GNSS/IMU
velocity estimates along with battery voltage/current, motor commands and a
wind estimate. Compare motor-off descents at several attitudes; measure
unpowered forward/side/backward deceleration separately. Derive body-relative
airspeed, check data quality and tune coefficients against held-out flights.
Account for wind, air density and uncertainty. Real-world diving and
mountain-surfing footage alone is insufficient to identify all parameters.

## Limitations

This is a deliberately simplified, deterministic model. It excludes actual
unsteady flow, rotor wash, wind shear, angle-of-attack dependent lift, prop
windmilling power, motor braking, true CdA, detailed battery thermals and CFD.
The later milestones for rotational dynamics, environmental forces and GPS
assisted physics are **not** implemented by this issue. Do not use simulated
performance as a safety or legal flight envelope.
