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
