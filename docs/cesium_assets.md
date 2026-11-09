# Bundled renderer assets

## CesiumJS

The optimized **CesiumJS 1.145.0** runtime is bundled in `web/cesium/`.
`globe.html` sets `CESIUM_BASE_URL` to `./cesium/`. JavaScript, CSS, Workers,
Wasm, Assets and Widgets come from the same pinned archive. Archive URL/SHA-512
are in `tool/cesium_vendor.json`; file sizes/SHA-256 are in
`web/cesium/manifest.json`. `pubspec.yaml` lists nested asset directories explicitly.

Verify the bundle offline:

```sh
python tool/vendor_cesium.py --check
```

For an upgrade, verify the release/integrity against the upstream registry,
update `tool/cesium_vendor.json`, move the old vendor folder outside the project,
then run `python tool/vendor_cesium.py`. The tool refuses to overwrite an existing
folder, validates the archive and regenerates asset entries. Review the diff,
manifest and notices; update version assertions in `cesium_assets_test.dart`.
Repeat checks, both builds and real-renderer tests from
[Contributing](../CONTRIBUTING.md). Preserve upstream licence/third-party files
and embedded notices; `.gitattributes` preserves vendor bytes.

## Serving

Offline raster preparation bundles GeoTIFF.js **2.1.3** in `web/vendor/geotiff/`
with its MIT licence. Its pinned SHA-256 is checked in
`test/js/offline_preparation.test.cjs`. Processing runs in a dedicated worker;
Android uses the same bundled page in a separate app-owned WebView.

Android's `GlobeAssetServer` binds only to `127.0.0.1` on an ephemeral port and
serves manifest-listed assets with Worker/Wasm MIME types. Host/port/method checks
prevent filesystem exposure. Cleartext is allowed only for that local origin;
external providers use HTTPS. Web serves the same files below the app base path.
Use `--no-web-resources-cdn` for local Flutter renderer resources in Web builds.
Bundling the renderer does not download map regions.

`globe.html?offline=1` uses a local grid/ellipsoid without imagery/terrain requests.
Normal terrain failures use a labelled flat fallback and explicit retry; see
[architecture](architecture.md).

## Browser harnesses

```sh
python tool/serve_globe_smoke.py
```

Open these paths at `http://127.0.0.1:8765`:

| Path | Purpose |
|---|---|
| `/smoke` | Offline WebGL, geometry worker, bridge, overlays and iframe reload |
| `/smoke?spots=10000` | Marker-limit and large-transfer scenarios |
| `/terrain-smoke` | Synthetic terrain with HTTP failure/delay and recovery cases |
| `/interaction-smoke` | Ground camera and waypoint interaction with synthetic terrain |
| `/flight-smoke` | Flight spawn/HUD, terrain contact, shared touch/gamepad input fixtures, reset and exit |
| `/tunnel-portal-smoke` | Actual aperture fragment shader: horizontal and 50° faces retained; 75° and 89° faces removed only inside the bounded portal |
| `/tunnel-model-portal-smoke` | Actual glTF CustomShader: two portal openings, including a graded opening; the flat road and walls outside the openings survive |
| `/tunnel-globe-portal-smoke` | Actual Globe heightmap without vertex normals: reproduces the disabled-material regression, opens a production tunnel shell from outside and preserves horizontal road and surrounding rock |
| `/tunnel-wall-opacity-smoke` | Actual tunnel materials in every graphics profile and an imported mesh: both wall sides stay opaque over changing bright backgrounds, with opaque draw commands and depth writes |
| `/tunnel-bridge-portal-smoke` | Real Globe cliff, horizontal bridge and descending bore: legacy grade stops flight; corrected physics crosses at exactly 0.5 m approach AGL, including a moving aperture refresh |
| `/tunnel-curve-portal-smoke` | Real Globe rock inside a bend: a straight mask leaves it visible; segment-following masks remove it while preserving side/roof rock and road, with one reused material |
| `/map-menus-smoke` | Production page at mobile size: compact active source credits, complete source dialog, required visible notices, keyboard close and grouped flight options; diagnostic grid, no remote maps |
| `/bridge-supports-smoke` | Actual Cesium bridge pillars: synthetic bridge tags, visible deck probes, detailed terrain foundations, unobstructed ground and layer cleanup; no live map services |
| `/bridge-native-source-smoke` | Original swisstopo Ganter bridge subset: native feature classification, picked deck heights and visible production pillars above synthetic ground; no live data service required |
| `/signal-smoke` | Radio sight lines, Fresnel envelope, unknown heights, ground view and terrain invalidation |
| `/situational-smoke` | Mobility vectors, independent OSINT sources, live official WMS and ground view |
| `/obstacle-smoke` | Actual Cesium obstacle geometry, selection, live official WMS and opacity controls |
| `/smoke?online=1&narrow=1` | Live swisstopo terrain/imagery and credits in a 320 px viewport |

Use `--port 0` for a free port, `--build` to serve `build/web`, and
`--terrain-fixture --fault metadata-fail-once` to inject a recoverable synthetic
terrain failure into an app preview. Fixtures under `test/web/` are excluded
from production assets. Synthetic terrain is not real elevation data; timings
and simulated connectivity do not establish device performance/network behavior.

References: [Cesium static assets](https://cesium.com/learn/cesiumjs-learn/cesiumjs-quickstart/),
[pinned npm package](https://registry.npmjs.org/cesium/1.145.0),
[map sources and notices](map_sources_and_attribution.md).
