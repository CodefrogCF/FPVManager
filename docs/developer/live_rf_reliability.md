# Live RF terrain reliability investigation

Date: 2026-11-24. The baseline is the supplied working tree, including its R40
RF and Advanced Physics changes. This investigation does not use an older
archive as the baseline. The original checkout is read-only; the delivery ZIP
contains repository-relative replacement and new files from an isolated copy.

## Architecture and existing safeguards

1. `web/features/flight/free_flight.js` publishes simulated aircraft poses.
   `web/globe.js` passes them to `liveRadio.observe()`. The renderer emits
   `flight-radio-position` at speed-dependent intervals of 200, 400 or 750 ms,
   plus flight lifecycle changes. This is separate from per-frame flight control.
2. `lib/features/signal/live_radio_controller.dart` owns configuration, latest
   pose, flight identity, scheduling, result freshness and publication. Its
   near-field update interval is 250, 450 or 800 ms according to speed.
   Terrain generations and display message revisions were already separate.
3. `live_terrain_sampler.dart` requests a geodesic first pass and adaptively
   refines large gaps, steep relief and Fresnel conflicts. It uses the existing
   `calculateRadioLink()` kernel. An evidenced obstruction can end refinement;
   sparse clear coverage remains limited. The existing 1–50 km tiers, near-field
   256-point first pass, 16 m clear coverage criterion, 5–6 m candidate grid and
   maximum 256 positions per bridge command are preserved.
4. `GlobeController._queryLiveRadioTerrain()` sends
   `query-live-radio-terrain`. It checks terrain generation, WGS84 ellipsoidal
   datum, `most-detailed-available`, result length and every finite height. The
   bridge already has unique request IDs, session/event guards, bounded pending
   commands and cancellation messages. The baseline live query used the general
   30-second terrain-command deadline. The patched live query uses 12 seconds,
   matching the terrain manager's existing sampling budget; other terrain
   commands retain their configured deadlines.
5. `web/features/signal/live_radio.js` samples through the terrain manager and
   `live_terrain_tile_cache.js`. Exact-coordinate heights have a 30-second,
   4,096-entry cache. Highest-available decoded tiles have a provider-scoped,
   128-entry, 120-second cache. Four workers limit tile request pressure; warm
   tiles are processed first to avoid scan thrashing. Paths beyond the existing
   local-cache extent retain Cesium's most-detailed bulk sampler. There is no
   coarse-LOD substitution or rounded-coordinate height reuse.
6. `set-live-radio-result` publishes geometry and assessment. The renderer's
   existing `rf_estimation.js` calculates separate illustrative RC and video
   link budgets. A terrain intersection alone does not assert total RC loss.
   `onAssessmentChange` and aircraft updates feed the assessment to
   `free_flight.js`, whose shared failsafe module drives Legacy and Advanced
   flight control. `simulated_failsafe.js` owns loss/recovery thresholds,
   hysteresis, configured delays and Rescue phases. Advanced autonomous motion
   continues through the existing flight-control and physics modules.
7. Provider changes invalidate terrain generations/caches and old results.
   Regional BKG beta terrain remains excluded from RF planning by `globe.js`.
   The terrain manager already bounds both sampling and normal provider tile
   requests at 12 seconds; renderer command timeouts are longer.

## Confirmed defects and evidence

- **Missing observations reset pending loss.** In the supplied baseline,
  `simulated_failsafe.step()` treated `rcQuality() === null` identically to
  quality above the loss threshold while normal/pending: it reset `lossTime`
  and restored the normal phase. Thus blocked → unknown → blocked restarted
  the configured delay despite unknown supplying no recovery evidence.
- **Sampling cancellation did not stop tile work promptly.** In the supplied
  tile cache, `getTile()` called `check(undefined, epoch)` throughout its retry
  and completion path. A cancelled consumer waited for the shared tile promise
  to settle before noticing its signal. Workers caught cancellation and
  generation errors with ordinary interpolation failures and could launch more
  groups or native fallback. This is reproducible with deferred mocked tiles.
