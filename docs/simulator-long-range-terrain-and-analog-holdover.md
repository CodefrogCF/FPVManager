# Long-range free-flight terrain gaps and analog HUD continuity

## Background

Cesium's `scene.globe.getHeight()` samples only *currently rendered* terrain
meshes. `undefined` means the relevant rendered tile has not supplied a usable
height; it is not proof that the ground is at sea level, that the path is clear,
or that an obstacle exists. At long distances (including the reported 8.2 km
and 14.4 km), a single missing rendered tile previously called `brake()`, set
the entire velocity to zero and prevented the flight from continuing.

## Behavior

- An active flight can continue across missing rendered terrain. Known Cesium
  terrain triangles, bridge/tunnel/model geometry and available ground-height
  probes **still** cause contact to stop the simulated drone.
- A missing height is **not** extrapolated from the last valid height and is
  never used to assert verified terrain clearance. The HUD warning reads
  `Terrain collision unverified: tiles still loading` (German translation
  included). AGL is unknown where the current ground is not available.
- `status().terrainVerification` exposes `state` (`complete`, `partial`,
  `unavailable`), sampled/missing probe counts for the last flight step, and
  cumulative `unverifiedDistanceMeters`. These metrics concern **collision
  terrain coverage**, not the separate radio LoS terrain profiler.
- This is a **simulation-only degraded terrain mode**: missing collision terrain
  can hide a mountain face, tree, or other obstacle. Never present these
  intervals as confirmed collision-free. The RF LoS/failsafe logic is separate.
- Launch still requires a working terrain provider and a valid sampled starting
  height. Provider-wide terrain loss is handled by the existing flight-exit
  mechanism; the change concerns *individual missing rendered tiles* only.

## Analog-video behavior

- A valid simulated video-quality sample drives the visual analog interference
  as before.
- If the video model briefly returns unknown/no data, the **visual-only** noise
  continues from the previous estimate for up to 1,100 ms, occasionally with a
  small extra flicker. It resets on a new flight and stops if the gap persists.
- Video/RC indicators remain unknown during gaps. The remembered noise is not a
  receiver measurement, does not supply RF link quality and cannot trigger or
  prevent simulated failsafe.

## Reproducible CPU-only benchmark

Run `node tool/benchmark_simulator_terrain_gaps.cjs` from the project root. It
simulates approximately 100.8 km/h GPS flight past 5.9, 6.1, 10, 14.4, 20,
30 and 49.9 km, including two injected intervals of unavailable rendered
terrain. It prints the simulated flight distance/speed, coverage flags and
CPU cost per simulator tick. It **does not** download Cesium tiles or measure
actual GPU rendering, memory, frame times, network availability, RF range or
Android/Windows throughput. `terrainQueries` are local synchronous height
probes, **not HTTP terrain requests**.
