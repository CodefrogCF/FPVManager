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
| `/signal-smoke` | Radio sight lines, Fresnel envelope, unknown heights, ground view and terrain invalidation |
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
