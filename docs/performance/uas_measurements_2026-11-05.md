# UAS GeoJSON loading and rendering: measurements and evaluation

**Measured:** 2026-11-05  
**Application:** FPVManager, Issue #47 chunking/cache optimization (96 Ki-character target chunks; bounded 128 Ki-character JSON frames).  
**Source:** FOCA/BAZL Switzerland UAS geographical zones, official GeoJSON EPSG:4326:  
`https://data.geo.admin.ch/ch.bazl.einschraenkungen-drohnen/einschraenkungen-drohnen/einschraenkungen-drohnen_4326.geojson`  
**Platforms:** Windows native / WebView2, Chrome (Flutter Web), Samsung Galaxy S22 (Android native WebView).  
**Method:** User-operated profile-mode runs and screenshots of the in-app local diagnostics. No performance data was uploaded by the app.

## Dataset and reporting notes

- Official HTTP body: **13,494,145 bytes** (approximately 13.49 MB decimal / 12.87 MiB).
- UAS features: **1,256** reported during the initial loads. This is the number returned by the dataset, **not proof of complete or currently valid airspace coverage**.
- Flutter-to-JavaScript transfer: **102 bridge frames**, including **100 data chunks**; reconstructed payload was about **9,798,715–9,798,718 UTF-16 characters**, depending on platform. HTTP bytes and Dart/JavaScript character lengths are different units.
- Times are wall-clock stage measurements from individual runs, not a controlled multi-run benchmark. Network paths, server cache, OS scheduling, CPU/GPU and thermal state were not held constant.
- **Bridge round trip includes renderer work.** Do not add it to Cesium load or JavaScript parsing durations. The first `postRender` callback is not a GPU completion benchmark.
- No geometry simplification or clipping of authoritative UAS zones was performed.

## 1. Cold HTTP 200 loads (real devices)

All timing columns are milliseconds (`ms`). `—` means not captured, not zero.

| Metric | Windows / WebView2 | Chrome / Web | Galaxy S22 / Android, run 1 |
| --- | ---: | ---: | ---: |
| HTTP status | 200 | 200 | 200 |
| HTTP body (bytes) | 13,494,145 | 13,494,145 | 13,494,145 |
| HTTP transfer | 3,553 | 1,840 | 28,188 |
| Dart JSON decode / parse | 1,502 | 220 | 592 |
| Geometry checks | 308 | 535 | 133 |
| Flutter JSON encoding | 1,102 | 328 | 364 |
| Bridge frames | 102 | 102 | 102 |
| Bridge frame send | 4,451 | 2,146 | 4,988 |
| Bridge round trip | 4,451 | 3,597 | 4,988 |
| Renderer JSON decode | 250.6 | 176.4 | 112.8 |
| Cesium `GeoJsonDataSource` load | 491.0 | 546.6 | 487.5 |
| Cesium attachment | 1.6 | 2.3 | 2.9 |
| Next `postRender` callback | 720.2 | 678.7 | 735.0 |

The S22 was used instead of the initially planned S25 Ultra. A second, deliberately uncached Android download returned **HTTP 200 in 25,959 ms**, with **5,129 ms** bridge round trip. The UI remained responsive during both Android downloads.

| Galaxy S22 second cold load | Value |
| --- | ---: |
| HTTP transfer | 25,959 ms |
| Bridge round trip | 5,129 ms |
| Average HTTP transfer across two runs | 27,073.5 ms |
| Average bridge round trip across two runs | 5,058.5 ms |

The repeated 26–28 second mobile download is noteworthy, but the test does **not** isolate network, server, Android networking, Wi-Fi conditions, or device thermal behavior as the cause.

## 2. Warm application restart with local UAS cache

No new HTTP transfer was shown in the visible diagnostics. The absence of an HTTP metric is not proof of a particular HTTP response status. The new Cesium renderer must receive the locally stored data again after a full application restart.

| Metric | Windows / WebView2 after restart | Galaxy S22 after restart |
| --- | ---: | ---: |
| Geometry checks | 199 ms | 73 ms |
| Flutter JSON encoding | 720 ms | 264 ms |
| Bridge frames | 102 | 102 |
| Bridge round trip | 3,444 ms | 3,689 ms |
| Renderer JSON decode | 225.1 ms | 95.5 ms |
| Cesium data source | 612.6 ms | 450.2 ms |
| Cesium attachment | 2.4 ms | 2.7 ms |
| Next `postRender` callback | 662.1 ms | 646.7 ms |

Functional verification: the 1,256 zone features remained available, with correct visibility, selection, and opacity behavior. Compared with the respective first load, bridge round trip was around **23% faster on Windows** and **26% faster on S22**, but these are single-run comparisons and cannot be attributed to an implementation change.

## 3. Warm hide and re-show within the same session

