# Performance and validation

Measure a named build, device and reproducible scenario. Synthetic Node timings,
user observations and instrumented device measurements are different evidence.
None establishes real-world flight safety or universally stable frame rates.

## Repeatable checks

From the repository root:

```sh
node tool/benchmarks/performance_suite.cjs --check
node tool/benchmarks/benchmark_advanced_validation.cjs
node --test test/js/advanced_validation.test.cjs
flutter test test/features/signal/live_radio_motion_benchmark_test.dart
```

The CI suite enforces protocol/geometry invariants rather than machine-dependent
timing thresholds. It measures transfer encoding and scene scheduling without
Cesium GPU/network work. Advanced validation covers two controlled aircraft
profiles, scripted scenarios, 30/60/120 render FPS, both physics models and an
injected frame stall. Definitions live in
[profiles](../../tool/benchmarks/physics_validation/profiles.json) and
[scenarios](../../tool/benchmarks/physics_validation/scenarios.cjs).

Use `benchmark_live_rf_reliability.cjs` and `compare_live_rf_motion.cjs` under
`tool/benchmarks/` for explicit RF report runs/comparisons. CLI usage is reported
by each script. Never compare different route/speed/provider fixtures as a
controlled before/after measurement.

## Collect device evidence

Use a Flutter profile build on the target Android/Windows/browser device. Record
build/SDK, OS, CPU/GPU, display refresh, graphics profile, cache state, source data
size, network conditions and thermal/power state. Repeat cold and warm runs.

Cover spawn/loading, 1/3/6 km terrain-obstructed RF paths, 100–140 km/h motion,
hover above home, turns, provider outages/recovery, complex scenery, collisions
and a sustained flight. Capture frame P50/P95 and long frames, CPU, memory/GPU,
bridge traffic and RF calculation P50/P95, valid/unknown rate/duration and request
counts. Keep sampling precision and known terrain fixtures constant.

Opt-in scene/physics counters and the live RF panel are diagnostics, not measured
RF reception. RF diagnostics are disabled by default, bounded and throttled.
Unknown data must remain distinguishable from a valid clear or blocked profile.

Enable developer options and the performance overlay for a platform comparison.
Record WebGL renderer/vendor (masked if unavailable), Chromium UA engine version,
canvas/CSS/drawing-buffer dimensions, DPR and resolution scale. Observed rAF
cadence is not the physical monitor refresh or Flutter presentation rate. Update
and scene P95 cover the observed Cesium event spans, not the entire native frame.
Terrain busy time is elapsed time with pending tiles, not CPU processing time.
Compare the same viewport, display refresh, provider, route and graphics profile
with recording disabled; compare the browser build to the Windows WebView build.

Use the [device template](../../tool/benchmarks/reference/advanced_physics_device_template.json)
and [scenario definitions](../../tool/benchmarks/reference/scenarios.json).
Save deliberate exports under `.local-performance/` (ignored by Git). Tools do not
upload telemetry or automatically discover/profile other devices.
Performance JSON and CSV exports are limited to 16 MiB on all platforms,
including Android. Other file-export limits are unchanged.

## Physics trace comparison

The validation runner accepts a local telemetry CSV and explicit time offset:

```sh
node tool/benchmarks/benchmark_advanced_validation.cjs --profile=reference-7-inch --scenario=climb --telemetry=local-trace.csv --offset=0
```

The parser/aligner in `tool/benchmarks/physics_validation/telemetry.cjs` defines
accepted columns, units and interpolation. Match axes, timestamps and SI units;
do not compare arbitrary Blackbox channels as equivalent. Keep script-clock stall
traces separate. Generic drag, inertia, resistance and thrust coefficients remain
estimates. Validate against independent real profiles and a holdout before changing
global model defaults.

## Retained evidence and limits

Dated original JSON records are preserved under
[benchmark references](../../tool/benchmarks/reference/), including older device,
rendering, Advanced-physics and paired RF-motion measurements. Their bytes and
recorded conditions are retained; they are not current acceptance targets.
RF before/after evidence is explicitly synthetic where labeled. It does not prove
current phone latency, network throughput or sustained thermal behavior.

Advanced's default selection is a usability decision. User-reported device
stability is useful observation, not a complete benchmark. Independent real-flight
calibration, repeatable platform profiling and thermal/memory endurance remain
separate follow-up validation. Report failed/not-run checks and measurement limits
alongside successful automated results; do not call a source ZIP release-ready.

