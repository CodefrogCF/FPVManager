# Live RF motion measurements

Measurements begun 2026-11-24; final validation 2026-11-25. These are deterministic synthetic measurements of the actual
Flutter `LiveRadioController` and its adaptive terrain sampler. They are not
recorded-flight, real-provider, GPU, or Android/WebView latency measurements.

## Fixture and interpretation

`test/features/signal/live_radio_motion_benchmark_test.dart` runs 64 scenarios:

- Nominal ranges: 1, 3, 5 and approximately 6 km (5,990 m for the fixed-radius case).
- Speeds: 100 and 140 km/h.
- Straight radial motion and lateral motion around a constant-radius circle.
- Prescribed terrain batch delays of 160 or 400 ms.
- An analytic clear mountain ring and an independently known obstructing ring.

The terrain function returns heights for the exact requested coordinates.
Each scenario lasts 12 simulated seconds with 20 ms observation ticks. The
pose telemetry cadence is 400 ms at 100 km/h and 200 ms at 140 km/h, matching
the renderer's existing speed-dependent publication intervals. Results include
both the complete interval and the interval after a two-second startup window.
Unknown intervals are sampled at 20-ms resolution; transition boundaries are
therefore quantized by up to one tick. Calculation latency is measured by the
deterministic clock independently of that interval counter.
Straight radial cases report their initial/final actual ranges; the nominal
6-km radial case crosses the existing sampling-tier boundary. Use lateral
cases for comparisons at a fixed path distance.

Every batch, including a request for a cached or single new endpoint, receives
the stated synthetic delay. This is a controlled stress fixture, not a model
of the actual provider's decoded-tile cache. It isolates scheduling, coverage
and motion-driven result rejection. The existing JS cache benchmark is a
different measurement of cache/provider behavior.

Recorded metrics are valid publication count, valid-observation time fraction,
unknown duration and maximum consecutive unknown interval, calculation P50/P95,
terrain batch/sample counts, published endpoint drift from the latest received
telemetry, single-flight pressure and false-clear publications. All 64 cases
assert zero false-clear publications against the analytic obstructing ring and
at most one active terrain batch. The fixture deliberately does not assert
that missing or overtaken data must become valid.

## Confirmed baseline failure path

The baseline movement tolerance is 12 m at 100 km/h and approximately 13.6 m
at 140 km/h. These are necessary spatial limits near terrain edges, but they
mean a completed clear profile can be rejected after only about 432/350 ms
of aircraft motion. The 256-point first pass around 5–6 km exceeds the 16-m
clear-coverage gap budget, so clear classification requires another query.
After an unusable profile the old fast-flight policy reduced that first pass
to 96 points. This increased the number of round trips and created a feedback
loop in which clear profiles were repeatedly overtaken before publication.

Near 6 km the 5.99–6 m candidate grid requires at least 501 points to keep
every interval within the existing 16-m budget. A first pass of 96 points plus
384 refinement points permits only 480 total points. It therefore cannot
establish the same clear-coverage bound in this case, independently of network
speed. The normal 256+384 budget does permit that coverage.

The supplied baseline was verified against the current original source and
executed in a separate writable workspace copy. Examples from the fixed-radius
clear scenarios, after excluding the two-second startup window:

| Range / speed | Batch delay | Valid observation time | Maximum unknown interval |
|---|---:|---:|---:|
| 1 km / 140 km/h | 160 ms | 52.0% | 200 ms |
| 1 km / 140 km/h | 400 ms | 0.0% | 11,600 ms |
| 5 km / 100 km/h | 160 ms | 57.4% | 360 ms |
| 5 km / 140 km/h | 160 ms | 0.0% | 11,600 ms |
| 5 km / 140 km/h | 400 ms | 0.0% | 12,000 ms |
| 5.99 km / 140 km/h | 160 ms | 0.0% | 11,600 ms |

The 5-km, 140-km/h, 160-ms baseline case made 76 terrain batches requesting
9,221 samples but produced only one valid publication during the 12-second
fixture. All baseline scenarios retained zero false-clear publications.

