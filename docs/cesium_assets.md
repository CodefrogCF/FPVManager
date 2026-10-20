# Bundled CesiumJS assets

FPVManager bundles the optimized runtime distribution of **CesiumJS 1.145.0**.
`web/globe.html` sets `CESIUM_BASE_URL` to `./cesium/` before importing the local
script. JavaScript, CSS, Workers, ThirdParty (including Wasm), Assets and Widgets
come from the same pinned npm archive. Source maps and unused source/unminified
distributions are excluded.

The archive URL and SHA-512 integrity are recorded in `tool/cesium_vendor.json`.
`web/cesium/manifest.json` records individual file sizes and SHA-256 hashes.
Flutter's asset directory list is explicit in `pubspec.yaml`, since nested
directories are not automatically included by a parent entry.

## Verify and update

Verification is offline and runs in CI:

```sh
python tool/vendor_cesium.py --check
```

For an intentional upgrade, verify the chosen npm release and its integrity
against the upstream registry, update `tool/cesium_vendor.json`, move the existing
`web/cesium` folder aside, then run `python tool/vendor_cesium.py`. The tool refuses
to overwrite an existing vendor directory, validates the compressed archive and
writes only regular files within the designated folder. It also regenerates the
Flutter asset directory entries. Remove the old copy from the project before
verification, and review the resulting diff, license inventory and manifest.
`.gitattributes` preserves exact vendor bytes across Git checkout platforms.

Run `--check`, Dart/JavaScript tests, both builds and the real renderer integration
test after an upgrade. The source version and manifest checks in
`cesium_assets_test.dart` must be intentionally updated for a new version.

## Native origin and offline behavior

The Android WebView loads `globe.html` through `GlobeAssetServer`, an ephemeral
HTTP server bound only to `127.0.0.1`. It serves manifest-listed `web/` assets,
checks the request host/port, rejects unsupported methods and does not expose
filesystem paths. JavaScript and Wasm have explicit MIME types. Android cleartext
traffic is allowed only for `127.0.0.1`; external providers continue to use HTTPS.
This permits same-origin workers/fetches without widening WebView file access.

Flutter Web serves the same files beneath the application's base directory.
The documented/CI Web build uses `--no-web-resources-cdn` so Flutter renderer
resources are also local. This does not implement downloaded map regions or
offline data freshness (#40/#51).

The renderer can start without online terrain or imagery. If initial terrain
connection fails/times out, it displays an ellipsoid fallback and reports that
online map resources are unavailable. `globe.html?offline=1` is a diagnostic mode
using a local grid, with no imagery/terrain requests. Integration tests use this
mode and synthetic UAS polygons. Live provider failures and device performance
need additional checks.

For a visible browser check, run `python tool/serve_globe_smoke.py` and open
`http://127.0.0.1:8765/smoke`. The harness uses the actual WebGL renderer,
synthetic polygons and a real iframe reload. It also schedules a real task in the
bundled `createGeometry` worker and waits for its result. Results appear on the page.
Use `/smoke?spots=10000` to exercise a 10,000-marker snapshot, reject an oversized
snapshot and repeat after renderer reload. Reported command timings do not
measure frame rate or performance on Android devices. The harness transfers large
commands in indexed 32 KiB blocks using the same protocol as the Dart bridge.

## Upstream notices

`web/cesium/LICENSE.md` and `web/cesium/ThirdParty.json` are copied unchanged from
the pinned package. Runtime files retain upstream embedded notices, including
the notices in Workers and ThirdParty assets. CesiumJS uses Apache-2.0; its
third-party components have their own terms recorded by upstream. Keep those
files when distributing the bundle.

The current imagery/terrain terms and on-screen notices are recorded in
[map sources and attribution](map_sources_and_attribution.md) (#8), and current
data flows in the [privacy policy](privacy_and_permissions.md) (#5). The broader
source/dependency and release documentation inventory remains #44. FOCA UAS
attribution remains in the renderer/UI.

For live attribution verification, open `/smoke?online=1` on the same smoke
server. It deliberately loads swisstopo imagery and terrain, asserts complete
visible source notices for all three styles and repeats after a real renderer
reload. This optional check requires working provider access and is separate
from the deterministic offline smoke and CI tests.

References: [Cesium static asset configuration](https://cesium.com/learn/cesiumjs-learn/cesiumjs-quickstart/)
and [pinned npm package](https://registry.npmjs.org/cesium/1.145.0).
