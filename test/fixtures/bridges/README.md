# Native Ganter bridge regression fixture

Source: © swisstopo, swissTLM3D 3D Tiles revision **20260520**, retrieved
2026-11-08. The source colours are pink for the road centre and grey for the
road border. This bridge is absent from the nearby BAZL aviation bridge records.

- [Official source tile](https://3d.geo.admin.ch/ch.swisstopo.swisstlm3d.3d/v1/20260520/6/31/9.b3dm)
- [Official road axis](https://api3.geo.admin.ch/rest/services/api/MapServer/ch.swisstopo.swisstlm3d-strassen/46980536?geometryFormat=geojson&sr=4326)
- [3D Tiles service documentation](https://docs.geo.admin.ch/visualize-data/3d-tiles.html)
- [swissTLM3D object catalogue, page 21](https://www.swisstopo.admin.ch/dam/de/sd-web/A3kQ2dAgenqG/2025-03)

`ganter_native_deck.b3dm` retains the original Draco-compressed pink road deck
and grey border meshes, materials, node transformations, RTC centre, and feature
metadata. Unrelated meshes were removed and the binary container repacked. The
retained geometry and material values were not changed. The grey mesh also
contains surrounding short bridge features from the same original tile; native
feature identifiers distinguish them.

`ganter_native_deck.json` records the original 49-point, **2D, unclassified**
GeoAdmin road centreline, provenance, the known bridge UUID, and reference
attributes. `tileset.json` loads the local subset with a tight bounding sphere
computed from the retained main deck vertices; its geometry transforms are
unchanged. The original much larger regional bounds are unsuitable for the
single-tile regression camera.
These three model/axis files occupy less than 30 KB. No external data service is
needed by the browser regression.

`ganter_terrain_reference.json` records 23 live ground samples from the app's
actual swisstopo Cesium terrain endpoint, captured on 2026-11-08, with the same
station positions and native deck heights used by the browser check. The
measured ground-to-deck gaps are 8.10–147.67 m, within the existing 150 m support
height limit. This optional reference is evidence of that comparison; the
offline regression does not download terrain or assume it remains unchanged.
The model, axis, and terrain reference files together occupy less than 40 KB.

The browser check uses the real bundled Cesium decoder, native feature metadata,
model transformations and downward ray picking. Its flat 1350 m ground is a
synthetic test surface. Support spacing is illustrative; the fixture does not
claim surveyed pier positions.
