# Real-world scenery

The generic scenery API handles bundled, managed and remote assets. The [user guide](../user/scenery.md) describes operation; the [package specification](scenery_package.md) defines portable storage. The [reference environment](scenery_reference_ruedersdorf.md) documents source rights and validation.

## Architecture

| Area | Implementation |
|---|---|
| Persistence, validation, import/export | `lib/features/scenery/`, Drift `sceneries` table (schema 13) |
| Renderer catalog, activation, height, collision and credits | `web/features/scenery/scenery_manager.js`, `web/assets/scenery/catalog.json` |
| Alignment and physical geometry | `scenery_alignment.js`, `scenery_collision.js` in the renderer scenery module |
| Replacement and clipping ownership | `scenery_replacement.js` |
| External provider | `scenery_tileset_provider.js`, `web/features/terrain/regional_3d.js` |

The database is authoritative. Initialize bundled definitions once, preserve intentional removals and local edits, and replay the catalog on renderer reconnect. Reject obsolete async results; unchanged assets retain their resources. Backups store definitions, not model bytes. Managed resources are content-addressed and released when no definition references them. See the [bridge contract](globe_bridge.md) and package specification for fields and validation.

## Local model import

Static GLB/glTF 2.0 with embedded or locally resolved buffers and PNG/JPEG textures is canonicalized to a self-contained GLB. Native loopback and Web cache-only loading avoid external fallback. Untrusted paths, external network references, executable content, animations, skins, morph targets, sparse accessors and unsupported compression are rejected. The import limit is 64 MiB, textures at most 4096 pixels per side, with separate decoded resource limits. Validate source rights and metadata before commit.

## External 3D Tiles providers

HTTPS OGC 3D Tiles 1.0/1.1 retain native root transforms and optional local ENU correction. Validate endpoint, bounding volume, content references and required extensions; constrain requests, cancellation and header parsing. Never forward query credentials across origins. Provider errors and incomplete coverage remain visible. Online-only sources stop requests in offline modes; no unauthorized caching or redistribution. External tiles are visual unless separate physical geometry is attached.

## Alignment and replacement

Visuals and colliders share geographic anchor (WGS84 ellipsoid or terrain-relative), ENU heading/pitch/roll and scale. Use the editor's numerical or graphical controls, terrain snap and three or more non-collinear geographic control points; residuals describe fit, not absolute survey accuracy. Cancellation restores prior state. Use local metre geometry to avoid large-coordinate precision loss.

Building regions are geographic polygons or provider-specific stable feature IDs. Hide only owned base geometry, invalidate cached base-building observations, and restore it when replacement is disabled/unloaded. For bundled scenes, small edits relative to the original pose (10 m horizontal, 50 m vertical, 3° per axis, 2% scale) retain the original building regions; larger edits require review. Terrain cuts require independently validated collision/height readiness, matching mesh checksum and provider-specific seam certification; position edits invalidate terrain approval. Do not remove surrounding or foreign clipping. Failed optional underlays cannot block the main model; invalid terrain cuts remain disabled.

## Custom collision meshes

Import FPC1 or validated static GLB/glTF converted to a triangle BVH. Physical geometry is independent of visual LOD, texture and opacity; preserve openings and sidedness. Reject invalid/degenerate triangles and enforce bounded resources. During flight missing required local geometry pauses affected movement without inventing signal loss. RF materials and propagation are described in [Radio and Rescue](radio_and_rescue.md).

## Height references and regional test service

Never mix orthometric heights (DHHN2016) and WGS84 ellipsoid heights. The official DGM/GCG2016 reference calibration applies once; active rendered terrain must independently confirm placement. Missing heights trigger retry, not a fabricated zero or arbitrary offset. The BKG 3D test provider has an unverified vertical reference for RF: preserve the explicit RF guard and use its data only under the applicable test terms.

Use `flutter build apk --release --dart-define=FPV_REGIONAL_3D_TEST=true` for an opt-in test build. The [local workbench](../../tool/scenery/cesium_georeference_workbench.html) and [server](../../tool/scenery/serve_workbench.py) allow authorized reference alignment; a flat-preview height is not the active terrain anchor.

## Streaming and performance

Activation uses camera/aircraft distance, hysteresis, bounded movement and route lookahead; prioritize reachable collision geometry over visual admission. Cesium selects 3D Tiles LOD; managed GLB presets select only supplied alternatives. Balanced is default; set `FPV_SCENERY_PRESET=low`, `balanced` or `high` at build time. Cache and memory budgets are admission estimates, not total GPU/process limits. Pending/obsolete loads release resources, credits and object URLs. Replacement reconciliation uses dependency revisions, skipping unchanged frames while still checking mask ownership and readiness.

Run the [performance workflow](performance.md), [reference validation](scenery_reference_ruedersdorf.md) and [pre-push checks](../../CONTRIBUTING.md). External conversion is documented in [Conversion](scenery_conversion.md).