## Implemented policy and sampling change

Uncertainty now supplies a HUD notice and does not itself activate hold,
descent, failsafe or GPS Rescue. Brief gaps pause pending confirmed-loss time;
after the five-second freshness horizon that pending evidence is discarded.
An already active maneuver which was triggered by confirmed modeled RC loss
continues to use its existing sequence and fresh recovery criteria. Unknown
data is neither asserted recovery nor newly confirmed RF loss.

For faster flight the sampler plans the uniform gap-filling points needed for
the existing clear-coverage limit before the first terrain round trip. It
uses the existing per-profile coarse/refinement budgets and candidate grid.
Around 5–6 km this combines the normal 256-point pass and the needed midpoint
refinement into one logical query. The old 96-point failure fallback is
removed. The logical query transport guard is the existing 4,096-point geometry
bound; it is not a new per-profile sampling budget or a requirement to sample
4,096 points. JavaScript terrain worker concurrency remains separately bounded. Only complete
midpoint waves are fused; if the remaining budget cannot fit a whole wave,
measured relief/Fresnel priorities still select the partial refinement across
the entire path. A 49.9 km stress regression with an intentionally small refinement budget
verifies that a remote-end obstruction receives the same priority as the
ordinary adaptive sampler.

The near-field fast-flight scheduler also follows the renderer's existing
pose cadence: 200 ms at at least 30 m/s and 400 ms at at least 12 m/s. Previously
its 250/450 ms intervals could repeatedly start between telemetry updates,
capturing an older endpoint and expiring otherwise fast results. The spatial
movement/freshness limits are preserved; the scheduler does not reinterpret
an old ray as the current ray. The selected near-field request cadence can
increase request count compared with the former 250/450 ms limit. The reports
include that overhead rather than treating lower latency as free work.

Rüdersdorf's selected BKG beta terrain is a separate provider limitation. Its
vertical datum has not been validated for this application's WGS84-ellipsoidal
RF calculations, so the existing refusal to use it for RF is preserved. The
application now categorizes that condition as unavailable terrain and exposes
its reason. This change permits normal manual flight with an uncertainty
notice; it does not claim to enable accurate RF analysis on that provider.

