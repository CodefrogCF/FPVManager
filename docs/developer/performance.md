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

In Settings → Developer options → Automated benchmarks, select a saved route
and one to three repetitions. Create or import a route in Swiss terrain first.
Use the same graphics profile, render scale, viewport and route for subsequent
comparisons. The route must last at least 10 seconds; the runner uses its first
60 seconds (35 seconds for multiple repetitions). Planned AGL is resolved once to a
fixed absolute camera trajectory; recorded timing is retained. The route hash
identifies the input, not a surveyed height reference. Lighting time is fixed
when realistic lighting is enabled. Playback follows the route at 1× and is
not a benchmark of manual flight dynamics or failsafe behavior.

Each case has a complete warmup pass followed by a measured pass. The six
layer/radio cases are all three standard tilesets plus RF, no buildings, no infrastructure,
no vegetation, no three standard tilesets, and no RF. The infrastructure case
includes tileset-derived bridge supports, not independently enabled tunnels or
custom scenery. RF uses the selected radio profiles and the route spawn as
station. The second repetition reverses case order, the third rotates it by half the
case count. Warmup does not flush the
browser/network caches or guarantee every tile is resident; compare results
with the recorded visibility and loading state.

The runner resets profiler windows between measured passes, samples roughly
once per second and labels every row by run, variant, repetition and progress.
The JSON also contains run summaries, input fingerprints, completion status and
visibility/RF observations. These are snapshot percentiles, not raw per-frame
quantiles. Runs lacking observed layer visibility or valid RF are identified.
The benchmark recording is bounded to 1,200 snapshots (manual recording stays
at 600); timeout, collision, terrain changes,
backgrounding, cancellation or exhaustion terminate the suite. Partial data
can be exported via the same menu, except when developer mode is disabled.
The runner restores original scene and RF settings; if restoration cannot be
confirmed, reload the renderer. Export JSON/CSV locally before starting another
suite. No route coordinates or raw provider error strings are included.

### Structures tuning matrix

Select **Structures: LOD / cache / supports** instead of the layer/radio
matrix. All standard layers and RF remain enabled. The reference fixes
Structures at maximum screen-space error 24, cache 16 MiB, overflow 4 MiB,
dynamic SSE factor 24 and foveated cone 0.1. Other cases change just one
factor: SSE 32/40/48/64, cache 24/32/48 MiB, synthetic bridge supports off,
or GPU timer queries off (CPU timing and the other diagnostics remain on).
The renderer recreates the Structures tileset for each tuning case, with
one warmup pass; other tilesets, HTTP caches and ground-height cache are not
explicitly flushed. This is not a cold-network benchmark. The regular layer
matrix retains its original resident-tileset policy.

The JSON identifies the matrix and cache policy, requested parameters, actual
parameter verification, Structures loading/ready snapshot counts, median
triangles, commands and memory-adjusted SSE. CSV rows include the requested
settings alongside actual layer counters. Compare matching route hashes and
settings; do not interpret a run with unverified tuning or incomplete layers
as a successful A/B comparison. A ready root does not guarantee all visible
geometry is loaded. Inspect video/detail quality as well as FPS before adopting
a higher SSE. Per-layer local header fragment counts/bytes are diagnostic only.

Bridge support ground and deck caches are bounded, in-memory and independent
of RF/collision sampling. Resident deck samples are cached only when all three
heights are coherent, plausible and the selected native content covering the
probe positions is identifiable and unchanged. The cache expires after 30 s,
invalidates on terrain/tileset changes and does not cache most-detailed fallback
results. Unsupported Cesium selection internals bypass the deck cache. A slow
resident navigation pick gets an additional yielded frame; nearby candidates are
processed first and existing geometry stays visible until replacement is ready.
