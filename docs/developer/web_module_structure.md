# Web renderer module layout

The web renderer intentionally uses **classic JavaScript scripts**, not ES modules.
It runs both in a Flutter Web build and in a native Flutter WebView through
`GlobeAssetServer`. Each script registers a `globalThis.FPV…` API, and
**`web/globe.html` script ordering must remain unchanged**.

## Organization

| Directory | Responsibility |
| --- | --- |
| `web/core/` | Bridge, positions, renderer localization, capture mode and performance |
| `web/features/map/` | Map providers, labels, compass, UAS styles, dated imagery |
| `web/features/terrain/` | Terrain source management and regional 3D providers |
| `web/features/navigation/` | Route editor, controller input, walking and road navigation |
| `web/features/flight/` | Free flight, rendering, recording and autonomous control |
| `web/features/flight/physics/` | Motors, batteries, aerodynamics, collision, dynamics and rescue velocity |
| `web/features/flight/hud/` | Flight HUD, signal bars and HUD CSS |
| `web/features/signal/` | RF estimation, live signal analysis and simulated failsafe |
| `web/features/scenery/` | Scenery catalog, placement, collision, calibration and local preview |
| `web/features/scene/` | Cesium 3D scene and tile scheduling |
| `web/features/infrastructure/` | Bridges, tunnels, obstacle models and layers |
| `web/features/vegetation/` | Vegetation models, composition and shaders |
| `web/features/weather/` | Forecasts, wind fields and radar overlays |
| `web/features/overlays/` | Additional situational layers |
| `web/features/offline/` | Offline preparation UI, encoding and storage helpers |

## Files deliberately kept at the top of `web/`

- `globe.js`: runtime orchestration entrypoint; loaded last by `globe.html`.
- `drift_worker.js`: generated Drift web worker, with its expected public path.
- `flutter_bootstrap.js`, `offline_bootstrap.js`: Flutter application startup.
- `offline_service_worker.js`: must be registered at the web scope root.
- `offline_preparation_worker.js`: worker entrypoint invoked by the preparation page.
- `offline_maps.js`: imported by the root service worker.
- `offline_map_client.js`: app-facing offline map startup integration.
- `index.html`, `globe.html`, `offline_preparation.html`, `manifest.json`,
  `sqlite3.wasm`, `favicon.png`: browser/bootstrap entrypoints and static assets.

Third-party `web/cesium/` and `web/vendor/`, published `web/assets/`, models,
icons, and terrain/index data have not been moved.

## Rules when moving or adding a module

1. Edit the exact script URL in `web/globe.html` **without reordering scripts**.
2. Declare each native WebView script or stylesheet in `pubspec.yaml` under
   its **full `web/...` path** (a Flutter Web build and a native asset bundle
   consume these differently).
3. Adjust local Node `require('./...')` paths relative to the module's **new
   source directory**. Browser scripts still use globals and document-relative
   asset URLs; don't rebase static `assets/...` paths against the script file.
4. Update `importScripts(...)` paths in root workers, offline preparation HTML,
   browser smoke pages and any local benchmark/tooling references.
5. Keep the service worker entrypoint at `web/offline_service_worker.js` to
   preserve its registration scope. Moving it changes browser behavior.
6. Do not change the meaning of a data URL, terrain URL, source credit,
   collision mesh, scenery alignment, cached offline region or RF calculation.

## Verification

```sh
node --test test/js/*.test.cjs
python -m unittest discover -s test/tool -p 'test_*.py'
flutter analyze --no-pub
flutter test --no-pub
```

`test/js/web_module_layout.test.cjs` verifies the original script order,
manifest references, CommonJS imports, smoke pages and worker imports.
For browser integration, also run the existing smoke suites against a local
HTTP server and validate Android/Windows/Web rendering. A passing Node suite
is not a replacement for testing native Flutter and in-browser asset loading.

## Applying the file move from a ZIP

An overlay ZIP cannot remove files that existed at old locations. Copy its
project contents to the repository root and run
`tool/cleanup_web_module_move.ps1` (PowerShell) **after** the copy. The
script checks that every new file exists and confirms the old file hashes
before removing obsolete top-level copies. It stops if an old file has
unrecognized local changes, so such changes are not discarded silently.
On Git, `git status` should show moved modules as deletions plus additions
(Git can detect renames automatically); commit these together.