The [BKG basemap.de 3D service documentation](https://sgx.geodatenzentrum.de/web_public/gdz/dokumentation/deu/basemap.de_3d.pdf)
names EPSG:4326 for Cesium and identifies ATKIS DGM5 as the terrain source.
The [DGM5 documentation](https://sgx.geodatenzentrum.de/public/gdz/dokumentation/deu/dgm5.pdf)
identifies DHHN2016/92 heights for that source dataset. These statements do
not establish whether the final 3D mesh height values were converted to
WGS84 ellipsoidal heights. The application's refusal is therefore an
unresolved height-reference validation issue, not a claim that the rendered
terrain is absent or that a particular unverified conversion was performed.

## Selected final before/after results

Both source versions passed all 64 fixture cases and preserved zero false-clear
publications and a maximum of one active terrain batch. The final candidate
combines gap-filling in the first query with the aligned pose cadence; these
are measurements of that final implementation, not of an intermediate change.

The following table uses fixed-radius **clear** paths and the window after the
two-second startup period. A percentage is the fraction of time a valid
geometric observation was available, not a measured radio reception rate.

| Range / speed | Batch delay | Valid time before → after | Terrain batches before → after |
|---|---:|---:|---:|
| 1 km / 100 km/h | 160 ms | 85.6% → 100.0% | 27 → 30 |
| 1 km / 140 km/h | 160 ms | 52.0% → 100.0% | 49 → 60 |
| 3 km / 100 km/h | 160 ms | 85.6% → 100.0% | 27 → 30 |
| 3 km / 140 km/h | 160 ms | 52.0% → 100.0% | 49 → 60 |
| 5 km / 100 km/h | 160 ms | 57.4% → 100.0% | 54 → 30 |
| 5 km / 100 km/h | 400 ms | 0.0% → 100.0% | 31 → 30 |
| 5 km / 140 km/h | 160 ms | 0.0% → 100.0% | 76 → 60 |
| 5 km / 140 km/h | 400 ms | 0.0% → 0.0% | 31 → 31 |
| 5.99 km / 100 km/h | 160 ms | 57.4% → 100.0% | 54 → 30 |
| 5.99 km / 140 km/h | 160 ms | 0.0% → 100.0% | 76 → 60 |

At 5 km / 140 km/h / 160 ms, calculation P50/P95 changed from 320/480 ms to
160/160 ms in the prescribed-delay clock. Valid publications increased from
one to 60 during the complete 12-second fixture. The final unknown interval
was limited to initial acquisition in this scenario. The requested sample
count increased from 9,221 to 30,660 because the old feedback policy repeatedly
abandoned sparse 96-point attempts, while the final implementation completed
the necessary clear-coverage sampling. This is an accuracy/resource tradeoff,
not a claim that every resource count decreased.

At 1–3 km the faster cadence increases logical request count: for example,
49 to 60 batches at 140 km/h with a 160-ms delay. The terrain cache/worker
limits remain independently bounded. This fixture does not measure the real
provider's extra tile traffic or mobile CPU cost from that cadence.

With 400-ms batches at 140 km/h, the aircraft can still move beyond the
unchanged spatial freshness limit before a usable profile is available. Those
cases intentionally remain unknown; the fix does not widen the limit or
promote old clear data to restored signal. Under the new policy that condition
causes a HUD notice rather than a new autonomous hold or failsafe.

Raw data: [baseline](../performance/live_rf_motion_before_2026-11-24.json),
[final](../performance/live_rf_motion_after_2026-11-24.json), and
[keyed comparison](../performance/live_rf_motion_comparison_2026-11-24.json).

## Reproducing the comparison

Run the same test file in an isolated copy of each source version. The report
output is optional; ordinary regression runs do not write measurement files.

```powershell
$env:FPV_RF_MOTION_BENCHMARK_OUTPUT = 'C:\workspace\motion-after.json'
flutter test test/features/signal/live_radio_motion_benchmark_test.dart --reporter expanded
node tool/compare_live_rf_motion.cjs motion-before.json motion-after.json motion-comparison.json
```

The comparison tool rejects mismatched fixtures or scenario keys and verifies
that the resulting scenarios preserve the no-false-clear and single-flight
invariants. Interpreting an improvement in this prescribed-delay fixture as a
real-device speedup would require a separate matched flight/provider test.

## Final validation and delivery (2026-11-25)

| Command | Final result |
|---|---|
| `flutter analyze` | Passed; no issues found. |
| `flutter test` | Passed; 1,073 tests. |
| `node --test test/js/*.test.cjs` | Passed; 991 tests, zero skipped. |
| Targeted sampler, cadence and controller regressions | Passed; 54 tests. |
| `dart format --output=none --set-exit-if-changed` on ten changed/new Dart files | Passed; zero formatting changes. |
| Deterministic motion comparison | 64 scenarios per source version; zero false clears in the analytic fixture, one active terrain batch maximum. |
| Actual Chromium / JSON bridge fixture | Passed eleven checks, including 511 samples; four active tile workers maximum, zero fallbacks. |

The replacement ZIP preserves repository-relative paths and includes a manifest
with baseline/replacement SHA-256 hashes. The original checkout was only read.
Its separate `pubspec.yaml` version bump is deliberately excluded from this
delivery. Compare baseline hashes before replacing files that have changed
since the snapshot. Rebuild/restart the app after applying the files so the
JavaScript assets are refreshed.

The existing native browser-timer hotfix is retained. Advanced/Legacy physics,
RF model parameters and configured loss/recovery delays are not changed.
The analysis-uncertainty policy is intentionally changed to a passive notice.
This does not make unverified BKG beta heights suitable for RF calculations;
those flights remain manually controllable with an explicit unavailability
reason. A new Android device flight and matched provider performance test
remain outside these automated measurements.