- **The cache itself could retain an unresolved tile promise.** A pending
  `{ work }` entry was installed before awaiting tile IO and shared with later
  profiles until its 120-second TTL. The module had no independent bound.
  A mock provider which ignores cancellation/timeouts causes successive
  12-second profile failures to join the same unresolved tile. The normal
  production terrain provider also has a 12-second tile bound, so this
  fault-injection reproduction is not proof of a 120-second production stall.
- **The Dart scheduler depended on downstream completion.** It held `_pending`
  until the entire asynchronous profile and result publication settled.
  There was no controller-level watchdog for a non-settling sampler, and a
  follow-up attempted inside the throttle interval had no scheduled wake-up.
  These are scheduler failure paths, even though the normal bridge usually
  supplies a separate timeout and frequent telemetry.
- **Elapsed scheduling and profile freshness used wall time.** Baseline
  throttling and calculation duration used `DateTime.now()`. Profile validity
  was stamped at completion, giving a long-running calculation a new full
  display lifetime. Clock adjustments and acquisition age therefore were not
  independently represented.
- **Exact-point cache hits did not verify current terrain detail.** The baseline
  height cache used coordinate and TTL alone. If availability discovered a
  finer terrain level, the same coordinate could continue returning its earlier
  height for up to 30 seconds despite the tile cache correctly detecting the
  new level. Cache entries now record their provider detail level and are
  resampled when availability changes. This is a precision failure path,
  not evidence of the provider's behavior during the unavailable recording.

Existing generation guards, warm-tile ordering, adaptive precision, spatial
movement rejection and the separation of geometric LoS from RF modeling are
retained. They are not presented as newly discovered missing functionality.

## Implemented reliability and diagnostics

The controller now has one active calculation and one replaceable latest-pose
slot, a scheduled throttle wake-up, request/generation fencing, cancellation
on lifecycle changes and a recoverable 12-second calculation budget. Monotonic
elapsed time drives scheduling, latency and freshness. Results age from the
captured aircraft pose; bridge transit time also consumes the existing
five-second observation horizon. A delayed profile cannot become newly fresh
merely by completing, nor overwrite a newer generation.

The terrain adapter releases cancelled/timed-out request slots, rejects older
analysis generations, and keeps reusable detailed tile work independently
bounded. Cancelled workers stop launching further tile groups or fallback.
Successful shared tiles can still warm the provider cache without publishing
an obsolete aircraft assessment. Missing/invalid samples remain explicit
errors; the most-detailed sampling path and existing precision policy remain.

Observation quality is separate from geometric LoS and modeled RF quality.
Pending, stale, unavailable and erroneous observations cannot restore signal
or authorize a new recovery. Brief gaps pause the accumulated confirmed-loss
time instead of resetting it or adding unsupported loss time. Beyond the
five-second evidence horizon, the simulator exposes uncertain/hold behavior
without asserting RF loss or starting GPS Rescue from uncertainty alone.
Already active Rescue retains its configured sequence; takeover still requires
qualified fresh recovery and deliberate pilot input.

Diagnostics retain bounded request/latency histories and record request and
generation IDs, monotonic start/completion/duration, valid/missing samples,
provider, current range, movement since the last observation, age, active/queued
counts, failure categories and RF/failsafe state. Collection is per request or
on explicit snapshots; it does not stream per-frame logs. The optional HUD
panel is disabled by default and refreshes at most once per second. Percentile
snapshots are computed only when diagnostics are requested.

## What the evidence does not establish

The referenced `30890.mp4` is not present in the supplied repository/workspace.
The exact network/provider/aircraft timeline from that flight cannot therefore
be reconstructed. Missing tiles, provider delays and aircraft movement can each
produce unknown observations by design. There is no measured evidence here of
bridge congestion, excessive JSON serialization cost, a provider switch during
the recorded flight, or a precision problem requiring a different LoS engine.
No bridge compression, timeout increase, terrain-detail reduction or new
arbitrary sampling cap is justified by these findings.

## Reproducible sampling measurements

