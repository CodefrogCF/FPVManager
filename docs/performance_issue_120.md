# Issue #120 — Cross-platform performance regression benchmarks and developer diagnostics

**Implementation:** synthetic correctness/protocol guardrails, explicit local report/export utilities, device scenario definitions, and Issue #47 historical reference data.

**Verification status:** Node tests and synthetic CI checks can be run without Flutter. Actual device/GPU/memory/cold-start regressions are still manual platform obligations, **not** inferred from CI timings. No new analytics, accounts, service, background fetch, consent bypass or automatic upload.

## What changed

| Component | Role | Scope and limitations |
| --- | --- | --- |
| `tool/performance_suite.cjs` | Runs existing `benchmark_globe_transfer.cjs` and `benchmark_scene_scheduling.cjs` | Synthetic Node fixtures only. `--check` exits nonzero if deterministic protocol invariants fail; timing values are not pass/fail thresholds. |
| `tool/performance_ci_baselines.json` | Versioned deterministic invariants | 18,000 features survive bridge; compressed chunk count remains lower; stable 3D-layer writes, requests, loads and removes are zero at 10,000 frames; height-based updates remain functional. |
| `tool/performance_report.cjs` | Manually create privacy-limited, structured local device report | Takes only explicitly supplied timing values and/or explicitly selected local lifecycle/scene files. No automatic device identification or data upload. |
| `tool/performance_compare.cjs` | Repeated-run p50/p95 summary | Refuses mismatched platform, scenario, conditions, dataset size, feature count, or synthetic/physical mixtures. No baseline/after causality claim. |
| `docs/performance/scenarios_issue_120.json` | Canonical test procedures | Cold load, warm HTTP 304, cached restart, offline-only, renderer reload, multi-layer navigation/simulation, SQLite, memory and lifecycle. |
| `docs/performance/issue47_reference_2026-11-05.json` | Source-faithful reference observations | Real Windows/Chrome/Galaxy S22 single measurements from #47, **not** CI timing budgets. |
| `test/js/performance_reporting.test.cjs` | Safeguards | Validates schema, source/CI distinction, leak-resistant import, local-only writes, reproducible scenarios, baseline failures, and Airspace UI exclusion. |
| `.github/workflows/ci.yml` | Quality CI guard | Runs the existing JS suite and the synthetic invariant check. No remote benchmark telemetry or network downloads added by these checks. |

The pre-existing, standalone tools are **retained** and remain useful:

```powershell
node tool/benchmark_globe_transfer.cjs
node tool/benchmark_scene_scheduling.cjs 10000
dart run tool/uas_loading_benchmark.dart
dart run tool/benchmark_uas_http.dart   # network request; run intentionally, NOT CI
dart run tool/benchmark_uas_memory.dart --features=1256 --runs=5
dart run tool/benchmark_uas_memory.dart --features=1256 --runs=5 --worker
dart run tool/benchmark_sqlite_cache.dart --tiles=10000 --spots=10000 --runs=3
```

The HTTP benchmark performs an intentional request to the official dataset endpoint when invoked. It is not called by `performance_suite.cjs` or in CI.

## Run synthetic CI guardrails (Windows PowerShell, FPVManager root)

```powershell
node --test test/js/*.test.cjs
node tool/performance_suite.cjs --check
# Optional: create one local report; no file is created when using only --check.
node tool/performance_suite.cjs --out=.local-performance/synthetic-001.json
```

The output file contains only the synthetic results. It does **not** claim actual GPU FPS, Android WebView frame rate, real GPU memory, user coordinates, or the performance of on-device storage.

CI intentionally **does not** gate on CPU time, RSS or GPU timings: those values depend on runners, JIT, thermal conditions, CI contention and browser/driver versions. It gates stable fixture sizes, transport preservation, expected resource state and redundant-work invariants. Existing Flutter, Chrome/Web, JS and database regression suites remain in CI. These protect correctness; they do not replace real-world measurements.

