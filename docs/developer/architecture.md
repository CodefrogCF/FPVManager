# Architecture and storage

Flutter owns navigation, local records, preferences, route editing and external data adapters. CesiumJS owns rendering, camera, picking and simulation. Web embeds a same-origin iframe; Android/iOS and Windows use a loopback asset server and platform WebViews. See [bridge protocol](globe_bridge.md) and [renderer assets](cesium_assets.md).

| Path | Responsibility |
|---|---|
| `lib/features/` | Feature UI, controllers, route/simulation analysis, import/export |
| `lib/core/` | Typed models, coordinates, persistence, OSINT/provider contracts |
| `web/core/`, `web/features/` | Bridge, map/terrain, physics, RF, scenery, navigation, overlays and offline resources |
| `test/`, `integration_test/` | Unit, widget, renderer and integration checks |
| `tool/` | [Grouped development tools](../../tool/README.md) |

## Database and repositories

Drift/SQLite schema 13 stores personal places/photos/tags, aircraft/battery/radio profiles, flight plans/waypoints, ground routes, checklists, telemetry, preferences and scenery definitions. Web uses bundled SQLite Wasm and a worker. Foreign keys are enabled; injected resources remain caller-owned. Historical schemas and migration fixtures are in `drift_schemas/` and `test/generated_migrations/`.

Repositories commit metadata, relationships and ordered route points atomically. Use returned route snapshots after waypoint replacement; do not retain old IDs. Spot lists page lightweight summaries and load photos separately. Preserve unrelated settings and advanced profile fields on partial updates. Raw points, spots and zone selections are mutually exclusive.

Typed heights are position-only, explicit absolute references or AGL. Missing/incompatible heights can render a marked preview but are excluded from analysis. Waypoint speed is outgoing airspeed in m/s. GeoJSON follows [RFC 7946](https://www.rfc-editor.org/rfc/rfc7946.html), GPX follows [GPX 1.1](https://www.topografix.com/GPX/1/1/); versioned extensions preserve reference, AGL and speed. Imports are bounded and transactional. For migration and format checks use [Contributing](../../CONTRIBUTING.md).

## Providers and terrain

`OsintProvider<T>` exposes source metadata, bounded fetch, status and disposal; cached providers share concurrent work and retain last good snapshots after failures. Retrieval, expiry and official validity are separate. Renderer acknowledgement identifies the committed dataset. Geometry, counts, CRS and references are validated before publication. Map provider factories reside in `web/features/map/map_providers.js`; `window.FPVMapProviderConfig` permits injected adapters.

Terrain generations invalidate old samples, picks and route calculations. Startup validates required root tiles, uses an explicit ellipsoid fallback if initialization fails and retries within finite budgets. Individual failures preserve loaded terrain and unknown heights; background samples and cancelled requests do not imply global render failure. Ground/flight modes must not invent valid clearance. See [simulation](simulation_and_collision.md), [height references](../user/coordinates_and_heights.md) and [map attribution](../user/map_sources_and_attribution.md).

Aviation obstacles use a separate `fpvmanager_osint_cache` database, validated KMZ/GeoJSON and bounded viewport/category batches. Stage updates transactionally; retain committed data on failure. Nearby regions use camera-local hysteresis; terrain anchors are provider-aware. Optional models use trusted AGL, not guessed top heights. WMS imagery remains independent. Validate KMZ with `dart run tool/quality/check_obstacle_kmz.dart`; regenerate models with `python tool/data/generate_obstacle_models.py`.

The airspace checker tests horizontal polygon/multipolygon intersections, including holes and boundaries, independently of display visibility. Split antimeridian crossings; altitude/time applicability and gaps remain explicit.

## Backups and offline maps

Backup v1: `FPVBK001`, flag (1 byte), salt (16), nonce (12). Protected exports use AES-256-GCM with header AAD, 16-byte tag and PBKDF2-HMAC-SHA256 (600,000 iterations); unprotected exports use SHA-256 for accidental corruption, not authentication. JSON stores typed rows and base64 BLOBs, with 64 MiB / 100,000-row limits. Validate schemas, relationships and images before transactional restore. Only permitted preferences are exported; credentials and provider caches are excluded. Scenery bytes require separate [packages](scenery_package.md).

Native public caches and Web Cache Storage retain allowed official tiles within prepared regions. Deduplicate requests, enforce resource caps, honor `no-store`/`private`, and reconstruct cached-only availability from actual tiles. Offline preparation discovers official raster/terrain sources through STAC and converts permitted inputs using explicit datum grids into PNG and quantized-mesh pyramids. Staged publication preserves previous data on failure; NoData remains missing. Prepared regions never fall back to network. Web offline startup requires a verified application snapshot created with `python tool/build/prepare_offline_web.py`; the service worker verifies the complete staged version and activates after old tabs close.

## Infrastructure and rendering

Synthetic tunnels derive from bounded OSM source axes and verified terrain/road approaches; connected ways share floor anchors. Portal apertures retain road/floor surfaces and only remove the intended steep terrain. Bridges use mapped supports or estimated spacing below verified deck profiles; explicit suspension spans suppress guessed piers. Neither is surveyed clearance. See [tunnel catalogue](offline_swiss_tunnel_index.md).

Keep renderer module order, worker URLs and owned resources consistent. Flight camera updates precede Cesium terrain selection; bounded shader preparation and adaptive streaming relieve stalls without changing collision precision. Short terrain sweeps reuse decoded triangle batches with provider/mesh invalidation and guarded public picking fallback. Generic scenery management is documented in [Scenery](scenery.md). Performance evidence belongs in [benchmarks](performance.md), not feature history.
