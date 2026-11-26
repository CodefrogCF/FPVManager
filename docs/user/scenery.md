# Real-world scenery and model imports

## Display and manage

Open **Map & view → Map → Real-world scenery**. Enable a scene to load it automatically near the camera or aircraft; use **Refresh status** or **Reload** if necessary. **Manage scenery** creates, imports, edits, exports or removes definitions. Stop navigation before editing. New imports start disabled; check placement and collision before enabling them.

- Local GLB/glTF: select a static model and required local buffers/textures, enter longitude/latitude, height reference, rotation and scale, and record author, licence and attribution. Use uncompressed models with PNG/JPEG textures; animations and compressed extensions are unsupported. The file limit is 64 MiB including resources.
- External 3D Tiles: enter an authorized HTTPS endpoint, review source metadata/credits and configure loading distance and detail. It requires network availability and applicable provider permission; no automatic offline copy or physical collision mesh is created.
- Portable `.fpvscenery`: import a local file or confirm an HTTPS download, review licence, revision and preview, then enable. Export a complete licensed package only when redistribution is permitted; otherwise use a reference-only export. Backups preserve definitions, not model bytes: retain separate packages for restoration. Removing a scene releases unshared local assets.

## Placement and physical geometry

Use the alignment editor to translate/rotate/scale the scene, switch views, pick terrain, or fit control points. Absolute heights are WGS84 ellipsoid metres, not AMSL; terrain-relative placement requires a valid terrain sample. Cancel restores the previous state. Attach an independent collision mesh for physical contact and optional RF material estimates. The visible model alone does not prove physical coverage. Select building replacement to remove overlapping default buildings; terrain cuts require separately validated geometry and may be disabled after alignment changes.

## Rüdersdorf

The experimental chemical plant scene is based on Andrea Spognetta's RAWscan (CC BY-NC 4.0), with approximate reconstructed structures and separate collision geometry. It is not surveyed. The optional BKG 3D test service is available in separately enabled builds; its height reference is not validated for RF. Source credits are in [Map sources](map_sources_and_attribution.md) and [asset attribution](../../web/assets/scenery/ATTRIBUTION.md).

## Troubleshooting

If a scene fails to appear, check its enable state, distance, terrain readiness and the displayed error. Enable **Settings → Developer options** for detailed alignment, collision and RF diagnostics, or use **Performance overlay** for frame and resource metrics. Restore a bundled original definition only after confirming that local alignment changes may be lost. Missing required colliders can pause affected movement; do not treat an uncertain RF display as confirmed loss or clearance. See [Flight simulation](flight_simulation.md) and [Coordinates and heights](coordinates_and_heights.md).
