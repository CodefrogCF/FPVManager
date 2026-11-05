# UAS GeoJSON loading / rendering performance

## architectural decisions

The pipeline is:

1. `GeoJsonOsintProvider` → HTTP response (bounded to 60 MiB), with optional ETag/Last-Modified revalidation; local cache.
2. `utf8.decode` / `jsonDecode` → `Map<String, dynamic>`; Flutter `compute` offloads large JSON on native Android and Windows, while Flutter Web executes it on its own runtime.
3. `UasDatasetAssessment` → checks usable features without transforming their geometry coordinates. This is *not* an independent certification of nationwide coverage.
4. `GlobeBridge` → JSON encoding followed by ordered, bounded frames. Android/iOS use `runJavaScript`; Windows uses WebView2 `executeScript`; Web uses a same-origin iframe `postMessage`.
5. The page bridge joins/decodes the complete message and Cesium `GeoJsonDataSource.load` builds ground-clamped geometry, then attaches it to the viewer. The next `postRender` callback is recorded separately.

### Changes

- Default outgoing payload chunks increased from **32 Ki UTF-16 characters** to **96 Ki**. Chunk boundaries are reduced automatically if nested JSON escaping would exceed the **128 Ki frame** limit. The renderer retains ordered, length-delimited reconstruction, cancellation, timeouts and limits. This reduces the number of per-frame native WebView2/Android calls without assuming a maximum escaping ratio.
- **HTTP 304 with an already attached dataset** reuses Cesium's live source and preserves the selected feature. It refreshes source-check metadata without re-serializing or reimporting the identical geometry. A 200 response with changed data still imports transactionally, keeping the previous dataset on failure; renderer reload always requires an import.
- Dedicated local metrics collect the last HTTP status and transfer size, HTTP time, JSON parse time, geometry assessment time, Dart encoding, frame count/dispatch time, bridge acknowledgement (includes JS work), JS join/decode, Cesium load/attach and first post-render callback. These remain available in the controller and transport pipeline but **the detailed benchmark table is intentionally hidden from the normal Airspace map-layer UI**. Historic live measurements are recorded in `docs/performance/uas_measurements_2026-11-05.md`.
- No large binary/blob/file-based bridge was added: Android/iOS, desktop WebView2 and browser iframe have different file-origin, sandbox and CORS characteristics, and adding a second data copy is not automatically faster. A benchmark should establish a measurable win before choosing an additional transport format. Binary transfer remains a possible follow-up.

## Reproducible measurements (Android, Web, Windows)

**Do not treat synthetic timings as measured device performance.** None were collected on these target devices in the authoring environment. Record the real, device-specific before/after values in the table below before claiming a performance gain.

1. Use the same committed FPVManager snapshot before this patch, then the patched build. Run in `flutter run -d windows`, `flutter run -d chrome`, and on a specific Android physical device (`flutter run -d <device-id>`). Keep OS, WebView2/browser version, release/debug mode, network, and map position constant.
2. The detailed diagnostics panel has been removed from the normal Airspace overlay. The November 2026 runs were recorded before its removal in `docs/performance/uas_measurements_2026-11-05.md`. For future on-device stage timing, use a developer-only diagnostic build or explicit local logging; do **not** expect those fields in the normal UI. For a **cold HTTP 200**, clear the UAS cache, enable the layer and allow the first postRender measurement. Repeat three times per build; report median and range.
3. For **HTTP 304** on native platforms, refresh with an unchanged official ETag after a successful first load. The old version retransfers on 304; the new version only toggles visibility and updates cache metadata. Web may not send conditional requests by default, so mark 304 as unavailable instead of inferring it.
4. For a **warm renderer**, hide and re-show the layer, then reload the renderer and re-enable. Reuse is only possible with the renderer still alive. Compare device responsiveness and peak memory externally (Windows Task Manager, Android Studio profiler, Chrome DevTools).
5. Collect after/before **HTTP bytes and time, parse ms, assessment ms, encoded character length, frame count, frame dispatch ms, JS parse ms, Cesium source load ms, attach ms, next postRender ms**. The full acknowledgement **overlaps** rendering: never add it to Cesium load time. `postRender` is not a GPU completion timestamp.
6. Verify the feature count, source identity, geometry positions, selected-zone details, polygon opacity and source attribution match before and after. Validate multi-polygon, holes, data gaps, out-of-date cache, back-to-back refresh, and abort during transfer.

| Scenario / platform | Before (ms, frames) | After (ms, frames) | Notes |
| --- | --- | --- | --- |
| Cold Android – HTTP / parse / bridge / Cesium | _measure_ | _measure_ | Device/OS/WebView: |
| Cold Chrome – HTTP / parse / bridge / Cesium | _measure_ | _measure_ | Browser/version: |
| Cold Windows – HTTP / parse / bridge / Cesium | _measure_ | _measure_ | WebView2/GPU/version: |
| 304 revalidation – native | _measure_ | _measure_ | Same ETag, no reimport expected |
| Warm hide / re-show | _measure_ | _measure_ | No second fetch/import |
| Renderer reload / failed import recovery | _measure_ | _measure_ | Should reimport if needed |

### Synthetic, local-only comparison

```
dart run tool/uas_loading_benchmark.dart
# Optional: use a LOCAL copy of the official Swiss UAS GeoJSON, no upload:
dart run tool/uas_loading_benchmark.dart "C:\\path\\to\\einschraenkungen-drohnen_4326.geojson"
```

The command compares 32 Ki/96 Ki transfer counts with an in-memory mock renderer, reports the encoded size, and optionally JSON parsing time for the local input. It is **not** an estimate of Windows WebView2, Flutter Web, Android WebView, network or Cesium GPU time. Do not use its wall-clock numbers as before/after device results.

## Notes / limits

- HTTP response bytes and Dart String length use different units (UTF-8 bytes vs UTF-16 code units). Both are reported explicitly.
- On 304 the per-response HTTP bytes are zero and decode/parse time is zero; previous Cesium metrics still describe the last successful import.
- No geometry simplification or spatial filtering was enabled because those could change legally significant restrictions or holes. Any future optional generalization needs fidelity and topology tests against the official source.
- Performance values remain local and are not uploaded. The detailed timing table is not shown in the normal Airspace overlay; `tool/uas_loading_benchmark.dart` remains available for developer-only synthetic comparisons.
- Cesium `GeoJsonDataSource.load(..., clampToGround: true)` is intentionally retained. Profiling should determine whether its entity generation and ground primitives dominate on any given GPU.