`tool/benchmark_live_rf_reliability.cjs` runs the original and patched JS modules
against identical analytic mountainous terrain at approximately 1, 3 and 6 km.
It uses the bundled Cesium coordinate/tiling math, exact requested-coordinate
height interpolation, level-17 availability and a deterministic clock. Each
mock tile takes a prescribed 80 ms; four existing workers overlap requests.
Profiles contain the existing near-field first-pass point count and are
requested every two seconds for 30 attempts, stationary or with rapid lateral
motion. Additional scenarios inject missing heights and one non-settling tile.

```powershell
node --expose-gc tool/benchmark_live_rf_reliability.cjs --baseline="C:\path\to\original\FPVManager" --out=docs/performance/live_rf_reliability_2026-11-24.json
```

The JSON records sampling success, failed-sampling frequency and unavailable
intervals, prescribed IO P50/P95, cold latency, actual Node fixture CPU time,
tile requests, interpolation counts, terrain batches and serialized command /
response payload bytes. Failure intervals refer to this sampling fixture;
they are not the HUD's unknown duration. Per-scenario process heap measurements
record `process.memoryUsage().heapUsed` before, at sampled peaks and after
disposal/microtask draining. `--expose-gc` enables explicit GC before and after
each scenario; the JSON records whether it was available. These numbers include
fixture promises, analytic terrain, reports and retained module allocations.
They are sampled process observations, not application/device or GPU memory
measurements. Sequential retention and GC variation prevent a memory improvement
claim. The existing entry-count bounds remain separate retention guarantees.
Short Node CPU timing differences also must not be presented as device speedups.

The recorded run is
[`../performance/live_rf_reliability_2026-11-24.json`](../performance/live_rf_reliability_2026-11-24.json).
Healthy sampling produced the same terrain requests and interpolation counts
before and after the fix, with 30/30 successful samples for every distance and
motion case. SHA-256 comparisons of the successful height streams match
exactly in all healthy and missing-data scenarios. The stationary warm-cache
P50/P95 are both 0 ms in this prescribed
IO clock; this excludes actual CPU execution time.

| Rapid-motion path | P50 before → after | P95 before → after | Cold first sample before → after | Tile requests before → after |
|---|---:|---:|---:|---:|
| 1 km | 0 → 0 ms | 160 → 160 ms | 240 → 240 ms | 20 → 20 |
| 3 km | 0 → 0 ms | 480 → 480 ms | 640 → 640 ms | 55 → 55 |
| 6 km | 0 → 0 ms | 960 → 960 ms | 1200 → 1200 ms | 108 → 108 |

The missing-data scenario remains 26/30 successful observations in both
versions: the four unavailable terrain batches are still errors, never clear
or blocked observations. With an intentionally non-settling first tile, the
baseline produced 0/5 successful observations and a 60-second unavailable
interval in the fixture. The patched sampler timed out its first attempt and
recovered on the next, producing 4/5 successes and a 12.56-second maximum
unavailable interval. This demonstrates recovery from the injected provider
failure; it is not a measurement of how often the normal provider fails.

Healthy rapid-motion response payloads increased from 115,844 / 146,603 /
146,666 bytes to 126,434 / 157,198 / 157,336 bytes over 30 requests at 1 / 3 /
6 km, respectively. This is approximately 353 additional bytes per response
for diagnostics. Command payload sizes, tile requests and interpolation counts
did not increase. Exact-height entries plateaued at 4,096 during rapid motion.
No real latency or throughput improvement is claimed for healthy sampling.

The final run used explicit GC. Healthy rapid-motion process heap observations
were as follows (MiB; before / sampled peak / after disposal and GC):

| Path | Original process heap | Patched process heap |
|---|---:|---:|
| 1 km | 23.29 / 27.76 / 23.41 | 23.65 / 31.62 / 23.76 |
| 3 km | 23.40 / 32.02 / 23.42 | 23.68 / 31.76 / 23.72 |
| 6 km | 23.38 / 31.76 / 23.41 | 23.70 / 32.17 / 23.78 |

