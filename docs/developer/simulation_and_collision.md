# Flight simulation, Cesium collision and HUD visuals

This is a **simulation-only** system. It is not guaranteed obstacle detection,
real-device telemetry or verified flight physics.

## Flight modes and energy input

`web/features/flight/free_flight.js` and related physics modules model manual Angle/Acro and
assisted GPS movement. Angle and Acro use thrust-driven battery-power
approximations; GPS, automated Rescue and replay use their separate
speed/climb-based power proxy. A freely falling unpowered aircraft may develop
high vertical speed without incurring high motor power.

The battery source of truth and electrical assumptions are documented in the
[battery model](battery_model.md). The flight model requires regression checks
for motor-off descent, powered recovery, conservative power bounds, long-frame
delta limits and reset behavior.

## Collision sources versus visuals

These are different concepts:

- **Collision candidates:** known rendered terrain triangles, supported
  bridge/tunnel geometry and enabled 3D model collision surfaces.
- **Visual-only objects:** radio sightline, Fresnel representation and separate
  ground station marker (marked with the `fpvVisualOnly` data-source convention).

Cesium's `Scene.sampleHeight` can include non-terrain primitives. The model
collision sampler passes visual-only objects through `objectsToExclude`, so
an RF line cannot make a drone moving toward its operator stop abruptly.
Real supported mesh surfaces retain their existing collision handling.

The scope is **not** exhaustive collision against every building face, wire,
vegetation element or unseen ground feature. On a source or state change,
preserve source-specific collision invariants and normal flight sweeps.

## Missing rendered terrain at long range

A missing result from `scene.globe.getHeight()` means no usable rendered tile
height was sampled. It is **neither** proof of a clear route **nor** proof of a
solid obstruction. One missing height no longer forcibly brakes the simulated
aircraft. Known surfaces still stop movement; the active flight reports
`terrainVerification.state` (`complete`, `partial`, `unavailable`), counts of
sampled/missing probes and accumulated `unverifiedDistanceMeters`.

Where terrain is missing the simulator must not invent AGL/ground clearance;
it exposes a **terrain collision unverified** warning. A valid provider and
starting terrain are still needed at spawn, while provider-wide loss retains
its distinct recovery/exit behavior. Radio LoS terrain analysis has its own
coverage/confidence model and should not be conflated with movement collision
coverage.

## Analog visual holdover

`web/features/flight/hud/signal_hud.js` owns presentation-only analog static and warning effects.
Brief missing video RF updates keep the prior visual noise for **up to
1,100 ms** with an occasional additional flicker. RC and video bars report
unknown during missing data; the saved visual effect must not be read back as
RF quality or used for simulated RC failsafe. Long gaps or new sessions reset
this visual state.

The analog overlay uses bounded DOM/CSS work, not per-frame texture readback.
Track actual scene frame intervals and long frames when measuring device impact.

## Repeatable checks

```sh
node --test test/js/*.test.cjs
node tool/benchmark_simulator_terrain_gaps.cjs
flutter test --no-pub --platform chrome test/web/globe_input_test.dart test/web/offline_storage_test.dart
```

Manual validation: fly at zero throttle in Acro, cross a visible live LoS ray
at high speed with physical model collision enabled, then fly across a terrain
tile gap and check that **unverified** coverage is shown rather than invented
terrain clearance. Repeat known-surface collision checks after a tile becomes
available.

The synthetic ~49.9-km benchmark measures **CPU simulation ticks only**; it
is not a Cesium GPU/device/network benchmark. See [performance](performance.md)
for Android/Windows measurement procedures.

## Selectable physics scheduler (v0.19 development)

The physics refactor introduces Legacy and Advanced flight physics adapters and an
optional fixed-timestep integrator. The initial Advanced adapter intentionally
reuses the existing flight force approximations; it does not yet model actual
motor/propeller torque or validated battery-dependent thrust. See the
[physics architecture and timing reference](flight_physics_architecture.md)
for units, module boundaries, accumulator limits, diagnostics and tests.

## Advanced contact response

Advanced Physics optionally resolves confirmed contact with a terrain normal, bounded surface
friction and restitution; severe impacts and unsupported model normals still hard-stop.
All existing swept collision sources, visual-only exclusions and unknown-terrain warnings
are preserved. See [advanced collision response](advanced/advanced-collision-response.md) for limitations,
configuration, tests and benchmarks.
