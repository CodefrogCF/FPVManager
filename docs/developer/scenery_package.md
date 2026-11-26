# FPVManager scenery package format 1 (.fpvscenery)

Status: experimental format. This specification is
published with the repository; no external service is required to use it.

## Scope and container

A package is a single ZIP32 archive, named `<id>.fpvscenery`. Version 1 uses
**STORE (method 0) only**. ZIP encryption, ZIP64, split archives, directory
entries, symlinks, extra fields, comments, data descriptors, prefixes, gaps and
trailing bytes are unsupported. Local headers must agree with central headers;
CRC32 must match. Only ASCII file names below are accepted. Nothing is extracted
using an archive-provided filesystem path. Stored entries avoid decompression
bombs in the archive itself. The GLB/FPC importers enforce decoded resource limits.

| Limit | Value |
| --- | --- |
| Entire ZIP, including headers | 64 MiB |
| Entries | 34 (manifest, up to 32 unique assets, optional preview) |
| manifest.json | 256 KiB; nested scenery manifest at most 128 KiB |
| Visual assets (including LOD alternatives) | 16 |
| Collision assets | 16 |
| Single managed asset | 64 MiB |
| PNG preview | 32 KiB, at most 512 × 512, one frame |
| Local managed storage | 512 MiB across all sceneries |

Allowed paths: `manifest.json`, `preview.png` (optional),
`assets/<sha256>.glb`, `assets/<sha256>.fpc`, where SHA-256 is 64 lowercase hex
characters. No unlisted files, duplicate names, or extra executable resources.
Textures, buffers and other glTF auxiliary resources must already be embedded
in a canonical self-contained GLB 2.0 created using the local model importer.
The format does not support arbitrary glTF sidecar paths, scripts, offline 3D
Tiles directory trees or downloading provider assets for redistribution.

## Manifest schema

The root `manifest.json` is UTF-8 JSON. Required keys:

| Field | Type / constraint |
| --- | --- |
| `format` | literal `fpvmanager-scenery` |
| `version` | integer `1` (container/manifest version) |
| `revision` | integer 1–2147483647 (publisher-controlled revision of this scenery ID) |
| `metadataOnly` | boolean |
| `redistributionAllowed` | boolean, must be true for a complete package |
| `scenery` | existing `SceneryManifest` schema version 1, detailed below |
| `files` | object mapping every non-manifest entry to `{ "bytes": integer, "sha256": string }` |

`manifest.json` is protected by ZIP CRC32. Each resource has both CRC32 and
SHA-256, and its managed filename must match its SHA-256. These are integrity
checks, not signatures, proof of identity or a license verification service.

The `scenery` object is the application-independent definition used by the
scenery catalog (see [scenery.md](scenery.md) and `scenery_manifest.dart`). Its
fields include `schemaVersion`, `id`, `name`, `description`, `source` (author,
license, attribution and optional HTTPS URL), `anchor` (longitude, latitude,
heightM, reference), `bounds`, `rotation` (headingDeg, pitchDeg, rollDeg),
`scale`, `assets`, `collision`, `visibility`, `minimumAppVersion`, and optional
`replacement` and `extensions`. Bounds derived from managed geometry are
recomputed, not trusted. Geographic polygons use `[longitude, latitude]` and
existing replacement validation. Absolute height is WGS84 ellipsoid height,
not mean sea level. Terrain-relative placement requires the relevant terrain
provider or its available offline data. The package contains scenery geometry,
not the entire base map or terrain provider cache.

A complete package requires all assets to use `provider: "managed"`. Each
visual asset has `role: "visual"`, `format: "glb"`; each collider has
`role: "collision"`, `format: "fpc"`. `uri` is the bare content key, e.g.
`<sha256>.glb`. The `model` metadata object contains `localBounds` (six ENU
coordinates), `vertices`, `triangles`, `textures`, `estimatedBytes`, and
`byteLength`. The importer recomputes and compares these fields using the
existing model and collision validators. Duplicate content keys are stored once.
Collision asset IDs and sidedness remain independent of visual quality.

### Visual LODs

`scenery.extensions.lods` optionally maps base visual asset IDs to preset-specific
alternative IDs. All referenced entries must be managed visual assets declared in
`scenery.assets`. Alternative IDs must not be LOD bases. Example:

```json
{
  "lods": {
    "visual-main": {
      "low": "visual-low",
      "high": "visual-high"
    }
  }
}
```

The base is used if a preset has no alternative. All alternatives use the same
local coordinate frame, orientation and scale. An author must verify alignment;
resource validation cannot establish that meshes represent the same real object.
The renderer loads only the chosen model for each base. The collision geometry
is not changed. Per-preset texture quality is encoded in the alternative GLBs.