All eight scenarios' before/peak/end byte counts are retained in the JSON.
These shared-process measurements show the fixture's allocation scale; they
do not establish a device memory regression or improvement. The original
checkout was only read to load the baseline modules and remained unmodified.

Real WebView transport time, provider/network latency, device heap/GPU memory, full
Flutter calculation latency and the recorded flight's unknown frequency remain
unmeasured. A device replay in profile mode with matching provider, station,
RF profiles, route, altitude and speed is required to quantify those outcomes.

## Validation

The implementation and automated validation results accompany this report in
the delivery manifest. The required checks are `flutter analyze`,
`flutter test`, and `node --test test/js/*.test.cjs`. Targeted deterministic
tests cover request recovery, stale/out-of-order results, sampling failures,
freshness, loss continuity and Rescue behavior through both physics modes.

Final validation on Windows x64, Flutter 3.47.0 / Dart 3.13.0:

| Command | Final result |
|---|---|
| `flutter analyze` | Passed; no issues found (31.6 s). |
| `flutter test` | Passed; 999 tests (4 min 45 s). |
| `node --test test/js/*.test.cjs` | Passed; 978 tests, zero failures/skips (22.55 s). |
| `dart format --output=none --set-exit-if-changed` on all six changed/new Dart files | Passed; zero formatting changes. |
| Targeted Flutter controller and settings tests | Passed; 28 tests. |
| Synthetic before/after terrain benchmark with explicit GC | Completed; comparable successful-height streams match exactly. |

Both independent SHA-256 scans of the 1,546 baseline-manifest files in the
original checkout found zero changed or missing files. Validation ran only
in the isolated work copy. Generated build/dependency files and test logs are
excluded from the replacement ZIP.

## Changed-file summary and use

The ZIP preserves repository-relative paths. Its delivery manifest records
the baseline and replacement SHA-256 of every payload file. Compare the
baseline hashes before replacing a file that has changed since this snapshot.

| Area | Files and purpose |
|---|---|
| Flutter scheduling | `live_radio_controller.dart`: latest-pose slot, recoverable watchdog, lifecycle cancellation, monotonic capture freshness and explicit result quality. `live_radio_diagnostics.dart`: bounded 64-request history and latency percentiles. |
| Bridge and settings | `globe_controller.dart`: live-query generation/request identity, matching 12-second deadline and validated sampler metadata. `live_radio_sheet.dart`: optional diagnostics switch and details. `web/globe.js`: diagnostic command and HUD wiring. |
| Cesium sampling | `live_radio.js`: recoverable sample slot, exact-key deduplication, observation metadata and diagnostics. `live_terrain_tile_cache.js`: bounded shared I/O, prompt consumer cancellation and provider-aware detailed tile reuse. |
| Simulated control | `simulated_failsafe.js`: preserved confirmed loss time, bounded uncertainty and fresh recovery. `free_flight.js`: revalidate evidence for every manual takeover entry point; no physics equations changed. |
| HUD | `flight_hud.js` and `flight_hud.css`: explicit uncertainty label and opt-in debug panel, updated at most once per second. |
| Regression tests | `live_radio_controller_test.dart`, `live_radio_sheet_test.dart`, `live_radio.test.cjs`, `live_terrain_tile_cache.test.cjs`, `simulated_failsafe.test.cjs`, `flight_hud.test.cjs`, and new `rf_observation_freshness.test.cjs`. |
| Evidence | New `benchmark_live_rf_reliability.cjs`, this report, and the synthetic before/after JSON. |

Open the existing live-radio settings and enable **Live RF diagnostics** to
show the session-only debug panel. It is off by default and does not enable
failsafe, GPS Rescue or manual training. The panel shows observation quality,
age, calculation latency/P50/P95, active/latest queued requests, failures,
sample counts, range, movement, provider and actual RC/failsafe state.

Automated coverage includes successful and missing sampling, high latency,
timeouts and recovery, stale/out-of-order results, superseded generations,
provider changes, repeated errors, long-distance mountainous profiles,
rapid movement, clear/blocked/unknown sequences, brief pending-loss gaps,
prolonged uncertainty, configured Rescue phases, and both physics models.
