# R25 — Replace scanned building shells instead of overlaying the scan

## Goal

This revision starts the actual, *bounded replacement* of original RAWscan
photogrammetry and obsolete procedural reconstructions. It does **not** claim
that the entire factory site is rebuilt. All other original scan components,
terrain and their textures remain in place for subsequent stages.

## Replaced in this revision

### 1. Small north-west utility structure (true source-scan replacement)

- Removed original textured scan triangles **inside** a bounded 3D building
  volume, cutting boundary triangles rather than leaving fragments crossing
  the boundary. This makes the original exterior and collision surfaces absent
  where the new building stands.
- Preserved original photogrammetry outside the selected volume, including
  the existing original material and interpolated UV mapping on cut edges.
- Removed previously generated synthetic support details in this region.
- Rebuilt the complete envelope with actual door/window voids, floors, a
  damaged roof service hatch, inner partition with a door, two partial upper
  service areas and a short stair.
- Original scan deletion region (local model coordinates):
  `[-4.59,-3.67,5.70,6.21,-2.06,-1.09]`.

### 2. Eastern production building (obsolete procedural shell replacement)

- Source analysis showed this area contains primarily ground-level original
  scan geometry; inaccurate building walls were mainly authored in R12 and
  subsequent procedural R17–R24 reconstructions.
- Removed the overlapping older **synthetic** building mesh surfaces within
  `x=4.29..5.48, y=0.99..2.76, z=-2.012..-0.745`.
- Rebuilt the exterior as walls segmented around doors and windows, open
  internal galleries, partial floor slabs, room partitions with walk-through
  doorways, stairs and two roof lightwells. No internal silos/tanks were added.
- Preserved the scanned terrain underneath.

## Integrity

- Original georeference, scale, axis mapping, metadata and attribution remain.
- 15 source scan mesh groups remain registered, but scan triangles inside the
  chosen replacement region are *actually removed*.
- GLB and FPC are rebuilt from the same geometry. The catalog's 16 terrain
  collision certificate hashes were updated.
- Source: verified R24 `local_reference.glb` with SHA256
  `cc68e2732b9a9efb7e31ae36534251e0c5d914556a0997e97713ce073f94141d`.
- The missing R11 ground collider was restored from the existing terrain GLB;
  its SHA256 matches the existing catalog certificate without changes.

## Build / verification

Starting from the R24 project, run:

```bash
python tool/scenery/refine_ruedersdorf_r25.py \
  web/assets/scenery/local_reference.glb \
  /tmp/ruedersdorf_r25.glb \
  /tmp/ruedersdorf_r25.fpc \
  /tmp/ruedersdorf_r25_report.json
python tool/scenery/test_ruedersdorf_r25.py \
  /tmp/ruedersdorf_r25.glb \
  /tmp/ruedersdorf_r25.fpc \
  /tmp/ruedersdorf_r25_report.json
```

`python tool/check_docs.py` and `node --test test/js/*.test.cjs` also passed
on the updated project. Ten targeted geometry rays (doorways, windows, hatch,
solid walls, roof) passed; JavaScript collision sweeps cover several of them
with a radius.

## Limitations and further work

1. Dimensions and partitions remain **unsurveyed approximations**, based on the
   source scan outlines and supplied panoramas/photos. R25 is not a site survey.
2. R25 is a pilot for converting **additional specific buildings one by one**.
   It must not be extrapolated to remove all original scan geometry in one
   global spatial deletion, since this would also remove preserved structures,
   terrain, trees, silos and necessary connecting elements.
3. Texture fidelity is still limited: new authored materials reuse earlier
   procedural concrete, brick, roof and metal surfaces. The old blurred scan
   texture is no longer used *inside the fully replaced northern building*;
   neighbouring unreplaced scan surfaces still retain original textures.
4. A Cesium in-app visual inspection is still necessary to confirm facade
   proportions and any unmodelled adjoining circulation.
5. R15's historical 'open southeast six-silo roof' test was outdated: the roof
   was intentionally closed in R16 and stays closed. That test is revised to
   verify the current roof behavior rather than resurrecting the obsolete
   opening. Exact triangle-count regression was replaced with a geometry-budget
   bound plus the full collision SHA256 certificate.

**License:** Original RAWscan attribution is retained in metadata/catalog;
original scan and any derivatives remain subject to the stated CC BY-NC 4.0
conditions. Do not present this model as surveyed or flight-safe.
