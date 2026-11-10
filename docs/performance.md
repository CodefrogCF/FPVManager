# Performance and diagnostics

This guide covers the current renderer/data pipeline, reproducible measurements
and local reporting. Synthetic checks protect correctness; they do not establish
device FPS, GPU memory, cold-start latency or network performance.

## Current behavior

- Large native UAS transfers can use negotiated gzip/base64 compression. Plain
  transfers use up to 96 Ki UTF-16 code units per chunk, reduced when escaping
  would exceed the 128 Ki frame limit. Capability negotiation and receiver
  credits keep transport bounded; cancellation releases incomplete transfers.
- Unchanged native HTTP 304 responses reuse an attached Cesium data source.
  Renderer reload still requires re-import. Web uses ordinary GET refreshes
  where the provider does not permit conditional-request headers through CORS.
- The 3D scene avoids repeated property writes while stable. Flight retains
  recently viewed terrain; bounded detail/cache settings follow the selected
  graphics profile. These budgets do not promise a particular device frame rate.
- Tunnel geometry is prepared one model per render opportunity during flight.
  Shared vertices and opaque drawing materials are reused; the newly occupied
  corridor's collision mesh is prepared before handoff. Long source axes retain
  their height anchors and overlapping windows. Curve masks update in place.
- Native bridge discovery and resident deck checks permit one depth probe per
  rendered opportunity; already confirmed native profiles avoid duplicate picks.
  Unchanged pier geometry retains its existing primitive.
- The optional approximate model-height collision probe is deferred until after
  the visible frame and uses a short-lived, nearby result. Exact synthetic tunnel
  collision stays independent. Flight gaps above 75 ms discard excess elapsed
  time instead of applying a large catch-up movement on the next image.

See [architecture](architecture.md), [bridge contracts](globe_bridge.md) and
[renderer fixtures](cesium_assets.md) for component boundaries and validation.

## Local checks

```sh
node --test test/js/*.test.cjs
node tool/performance_suite.cjs --check
node tool/benchmark_globe_transfer.cjs
node tool/benchmark_scene_scheduling.cjs 10000
dart run tool/uas_loading_benchmark.dart
dart run tool/benchmark_uas_memory.dart --features=1256 --runs=5
dart run tool/benchmark_uas_memory.dart --features=1256 --runs=5 --worker
dart run tool/benchmark_sqlite_cache.dart --tiles=10000 --spots=10000 --runs=3
```

The CI suite preserves 18,000 synthetic bridge features and checks 10,000 stable
scene frames for redundant writes, requests, loads and removals. Its elapsed times
are observations, not pass/fail thresholds. The Dart loading/memory/SQLite tools
are also microbenchmarks; they do not exercise a physical WebView or GPU.

`dart run tool/benchmark_uas_http.dart` deliberately contacts the official data
service. Run it only for an intended network measurement; it is not part of the
synthetic CI suite. An explicit local GeoJSON path can be passed to
`tool/uas_loading_benchmark.dart`; that command does not upload the file.

## Measure a device

Use [the scenario definitions](performance/scenarios.json). Compare the same app
build conditions, dataset revision/size, camera/path, graphics profile, device,
OS/browser, network, cache state and power/thermal conditions. Collect at least
five repetitions per scenario in profile or release mode. Keep missing values
missing instead of replacing them with zero.

| Scenario | What must be distinguished |
|---|---|
| Cold load | Actual HTTP 200, browser disk cache, body bytes and feature count |
| Revalidation | Actual HTTP 304 versus an unchanged/cached 200 response |
| Restart/offline | A retained local snapshot versus verified network disconnection |
| Renderer reload | Required re-import, retained selection/state, cleanup and recovery |
| Flight/navigation | Frame gaps, input response, collision integrity and background loading |
| Storage | SQL microbenchmarks versus complete Drift/SQLite/Web storage behavior |

HTTP bytes are UTF-8 bytes; encoded bridge lengths are UTF-16 code units. Bridge
round-trip duration includes renderer work and must not be added to its individual
stages. The first Cesium `postRender` callback is not a GPU completion timestamp.
Use device/browser profiling tools for GPU time, GC, peak heap and process memory.
Successful imports and feature counts do not certify airspace coverage or validity.

## Opt-in diagnostics

```sh
flutter run --profile --dart-define=FPV_LIFECYCLE_PROFILE=true
```

The lifecycle probe records generic phases, counts and durations. `app-start`
begins at Dart `main`, not OS process launch. `app-resumed durationMs` is time in
the background; `resume-to-globe-ready` measures the subsequent renderer recovery.
Collect logs explicitly with `flutter logs` and keep them local.

`GlobeController.scenePerformance(action: 'start' | 'snapshot' | 'stop')` provides
bounded CPU-render and frame-interval summaries, plus estimated resident tileset
bytes. It is off by default and is not part of the normal map menu. Request-render
idle periods are excluded; the counters are not actual GPU timings or full memory.

## Explicit reports and comparisons

This example creates an illustrative report; its values are not new measurements:

```sh
node tool/performance_report.cjs --scenario=uas-cold-http200 --platform=android --network=wifi --cache=cold --renderer=native-webview --dataset-bytes=13494348 --features=1256 --metrics=httpTotalMs=1828,bridgeRoundTripMs=979 --out=.local-performance/android-cold-001.json
node tool/performance_suite.cjs --out=.local-performance/synthetic-001.json
node tool/performance_compare.cjs .local-performance/android-cold-001.json .local-performance/android-cold-002.json .local-performance/android-cold-003.json .local-performance/android-cold-004.json .local-performance/android-cold-005.json --out=.local-performance/android-cold-summary.json
```

The report tool accepts only its documented scenario/condition/metric fields.
Optional `--lifecycle-log=<path>` and `--scene-json=<path>` inputs are capped at
5 MiB and reduced to allowlisted summaries. Coordinates, identifiers, credentials
and arbitrary log text are not copied. Output requires an explicit path and never
overwrites an existing file. The comparison tool rejects mixed platforms,
conditions, datasets or synthetic/physical results. It does not infer causality.

Files in `.local-performance/` are ignored by Git. No report, telemetry upload,
device discovery or native profiler collection runs automatically. Share a report
only after deliberately reviewing and exporting it.

## Dated reference observations

[The 2026-11-05 reference](performance/device_reference_2026-11-05.json) preserves
six user-operated, single-run Windows/WebView2, Chrome and Galaxy S22 observations.
The official UAS response then contained 1,256 features in 13,494,145 bytes; cold
HTTP transfer times were 3,553 ms, 1,840 ms and 28,188 ms respectively. The JSON
retains the remaining stages, restart samples and measurement limitations.

Those observations preceded later renderer/data changes. They are provenance,
not a current target, a controlled before/after comparison or a CI baseline.
The S22's slow network measurements do not establish the cause of later frame
stalls. Use new, paired measurements when evaluating a current build.