| Platform | Re-show delay | Zone selection and opacity | Diagnostics |
| --- | --- | --- | --- |
| Windows / WebView2 | Immediate (under 1 s) | Working | Unchanged |
| Chrome | Immediate (under 1 s) | Working | Unchanged |
| Galaxy S22 | Immediate (under 1 s) | Working | Unchanged |

This is **consistent with** retaining the attached Cesium data source instead of fully reimporting it. Unchanged diagnostics alone do not prove zero bridge traffic; the functional behavior and the existing automated reuse tests support the conclusion.

## 4. Browser caching and conditional request tests

Chrome DevTools showed a GeoJSON request served as **`200 OK (from disk cache)`**, with `Cache-Control: max-age=7200, public` (2 hours), `ETag`, and `Last-Modified: Thu, 05 Nov 2026 10:01:18 GMT`. The in-app refresh also yielded **200 from disk cache**; zones, selection and opacity continued functioning. Browser disk caching is **not equivalent** to an actual HTTP 304 request.

A **separate PowerShell `curl.exe` conditional HEAD request** against the official endpoint with `If-Modified-Since: Thu, 05 Nov 2026 10:01:18 GMT` returned **`HTTP/1.1 304 Not Modified`**. This confirms the server supports conditional revalidation. It does not by itself demonstrate that the app received a 304 in that session.

Existing automated test `test/features/globe/osint_provider_integration_test.dart` has a specific HTTP-304 scenario checking that an unchanged dataset updates its freshness, reuses the existing data and sends `set-uas-zones` without a GeoJSON reimport. The user reported the complete Flutter test suite passing.

## 5. Synthetic in-memory chunk comparison (not device A/B)

Command: `dart run tool/uas_loading_benchmark.dart` with **4,500 synthetic features**, no HTTP, WebView, Cesium or device GPU.

| Measurement | 32 Ki-character chunks | 96 Ki-character chunks | Change |
| --- | ---: | ---: | ---: |
| Frames | 37 | 14 | −62.2% |
| Mock transport | 105 ms | 62 ms | −41.0% |
| Mock round trip | 178 ms | 85 ms | −52.2% |
| Encoded content | 1,140,110 chars | 1,140,110 chars | Unchanged |
| On-wire framed bytes | 1,242,762 | 1,240,508 | −2,254 bytes |

These numbers justify further investigation of bulk transfer, but **must not be presented as a real-device speed-up**. The previously requested controlled 32/96-KiB device A/B comparison is intentionally **deferred at the user's request**.

## 6. Findings and next priorities

1. **Mobile HTTP:** The S22 twice needed approximately 26–28 s for the 13.49 MB official dataset. Investigate request/connection behavior, response compression support, server/network conditions, content reuse and user-visible progress. Preserve the verified source URL and offline-first operation; do not add an unsolicited proxy or telemetry.
2. **Flutter–Cesium bridge:** Around **3.4–5.1 s** for native WebView transfer/rebuild and **3.6 s** Chrome round trip on the first measured Web load. Evaluate transfer alternatives appropriate to each platform, with strict bounds, cancellation and source fidelity.
3. **Parsing, allocation and memory:** Windows initial Dart parse was 1.5 s and JSON encoding 1.1 s; multiple full JSON representations may increase peak RAM. Profile and reduce copies without losing MultiPolygon topology, holes or altitude metadata.
4. **Cesium and GPU:** 0.45–0.61 s for source creation plus about 0.65–0.74 s until the next postRender. Profile actual frame pacing, GPU resource usage and overlapping 3D layers rather than treating this callback as a GPU benchmark.
5. **Lifecycle, startup and local storage:** Preserve immediate hide/re-show and fast cached restart; avoid expensive duplicate imports and unbounded background requests across platform/WebView2 lifecycle transitions.
6. **Performance instrumentation:** Keep stage-level timings internally available and local, but remove the detailed benchmark block from the normal **Airspace → Map Layers** UI. The standalone CLI benchmark remains usable.

## 7. Closure statement and limitations

- **Confirmed:** automated tests passed; correct feature count in measured loads; visibility, opacity and zone interaction; responsive Android UI during download; warm hide/re-show on all three target platforms; cached app restart on Windows and S22; official server conditional revalidation via curl.
- **Not confirmed:** a real-device 32 vs 96 KiB before/after test, a manual **in-app** 304 event, GPU finish/long-term frame rate, peak process memory and the cause of slow S22 HTTP downloads.
- **Issue #47 status:** the optimization is functionally validated and the measurements are documented, while the real-device A/B acceptance item is **explicitly deferred**, not silently marked complete. Additional optimizations should be tracked in separate issues.
- **Safety/data:** the success of a 1,256-feature import and its cache freshness do not certify current Swiss UAS airspace rules or exhaustive coverage. Always verify current official restrictions before flight.