## Issue #47 historical starting reference

Source: [`performance/uas_measurements_2026-11-05.md`](performance/uas_measurements_2026-11-05.md). The machine-readable reference is [`performance/issue47_reference_2026-11-05.json`](performance/issue47_reference_2026-11-05.json).

| Initial cold-load stage | Windows / WebView2 | Chrome / Web | Galaxy S22 / Android |
| --- | ---: | ---: | ---: |
| HTTP transfer | 3,553 ms | 1,840 ms | 28,188 ms |
| Dart JSON parse | 1,502 ms | 220 ms | 592 ms |
| Flutter JSON encode | 1,102 ms | 328 ms | 364 ms |
| Bridge round trip | 4,451 ms | 3,597 ms | 4,988 ms |
| Cesium GeoJSON source load | 491 ms | 547 ms | 488 ms |
| First postRender callback | 720 ms | 679 ms | 735 ms |

The historical 2026-11-05 official GeoJSON body measured **13,494,145 bytes** with **1,256 features** and **102 bridge frames** under the then-current implementation. The revised official body subsequently measured **13,494,348 bytes** in #115: **do not silently compare as an identical data revision**. For a later same-network Galaxy S25 Ultra observation, HTTP 200 took 1,828 ms and HTTP 304 revalidation including local handling took 167 ms (see #115). The S22 has known reliability/thermal concerns and is kept only as a historical observation, not a mandatory performance target.

These are non-controlled **individual device measurements**, not a paired repeated A/B experiment. The bridge round trip **includes** JavaScript/render work, so never add its duration to renderer load time. `postRender` does not measure actual GPU completion. A warm restart from local cache is **not** evidence of an HTTP 304 or an offline network.

## Device measurement protocol

Procedures are in [`performance/scenarios_issue_120.json`](performance/scenarios_issue_120.json). Follow the same scene location/camera, app version and official dataset revision, network, cache mode, graphics profile, and reproducible gesture/flight sequence per comparison. Run at least **five repeated samples** in profile/release mode per supported platform and scenario (one JSON file per run); let the device cool between runs. Record actual dataset byte size and feature count, not assumptions copied from Issue #47. Handle missing stage values by omission, never as zero.

Required categories:

1. **Cold HTTP 200**: clear *public UAS cache only*, restart, confirm actual 200, measure HTTP/parse/bridge/Cesium.
2. **Warm 304**: keep ETag and unchanged official body, confirm actual 304 (otherwise mark not applicable). No geometry re-import should occur for an attached dataset.
3. **Warm restart / offline**: explicitly distinguish reused local cache from actual offline/disconnected network; preserve stale source/date warnings.
4. **Renderer reload**: ten reload/recovery cycles; verify re-attach as needed without duplicate objects, missing credits or lost safety geometry.
5. **Multi-layer camera and FPV simulation**: same scene and 60-second path, 5 samples for each graphics profile. Collect scene callback pacing, independent GPU/GC profiling, collision integrity and attribution. Idle gaps must not be presented as dropped frames.
6. **Navigation/warm resume**: ten globe/spots/routes/settings cycles and ten resumes; verify retained camera, local records, WebView focus/input, renderer identity, no duplicate requests and resource cleanup.
7. **SQLite/GeoJSON and backup**: keep synthetic CLI patterns separate from real-device Drift, platform Web storage, allocation, GC, peak RSS and export/import/restore measurements. Never discard personal records or expose them in benchmark output.

### Enable lifecycle diagnostics only for a profiling run

```powershell
flutter run --profile --dart-define=FPV_LIFECYCLE_PROFILE=true
# In another PowerShell terminal, with the app active:
New-Item -ItemType Directory -Force .local-performance | Out-Null
flutter logs | Select-String -Pattern 'FPVManager lifecycle' | Out-File -Encoding utf8 .local-performance/lifecycle-001.log
```

