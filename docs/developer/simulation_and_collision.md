# Flight simulation and collision

The simulator is illustrative, with approximate hardware/environment models.
It does not control a real aircraft or certify obstacle clearance.

## Physics and state

Advanced is the default; Legacy remains an explicit compatibility fallback.
The shared aircraft state connects manual GPS/Angle/Acro, GPS Rescue and route
playback to the selected battery/propulsion and collision configuration.
`flight_physics.js` uses a bounded 60/120/240 Hz fixed timestep (120 Hz default),
limited catch-up work, dropped-time diagnostics and render interpolation.
Battery integration remains independent of rendering.

| Module under `web/features/flight/` | Responsibility |
|---|---|
| `free_flight.js` | Flight lifecycle, controls, shared state and terrain sweeps |
| `physics/flight_physics.js` | Integration timing and diagnostics |
| `physics/motor_propeller.js`, `physics/electrical_propulsion.js` | RPM/thrust estimates and bounded battery-load coupling |
| `physics/body_axis_aerodynamics.js` | Body-axis drag and optional propeller drag |
| `physics/rotational_dynamics.js` | Rate shaping, inertia/torque response and Air Mode |
| `physics/descent_aerodynamics.js` | Optional ground effect, propwash and vortex-ring heuristics |
| `physics/collision_response.js` | Advanced contact normal, friction, slide/rebound and hard stop |
| `autonomous_flight_control.js`, `physics/rescue_velocity.js` | Assisted/Rescue movement through the same constraints |

Profile coefficients are assumptions unless supported by independent measurements.
See [battery](battery_model.md) and [propulsion](motor_propeller_model.md) for
input provenance and electrical limits. Angle/Acro use thrust-driven power
estimates; GPS/Rescue/replay use the existing assisted speed/climb proxy.
Unpowered descent must not invent high motor power from falling speed.

## Configuration and persistence

`SimulationSettings` validates flight modes, frequency, rates, camera, controller,
battery and optional advanced effects before sending a bridge command. The
`simulation.settings.v1` preference stores the complete configuration and selected
equipment identity. Existing signal-HUD/failsafe keys stay authoritative for those
subsettings. All three keys are included in portable backups.

The settings dialog waits for preferences and saves even without starting a
flight. Valid active quick-control changes are persisted; idle renderer defaults
cannot overwrite saved choices. Restore reloads the stored configuration rather
than retaining the previous session's camera/controller values. Missing fields
from older backups use defaults; invalid data is rejected before replacement.
Capture mode and flight telemetry are transient. No database schema change is
required for these preferences.

## Collision and terrain quality

Collision candidates are known rendered terrain, supported bridge/tunnel geometry
and enabled model surfaces. RF sightlines, Fresnel illustrations and the separate
station marker are visual only (`fpvVisualOnly`) and must be excluded from scene
height/collision sampling.

A missing rendered terrain height is neither a confirmed obstruction nor a clear
path. It does not by itself brake the aircraft. `terrainVerification` reports
`complete`, `partial` or `unavailable`, missing probes and unverified distance;
AGL is not invented. Known surfaces still constrain movement. A valid starting
terrain is required at spawn, and provider-wide failure retains its distinct
recovery/exit handling. RF observation quality is a separate contract.

Advanced contact uses supported surface normals, bounded restitution and friction.
Severe impacts and unsupported normals still hard-stop. Coverage is not exhaustive
for unseen terrain, buildings, vegetation or wires. Bridge supports are illustrative:
explicit suspension/hanging bridge structure tags or unambiguous names suppress
automatic intermediate pillars, including aligned overlapping source decks.
Actually mapped pylons/piers remain eligible. Ambiguous/unclassified structures
are not inferred from imagery.

## HUD and uncertainty

Analog noise is presentation only. Missing video updates may retain its previous
visual effect for up to 1100 ms; RC/video bars still show unknown. This holdover
cannot supply failsafe evidence. New sessions and longer gaps reset it.
See [radio and Rescue](radio_and_rescue.md) for observation freshness, RF evidence
and opt-in failsafe criteria.

## Validation

The JS suite tests fixed-step/frame-rate invariance, low-voltage/freefall behavior,
control/Rescue handoff, wind, collision, missing terrain and reset boundaries.
Run `node tool/benchmarks/benchmark_advanced_validation.cjs` for the controlled
profiles/scenarios and `node tool/benchmarks/benchmark_simulator_terrain_gaps.cjs`
for the terrain-gap simulation fixture. These measure CPU simulation work, not
Cesium GPU/device performance. The [performance guide](performance.md) covers CSV
comparison, recorded evidence and the remaining device/calibration gate.