The flight graphics settings allow an independent 40–100% render scale, or the
profile default. Compare at a fixed scale and record the actual drawing buffer.
In Settings → Developer options → Performance recording, start a local session,
return to the flight, then stop and export JSON or CSV. A session retains at most
600 one-second snapshots (rolling profiler windows, not individual frames); no
files are written until explicitly exported. Disabling Developer options stops
profiling and clears the unexported session. Terrain request timings measure
settlement wall time, grouped by whether Cesium supplied a rendering request;
layer progress distinguishes pending downloads and processing, not exact CPU time.

## Automated route benchmark

In **Settings → Developer options → Automated benchmarks**, select a saved
Swiss route and one to three repetitions. Use the same route hash, graphics
profile, render scale, viewport and RF profile on each device. A route must
last at least 10 s; the runner uses its first 60 s (35 s for multiple repeats).
Planned AGL is resolved once to an absolute trajectory; recorded timing is
retained. Replay at 1× uses the route spawn as RF station, fixed lighting time
when enabled, and does not test manual flight physics or actual reception.

### Matrices and comparison profiles

| Matrix | Variants |
|---|---|
| `layers-v1` | Reference, no buildings, no Structures, no vegetation, terrain, no RF |
| `structures-tuning-v8` | Reference SSE 24/cache 16 MiB; SSE 32/40/48/64; cache 24/32/48 MiB; supports off; frozen warmed supports; compute-only supports; GPU timer off |

Structures tuning fixes overflow to 4 MiB, dynamic SSE factor 24 and foveated
cone 0.1. Each variant changes one factor; all three standard tilesets and RF
remain requested. Compute-only does not create support primitives. Frozen
mode holds the last warmup geometry (not a full-route bake) and performs no
new discovery/picks during measurement. The layer matrix's infrastructure
case toggles Structures and its synthetic supports, not independent tunnels
or custom scenery. Repeat 2 reverses order; repeat 3 rotates by half the matrix.

Choose the original settings, **Tunnel / obstacles off**, or **3D tunnels /
obstacle models on**. Both standardized profiles fix FOV to 100° and tilt to
0°, disable obstacle WMS/hazard overlays and set schematic tunnels, obstacle
vectors and models consistently. They do not overwrite saved preferences or
change collision settings, other overlays, route, RF, render scale or actual
buffer resolution. Remove prepared custom tunnels before using these profiles.
The export includes original and effective requested map settings; flags are
not proof of loaded geometry. Record actual layer availability and inspect the
scene. For comparisons with extras on, check obstacle categories and collision
settings too.

### First pass, warmed pass and rotation

For each case, the runner records a separate `warmup` summary (snapshot count,
median FPS, first observed support time in ms, support coverage and last
sampled pick/cache counters), then resets the profiler before the measured
replay. The Structures matrix recreates its tileset per case; HTTP/browser,
other tileset and terrain caches are not explicitly flushed. The layer matrix
retains resident tilesets. Warmup counters can include flight initialization;
these are not cold-network/device starts. For an independent cold session,
reload the renderer before the suite and record HTTP cache state separately.

Optional `stationaryRotation` runs **after** a measured reference replay at its
endpoint. It waits up to 20 one-second polls for existing geometry, then
pauses at a fixed position and tests 30° heading steps with alternating
0°/+20°/−20° pitch and return to the original heading. Without a baseline the
result is unverified, no empty rotation is recorded, and subsequent reference
runs can retry. Diagnostic-only interruption is also reported as unverified. Stable means no recorded removals or transform modifications;
new piers are allowed. Cylindrical piers have no independent heading parameter.
The test is separate from FPS samples, not an on-screen visibility test.

The JSON includes requested/observed layer and tuning state, per-run status,
FPS and frame-time snapshot percentiles, triangles/commands, memory-adjusted
SSE, RF validity and support coverage/counts. CSV contains the measured samples.
Support-enabled cases require observed geometry, support-off cases require zero
computed/rendered supports, and frozen/compute-only cases verify their mode.
One populated sample is not full coverage; compare first-support latency and
coverage as well as FPS. `visibleSupports` counts admitted primitive instances,
not pixels actually visible. GPU timings require timer-query support; JS
geometry-construction time excludes later Cesium/GPU uploads.

The runner retains at most 1,500 measured snapshots (manual recording: 600),
exports locally within the 16 MiB limit and restores temporary settings.
Timeout, collisions, terrain changes, backgrounding, cancellation or exhaustion
stop the suite. Export partial data if needed. Reload the renderer if restoration
cannot be confirmed. No route coordinates or raw provider errors are exported.

## Bridge supports: current architecture

