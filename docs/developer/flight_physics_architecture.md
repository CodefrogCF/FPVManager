# Flight physics architecture and frame-independent timing

**Simulation only.** The Advanced model connects manual Acro/Angle and GPS-assisted
flight / GPS Rescue to shared propulsion, battery, directional drag, rotation,
environmental and collision constraints. Generic coefficients are not calibrated
hardware measurements. Legacy preserves the original behavior. The radio bridge,
HUD, Cesium camera and battery-profile formats remain compatible. See the
[validation and release gate](advanced_physics_validation.md).

## User-visible selection

In **Simulation settings → Physics model**, select:

- **Legacy (default):** v0.18-era time integration, preserving current flight
  feel, controller behaviour, GPU-dependent motion timing and stall protection.
- **Advanced:** a selectable hardware-aware motor approximation in manual and autonomous flight when configured (otherwise the previous generic approximation), integrated
  at an independent, fixed simulation frequency (60, 120 or 240 Hz). The
  default is **120 Hz**. Rendering interpolates between physics snapshots.

The selection and physics frequency travel through the existing
`SimulationSettings.toCommand()` payload, including the normal new-flight and
settings workflows. No new drone or battery database columns are introduced;
existing profiles retain their meaning.

## Module boundaries

| Module | Responsibility |
| --- | --- |
| `lib/features/simulation/simulation_settings.dart` | Selectable mode, frequency, validation and bridge payload |
| `lib/features/simulation/simulation_settings_sheet.dart` | Bilingual model and frequency controls |
| `web/flight_physics.js` | Shared runtime contract, scheduling, fixed-substep budget and diagnostics |
| `web/motor_propeller.js` | Optional advanced motor RPM, propeller thrust and electrical-load estimate |
| `web/body_axis_aerodynamics.js` | Body-axis drag and low-throttle propeller drag |
| `web/rotational_dynamics.js` | Inertia, bounded control torque, and simplified Air Mode |
| `web/autonomous_flight_control.js` | GPS and Rescue guidance translated to shared attitude/thrust targets |
| `web/environmental_wind.js` | Deterministic wind and terrain-dependent approximations |
| `web/descent_aerodynamics.js` | Optional ground effect and powered descent approximations |
| `web/collision_response.js` | Bounded contact impulse, sliding/rebound and ground-contact resolution |
| `web/free_flight.js` | Existing pilot/controller logic, forces, motion integration, collision sweeps and battery updates |
| `web/flight_rendering.js` | Cesium camera/terrain rendering and collision providers |
| `web/globe.js` | Flutter↔Cesium command and state adapter, frame clock |

The runtime receives three host adapters: `integrate(seconds)`, `snapshot()`,
`present(previous, current, alpha)`; plus an optional `isActive()` guard.
This isolates physics scheduling from camera drawing without introducing a separate physics worker. The shared physics snapshot carries:

- **Position:** WGS84 latitude/longitude in degrees; ellipsoidal height in m.
- **Velocity:** local north/east/up in m/s.
- **Orientation:** normalized body forward/right/down to local north/east/down quaternion (w,x,y,z).
- **Angular velocity:** body x/y/z in rad/s.
- **Propulsion:** acceleration in m/s².
- **Environment:** gravitational acceleration and wind velocity in local N/E/U
  coordinates. Existing collision providers remain authoritative.

Pilot input and RC failsafe state remain in the controller. The fixed-step adapter invokes the selected flight integration at a constant timestep, then presents once per render frame. Advanced GPS guidance requests physically bounded thrust and attitude; it does not directly assign velocity. No second battery, radio, or collision subsystem is introduced.

## Fixed timestep / rendering independence

The Advanced runtime accumulates real elapsed frame time. With a 120-Hz
physics rate it processes 1/120-second steps. At 30, 60 and 120 FPS, ordinary
frame durations should therefore produce the same physical state and energy
consumption (within numerical tolerance), even if the camera refreshes less
often. The presented camera interpolates between the previous and current
physical positions and quaternion attitudes. Interpolation does **not** mutate
the authoritative simulated state.

Each rendered frame can process up to **24** physics substeps; pending time is
bounded to **0.5 s**. Short rendering stalls are caught up over multiple
frames if necessary. Extremely long or repeated stalls cannot be replayed
indefinitely: excess time is dropped *explicitly*, with the total reported
in `physicsDiagnostics.droppedSeconds`. A growing queue appears in
`physicsDiagnostics.queuedSeconds`. These are deliberate overload policies,
not silent loss of simulated time.

The runtime reports in `status().physicsDiagnostics`; Flutter can request the
current values using `GlobeController.flightPhysicsDiagnostics()` without
subscribing to per-frame data:

- `model`, `stepHz`, `simulatedSeconds`
- `queuedSeconds`, `droppedSeconds`, `lastSubsteps`
- `interpolationAlpha`

A simulation pause and route replay discard accumulated, unprocessed time;
start/reset clear the counters. Battery consumption happens inside each
completed physics substep, not inside the camera presentation callback.
The Legacy adapter retains its original long-frame cap for compatibility.

## Limits and follow-up work

- Advanced manual and autonomous flight use motor/propeller hardware estimates where
  sufficient aircraft parameters exist; otherwise conservative generic models apply.
  Legacy retains its historical assumptions. **No path is calibrated
  automatically against real hardware.**
- Existing collision sweeps still use terrain and supported modeled geometry;
  absent terrain tiles remain explicitly unverified.
- The fixed-step scheduler is invoked from the existing Cesium `preUpdate`
  callback, rather than a background thread. If rendering pauses entirely,
  there is no autonomous physics worker; the next frame processes bounded
  catch-up time. CPU/GPU contention must be measured on actual devices.
- At 240 Hz, terrain/collision and wind queries may become expensive.
  Profile first on the S25 Ultra and Windows; revert to Legacy if necessary.
- The Node validation runner uses the real simulator and a synthetic terrain adapter.
  Actual Blackbox/flight-data comparison and Android/Windows performance evidence
  remain separate release gates. See [validation](advanced_physics_validation.md).
