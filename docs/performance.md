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
  graphics profile. While tiles are pending, fast turns or low-altitude frame
  stalls briefly ease terrain refinement; normal detail returns in small steps
  after the view settles. Resolution and collision checks remain unchanged.
  These budgets do not promise a particular device frame rate.
- Large explicit 3D tileset header trees are partitioned into local external
  subtilesets with up to 64 headers each. Preparation yields after about 2 ms;
  construction drains in small batches between frames. Geometry payloads,
  transforms, materials, source credits and configured LOD thresholds are
  retained. Cesium reads local header fragments from memory, with a 64 MiB cap
  per tileset. Destruction releases the fragments. Implicit or unsupported
  trees use ordinary loading.
- Vegetation reuses swisstopo's instanced tree batches. The replacement meshes
  use 40 triangles and one primitive each. Foliage meshes omit transparent
  margins around the atlas cells. Model selection runs when a batch loads,
  using one shared local raster. The
  [vegetation comparison](performance/vegetation_2026-11-11.json) records WebGL
  draw calls and timing at ground and overhead views.
- Geographic model bounds enclose the full source content and child regions,
  including overhanging halls. Late external loads update cached ancestor
  volumes so buildings remain visible at the edge of a wide flight view.
  Bounds repair also runs when the local-header memory cap prevents splitting.
  Camera FOV, normal offscreen culling, payloads and graphics settings remain
  unchanged; no general overscan or extra preload pass is added.
- Before activating flight controls, the renderer prepares common terrain
  shader variants for imagery, fog, quantization and underground views. This
  avoids first-use driver compilation during low flight and turns. Preparation
  is cancellable, has a 15-second budget and reuses Cesium's cached programs on
  later flights. The existing pending indicator remains available; first entry
  can take several seconds. Parallel compilation is used when the driver offers
  it. New materials or uncommon variants can still require normal compilation.
  When a 3D layer is enabled, its shared material-lighting lookup is also
  initialized before controls activate; later flights reuse the same texture.
  With swisstopo vegetation enabled, one hidden instance prepares both tree
  lighting variants and releases its geometry after obtaining the programs.
  The [showcase flight comparison](performance/showcase_flight_2026-11-14.json)
  records shader waits and frame intervals in a dense forest.
- Flight preparation also initializes the sky, Sun bloom and Moon programs.
  Fast rotations and vertical speeds of at least 10 m/s below 100 m AGL briefly
  reduce Cesium's terrain tile load time slice from 5 ms to 2 ms. This is a
  scheduling target. A single tile operation can take longer. The
  [Acro test with swisstopo terrain](performance/acro_maneuvers_2026-11-11.json)
  records the remaining frame gaps as well as the reduction in shader waits.
- Terrain collision rays only visit rendered tiles within the current movement
  segment. Height and contact queries reuse exact decoded terrain vertices and
  binary bounds instead of repeatedly decoding full meshes. The additional
  cache is limited to 16 MiB and 64 meshes and is released on flight exit.
  Skirts, back faces and terrain exaggeration retain their existing behavior;
  unsupported runtimes use Cesium's original queries. No collision samples or
  source triangles are removed.
- Camera movement runs before Cesium detects camera motion and underground
  transitions, so those checks observe the current flight pose too.
- Tunnel geometry is prepared one model per render opportunity during flight.
  Shared vertices and opaque drawing materials are reused; the newly occupied
  corridor's collision mesh is prepared before handoff. Long source axes retain
  their height anchors and overlapping windows. Curve masks update in place.
- Native bridge discovery and resident deck checks permit one depth probe per
  rendered opportunity; already confirmed native profiles avoid duplicate picks.
  Unchanged pier geometry retains its existing primitive.
  Its periodic source search follows the aircraft/ground camera coordinates
  during navigation, avoiding an unbounded screen-centre terrain ray every
  two seconds. Normal map browsing retains visible-ground targeting.
- The optional approximate model-height collision probe is deferred until after
  the visible frame and uses a short-lived, nearby result. Exact synthetic tunnel
  collision stays independent. Flight gaps above 75 ms discard excess elapsed
  time instead of applying a large catch-up movement on the next image.
- Opt-in scene timing includes pauses longer than 250 ms during active,
  unpaused flight and reports counts above 100 ms. Idle/background gaps stay
  separate; a long actual render is not discarded from CPU timing.

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

[The 2026-11-10 flight traces](performance/flight_trace_2026-11-10.json) record
public-test-point measurements on Windows/Chrome with an Intel UHD GPU and the
85% profile. They distinguish driver preparation, CPU collision work, main-thread
tasks and Cesium `postRender` intervals. These are individual desktop observations,
not an Android FPS result or proof that every future frame will meet a deadline.

[The additional 2026-11-10 streaming observations](performance/scene_streaming_2026-11-10.json)
cover terrain plus the three official 3D layers in Quality mode. They isolate
large header construction and the recurring bridge-search terrain pick, and
retain cold graphics-driver pauses and other remaining limits in the report.

[The building visibility check](performance/building_visibility_2026-11-10.json)
records the original hall headers and a controlled rendering comparison at
105 degrees. It verifies visibility correctness rather than device frame rate.
