# Advanced GPS-assisted flight and simulated GPS Rescue

## Scope and compatibility

With **Advanced** physics, both GPS-assisted manual input and the existing
simulation-only GPS Rescue use the same orientation, propulsion, battery and
aerodynamic integrators as Advanced Acro. The historical **Legacy** GPS and
failsafe-assisted velocity controllers remain unchanged. Existing saved
`flightMode`, failsafe configuration, RC thresholds and altitude/speed settings
remain valid without migration.

The failsafe state machine (`web/features/signal/simulated_failsafe.js`) is unchanged:
`rescueHold` → `climb` → `turn` → `return` → `landing` → `landed`, together with
`hold`, `descend` and `unavailable` modes. The RF model, activation and
reconnection hysteresis, deliberate stick-input takeover and replay bypass
remain unchanged. Only the translation of autonomous requests into aircraft
forces differs in Advanced mode.

## Control pipeline

All terms use SI units and local world **north/east/up** coordinates. Body
coordinates are **forward/right/down** with unit quaternion attitude.

1. **Guidance** (`web/features/flight/autonomous_flight_control.js`) creates target ground
   north/east velocity, upward velocity and heading; it does not modify the
   current position, velocity or orientation. Manual GPS uses normalized stick
   targets. Rescue uses the existing stop-distance-limited `approachSpeed()`
   near the home point and a constrained climb/landing rate.
2. **Velocity controller** computes bounded horizontal and vertical
   accelerations from the target/actual velocity error (`acceleration` and
   `deceleration` settings). Wind compensation uses air-relative body-axis drag
   estimated at the *current* velocity; it cannot add force without thrust.
3. **Thrust and attitude allocation** adds gravity compensation, limits the
   requested vector to the available propulsion envelope and a conservative
   **45° maximum tilt**, then derives a target quaternion for the commanded
   heading and force direction.
4. **Angular rate controller** converts target quaternion error into body-axis
   rate requests constrained by the existing Acro rate settings, then passes
   those requests through `rotational_dynamics.stepTargetRates()`. The shared
   actuator dynamics apply inertia, per-axis torque and angular acceleration
   limits. Angular state and orientation are integrated, never assigned
   directly from the guidance heading.
5. **Propulsion** turns required thrust into a bounded motor command, using the
   existing nominal thrust model or a binary inversion of the configured
   motor/propeller output curve. Where hardware and battery profiles are
   present, the same battery–ESC–motor coupling supplies delivered thrust,
   including voltage sag, discharge caps and motor-response delay.
6. **Translation** applies the actual thrust vector from the updated aircraft
   attitude, gravity and the existing `body_axis_aerodynamics` integration.
   The **same terrain / structure collision sweep** as manual flight checks
   each resulting movement. The battery is charged for the actual propulsion
   output plus modeled auxiliary load.

The integration uses fixed advanced-physics substeps; per-render-frame timing
does not change the simulated steps, within the existing backlog/drop budget.
The `status().flightControl` object exposes targets and delivered force
estimates for debugging; it is `null` in Legacy/manual Acro/Angle flight.

## Flight-phase semantics

| Phase | Target movement | Physical boundary |
| --- | --- | --- |
| Hold / Rescue Hold | Brake and hold ground position; keep heading | Wind or weak thrust may cause drift |
| Climb | Climb toward configured rescue altitude, without jumping | Available thrust minus gravity, aerodynamic drag and tilt allocation |
| Turn | Rotate toward home heading and retain altitude | Torque, inertia and yaw-rate limits |
| Return | Travel toward home with distance-limited speed | Available acceleration, braking distance, wind and power |
| Landing | Brake over home, descend at configured low rate | Motor response, real vertical movement, normal floor clearance |
| Landed | Stationary simulated touchdown | Existing failsafe terminal-state logic |

A depleted or undersized pack **does not receive virtual hover/climb thrust**.
The state machine can report `unavailable` when the battery estimate is
insufficient; in other low-power conditions a rescue phase may remain active
while the aircraft descends or is unable to attain the requested speed/altitude.
No safe-return or guaranteed landing behavior is promised.

## Modeling assumptions and limitations

- **All thrust, drag, inertia and response-time defaults are uncalibrated
  estimates.** The seven-inch, 1.32 kg reference setup is a test fixture, not a
  manufacturer-validated performance prediction.
- The thrust allocation and torque authority are simplified; individual motor
  mixers, dynamic propeller inflow, EKF/GPS noise, magnetometers, altitude
  sensors and full Betaflight navigation/PID behavior are not simulated.
- Drag feed-forward is a simplified quadratic model; strong gusts and abrupt
  attitude changes can cause tracking errors, drift and overshoot.
- Braking-distance guidance assumes configured deceleration; when the actual
  available thrust is lower, arrival may overshoot the 3 m home threshold.
- RC recovery is deliberately governed by the existing **simulated** RF
  quality and deliberate input rules. This is NOT real-world GPS Rescue
  software, nor an aircraft flight-safety system.
- Camera mouse look in Advanced GPS sets a *target* yaw; the vehicle heading
  changes through finite control torque. Legacy GPS look remains immediate.
- Calibrate from real Blackbox/GPS/altitude recordings (especially battery
  voltage and current under load) before drawing conclusions about performance.