Portable extensions are restricted to the managed LOD map and numeric alignment
opacity. Arbitrary runtime Cesium extensions, provider-specific underlays and
terrain calibration certificates are not imported/exported; they may reference
unlicensed resources and require independent calibration. The explicit
`replacement` configuration is preserved. The importer attaches locally stored
`extensions.package` metadata (revision, redistribution permission,
metadata-only status, and optional bounded base64 PNG preview). It is not
necessary to include this local metadata in the archive.

### Metadata-only packages

Set `metadataOnly: true`, `redistributionAllowed: false`, and `files: {}` to
exchange the definition without any asset or preview bytes. Existing managed,
bundled and remote-tiles references are retained as references, not fetched or
activated. Source and provider URLs with query strings are rejected rather than
risk exporting access tokens. Reacquire the files from the authorized provider;
import a complete licensed package to activate the scenery. The exporter does
not download or copy remote provider or bundled resources. Rights must be
explicitly confirmed for every complete export; a claimed boolean does not
supersede actual third-party terms. Metadata-only exchange also requires the
right to share the metadata itself.

## Installation, updating and removal

In **Manage scenery**, select local package import or enter an HTTPS URL.
Remote download requires confirmation before the request; the download is
bounded and rejects redirects/non-200 responses. Web additionally requires CORS.
A second confirmation shows source, license, revision and optional preview after
validation. No definitions or asset bytes are committed before validation and
confirmation. Import is disabled during navigation. Every installed package is
initially disabled; review alignment and collision geometry before activating it.

A reserved bundled ID cannot be overwritten. An existing non-package ID can
only be repaired if its managed asset descriptors and source match exactly;
the existing definition and local alignment are retained. A package ID collision
requires explicit confirmation. Higher revisions replace
package definitions; lower revisions are rejected. At the same revision,
identical asset descriptors permit repair of missing bytes while retaining local
alignment. A metadata-only package cannot downgrade a complete installation.
A matching metadata-only definition can be upgraded to complete at the same
revision; changed asset descriptors require a higher revision. Newly created
files are rolled back if the database commit fails. Committed files remain
available if the renderer bridge fails. The last actual reference to a managed
file is removed during normal removal/update; shared resources are retained.
Filesystem/cache deletion failures remain subject to existing storage recovery
limitations. Physical deletion is not a secure erase guarantee.

The export dialog asks for the revision and an explicit redistribution
confirmation; metadata-only exports read no asset bytes. For local source
models, set author/license/attribution in the existing model editor first.
Package LOD authoring and optional preview creation can currently be performed
by constructing a conforming archive; the UI imports and re-exports them but
has no LOD/preview editor. Exporting an installed package preserves its preview.

## Backup / restore

Personal-data `.fpvbackup` files continue to contain scenery definition rows,
including content keys, package revision, rights, attribution and metadata-only
status. They do **not** contain model files or provider caches. Keep separate
licensed `.fpvscenery` archives for the offline bytes. After restoring a backup
on another device, import the matching package to repair missing bytes. A
same-revision repair with matching asset descriptors retains the restored local
placement; the scenery is disabled until reviewed again. No network recovery
runs automatically. This does not change the backup format or require a database
migration. Reference-only packages remain unavailable after restore.

## Verification

Run the [pre-push checks](../../CONTRIBUTING.md) and `flutter test test/features/scenery/scenery_package_test.dart`. Verify offline cross-device import, saved placement, licence display, removal and Web CORS/storage on target devices.

## Optional RF material assumptions

Collision assets may carry an optional `rf` object directly in their scenery
manifest asset entry. Existing packages and manifests without this property
remain valid and use the `unknown` preset. No new archive entry or format
version is required. The property is preserved through manifest, package and
backup workflows; it does not change collision mesh bytes or visual LOD.

```json
{
  "material": "reinforcedConcrete",
  "thicknessM": 0.3,
  "surfaceLossDb": 24,
  "lossDbPerM": 35
}
```

Only `material` is required if `rf` is present. Allowed values: `unknown`,
`concrete`, `reinforcedConcrete`, `brick`, `metal`, `glass`, `wood`. Thickness
must be finite and between 0.01 and 20 metres; optional loss overrides must be
finite and in the inclusive 0–100 dB or dB/m range respectively. Unknown fields,
invalid values and RF declarations on visual assets are rejected. A material
classification applies to one complete collision mesh. These settings are
simulation assumptions, not measured RF data. See [RF analysis](radio_and_rescue.md).