Stop the logging command manually after the test. This existing opt-in probe records generic lifecycle phases, counters and millisecond durations. `app-start` is **Dart main**, not OS process launch; `app-resumed durationMs` is **background residence**, not resume-to-interactive time. Only `resume-to-globe-ready` approximates the next renderer-ready interval. In case of abnormal/native engine relaunch, verify independently.

For the renderer's **opt-in** `GlobeController.scenePerformance(action: 'start' | 'snapshot' | 'stop')` API, see `docs/performance_issue_117.md`. Collect a bounded snapshot while moving the camera or flying, and save the returned JSON locally using a developer-run instrumented build or debugging session. The scene API remains unavailable in the normal map layer UI. CPU callbacks and inter-frame times are **not** actual GPU timing. Use Android Studio Profiler/DevTools, Instruments, Chrome/Edge performance tracing or WebView2 diagnostics for true memory, GC and GPU observations.

### Explicitly create a sanitized real-device report

The following values are **illustrative** (drawn from a previous S25 Ultra sample), not a new benchmark:

```powershell
node tool/performance_report.cjs `
  --scenario=uas-cold-http200 --platform=android `
  --network=wifi --cache=cold --renderer=native-webview `
  --dataset-bytes=13494348 --features=1256 `
  --metrics=httpTotalMs=1828,bridgeRoundTripMs=979 `
  --out=.local-performance/android-cold-001.json
```

To include **only allowlisted duration summaries** from a local diagnostic log, use `--lifecycle-log=.local-performance/lifecycle-001.log`. For a local scene snapshot use `--scene-json=.local-performance/scene-001.json`. Any additional JSON properties, free-text notes, URLs, identifiers, raw logs, positions and arbitrary performance labels are not copied into the output. Inputs are limited to 5 MiB; the output uses exclusive file creation (it will not overwrite an existing report).

For five homogeneous actual runs:

```powershell
node tool/performance_compare.cjs `
  .local-performance/android-cold-001.json `
  .local-performance/android-cold-002.json `
  .local-performance/android-cold-003.json `
  .local-performance/android-cold-004.json `
  .local-performance/android-cold-005.json `
  --out=.local-performance/android-cold-summary.json
```

The compare command refuses different platforms, datasets, scenarios, or conditions rather than averaging incompatible measurements. P50/P95 are nearest-rank percentiles, which are coarse for five runs. For a pre-/post-change claim compare **separate** homogeneous summaries from separate commits/builds, with complete test conditions recorded manually. The tool does not infer causality or emit a false pass/fail performance verdict.

All files inside `.local-performance/` are Git-ignored by default. The program does not automatically create records, invoke native log collection, read personal databases, contact a telemetry service, upload, or write outside the user-selected local output directory. Sharing an exported report is the developer's deliberate action.

## Verification and remaining limitations

- **Implemented and testable:** CI synthetic bridge and 3D scheduling invariants, scenario definitions, strict and local timing reports, privacy-limited import, repeated-run summaries, historical Issue #47 reference, normal Airspace menu exclusion and JS regression tests.
- **Previously available:** Dart UAS loading/HTTP/memory and SQLite benchmarks; production Flutter/Chrome tests; scene frame/tileset sampling and app lifecycle probe.
- **Must be tested by the project owner:** Android (Galaxy S25 Ultra recommended), iOS, Windows/WebView2 and Chrome/Web cold/warm/reload, navigation/focus, real scene pacing, allocations/GC/peak memory and Web SQLite recovery. CI runners cannot prove those metrics, nor that an app stays interactive during a failed online request.
- **Not claimed:** a specific measured before/after real-device FPS gain; automated GPU memory capture; strict cross-device performance limits; completed acceptance of all hardware-dependent items in #114–#119.

The v0.12.0 suite can be closed **as an instrumentation/CI feature** after local analyzer and Flutter tests pass; any missing real-device benchmark results should remain explicitly tracked rather than retroactively called measured.