Synthetic piers are illustrative, visual-only and independent of RF and
collision sampling. Native discovery uses official road axes and classified
hits from the selected Structures tileset. It uses contiguous matching
source IDs where available; unidentified hits cannot be committed for session
reuse. Unobserved points split spans, and excessive slopes/outliers are rejected. Stations use a fixed 24 m source-axis raster with a 12 m offset.
Mapped piers and explicit mapped-only exclusions take precedence; unsupported
suspension/arch inference is avoided. No missing height is fabricated.

- **Discovery:** near-road/route-lookahead priority, bounded road-area cache
  (8 areas, 5 min), initial local preview around a classified anchor (±144 m,
  stop each direction after two misses), then full bounded scans. At most 96
  new native picks initially, 48 mobile/64 desktop with a prior profile, and
  192 visits per refresh. Partial profiles have a short retry window. Optional
  ordinary replay prefetch streams axes only; it never blocks flight start.
- **Session reuse:** exact source-axis native observations (4,096 entries) are
  committed after a corresponding station passes terrain/deck clearance
  validation. Uncommitted positive hits expire after 120 s; explicit ordinary
  road classifications after 15 s. Missing/unidentified hits are retryable.
  Ground samples (2,048) are provider-scoped and normally expire after 120 s;
  identified native stations can reuse them within the session.
- **Deck validation:** source-identified native profiles avoid redundant deck
  picks. Other candidates require coherent three-probe measurements (2.5–150 m
  clearance, local consistency) or an explicit source height. Selected-content
  signatures permit short reuse; two independent agreeing groups within 25 cm
  permit session reuse (512 records). At most two short-cache hits per refresh
  receive an independent confirmation attempt after 15 s. Detailed fallback
  uses a whole coherent group, never mixed passes; requests are serial with an
  8 s refresh deadline. An outstanding Cesium request prevents a new one.
- **Continuity:** retain validated native station records (512) until eviction
  or invalidation. Admit new geometry within 700 m; keep already admitted piers
  within 900 m, or up to 1,200 m if their bounding sphere intersects the camera
  frustum. Existing profile budgets still cap rendering. Missing/partial scans
  do not invalidate source-backed piers. Source/terrain changes and explicit
  conflicting/excluded geometry remain authoritative. Portal visibility changes
  invalidate visual picking signatures only. Native height corrections above
  25 cm need a second independent observation.
- **Scheduling:** picks yield across frames; after first geometry, shared
  cost/frame-cadence feedback adds up to 120 ms recovery. Pending flight scans
  survive movements within 700 m of their center. Native piers publish as a
  batch; other incremental updates coalesce to 250 ms. Identical geometry
  reuses its primitive. No data is persisted to disk.

The default Structures cache remains 16 MiB. For the tested Xclipse 920 renderer,
Balanced and navigation use 48 MiB; masked/unknown renderers and other profiles
keep the conservative defaults. Explicit benchmark tuning overrides the device
choice. This is a targeted experimental budget, not evidence that all low-end
phones benefit from larger caches. SSE and RF/physics precision are unchanged.

Diagnostics: `nativeEarlyProfiles`, `nativeEdgeDeferred`, `nativeSessionHits`,
`nativeSessionCommitted`, `nativeClassifiedRoadHits`, `deckIndependentRechecks`,
`deckStableHits`, pick counts/times and adaptive wait times track work and reuse.
`supportTransformHash` fingerprints sorted identity/position/height/radius;
`supportAudit` retains only recent hashed IDs and reasons. Addition, removal,
position, height, radius and clear counters are separate (clear and draw
removal may overlap). Cache/LOD observations cannot establish surveyed accuracy;
initial consistently incorrect heights may survive until eviction or explicit
invalidation. Frustum retention does not guarantee on-screen visibility or
unlimited geometry beyond the search radius.

### Latest device evidence (V7, 2026-11-28)

| Device | Reference FPS | Frozen FPS | Without supports FPS |
|---|---:|---:|---:|
| Windows RX 6900 XT | 58.66 | 59.94 | 59.93 |
| S25 Ultra / Adreno 830 | 118.02 | 119.85 | 119.90 |
| S22 / Xclipse 920 | 58.69 | 90.51 | 97.09 |

Mean of verified run medians, Balanced, render scale 50%, FOV 100°, extras off;
108 completed runs, 106 tuning-verified. S22 had a different route hash and
model-collision preference. Its frozen figure uses one verified run. The S22
48 MiB case averaged 92.20 FPS with support geometry present in all 78 samples;
this is one short scene, not a thermal/memory endurance result. The S25 Ultra
rotation preserved 19 support transforms; Windows/S22 had no starting
baseline. No V8 device results are available yet. Retest with identical route
hashes, both extras profiles and sustained flights at intended render scales.
