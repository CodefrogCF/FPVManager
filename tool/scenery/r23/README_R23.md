# Rüdersdorf R23 — South-east production atrium, minor annex details and documentation CI

**Source:** R22 `local_reference.glb`, SHA-256
`1905fa96ba2b3a089d5da2775e53fbaf4e0e100a5cae28e528c36d23e01f99f0`.

This patch is cumulative in its **complete replacement GLB/FPC**; its source code is an
incremental R22→R23 reconstruction. The visual model and collision mesh are kept in
sync. **This is an approximate artistic reconstruction, not a surveyed site model
or a certified obstacle dataset.** Do not use it to determine safe real-world FPV
clearance.

## Reference matching and changes

The regional alignment remains **local −X approximately north; +Y approximately
east** (scale `16.023268178233355`, rotation `99.7993823133657°`). Camera
locations within most panoramas have **not** been georegistered. Existing scan
rooflines and structural footprints therefore determine placement; photographic
references supply plausible structure and type.

| Area | Reference basis | Geometric reconstruction |
| --- | --- | --- |
| Multi-level production block / south-east hall | `15875_Suedosthalle_innen.jpg`, `15878_Suedgebaeude_Lochraum.jpg` | Replace two originally closed R6 upper side-deck boxes with segmented slabs and **two real open service penetrations**; add shallow roof soffit grid, six narrow perimeter supports with capitals, wall brackets and two stair-edge handrail runs. Preserve open central atrium. |
| Small north-edge utility building | `15871_Hof_Nordost.jpg`, `15880_Suedgebaeude_Aussicht_Nord.jpg` | Ten thin supports, open window frames and partial ceiling grid inside a scan-derived footprint/roof height; do not add opaque invented walls or roof. |
| Damaged south-west annex | `15883_Suedwesthalle.jpg` and existing damaged-foreground references | Eight light cross-braces and fragmentary window lintels. Preserve roof and doorway openings. |

**Existing geometry left intact:** 15 RAWscan meshes, geographic transform,
R20 east-side platform near the main hall's north end and its open center, the
central four-silo roof dive, the closed six-silo south-eastern headhouse roof,
and R21 east building access hatch.

### Actual upper-floor openings

R23 removes exactly **24** triangles from the preceding *procedural* upper
side decks and reconstructs them as pieces surrounding the holes, rather than
overlaying decorative holes on a collision-solid floor.

- Western floor cutout local X/Y: `(-4.185..-4.035, 2.060..2.225)`
- Eastern floor cutout local X/Y: `(-2.875..-2.725, 2.405..2.585)`
- Source floor level is approximately `Z=-1.184..-1.160` in **local** units.

All approximate local dimensions must be multiplied by the scene's 16.0233
scale to obtain modeled world metres. The geometry is not independently
measured. The room assignment is plausible, not photographically registered.

## Mesh statistics

| Property | R22 | R23 |
| --- | ---: | ---: |
| Visual triangles | 961,184 | 962,972 |
| Unique FPC triangles | 961,182 | 962,970 |
| Change in visible triangles | — | +1,788 (+0.19%) |
| Unique collider vertices | — | 489,982 |

- Procedurally added geometry before removing old slabs: 1,248 concrete and
  564 metal triangles.
- **GLB SHA-256:** `85a53f623fa5ea5e30f6df2feeef44fce8fd75f5a9c2d93c797a7ca44541b30e`
- **FPC SHA-256:** `fac191d3aa9c383cc46f5c42b72bb7c17effbfbdaedf1a7c1a18eaa2c1587ec1`
- All 16 FPC collision certificates in the scenery catalog are synchronized to
  the latter digest. The independent DGM terrain underlay is unchanged.

## Documentation CI correction

`python tool/check_docs.py` previously failed on two relative Markdown links
and ticket-like references in the scenery feasibility report. R23 also ships:

- `docs/user/map_sources_and_attribution.md`: link to
  `../../tool/build_forest_composition.py` and to
  `../developer/cesium_assets.md`.
- `docs/research/v0.20.0_issue_144_scenery_feasibility.md`: remove ticket
  references **in document content** while preserving the status and next steps.

The filenames are not themselves scanned by `check_docs.py`.

## Rebuild and verification

From the FPVManager repository root with NumPy and SciPy installed, obtain the
R22 GLB at the exact source hash above, then run:

```bash
python tool/scenery/refine_ruedersdorf_r23.py /path/to/R22/local_reference.glb web/assets/scenery/local_reference.glb web/assets/scenery/local_reference.fpc tool/scenery/r23/refinement_R23_report.json
python tool/scenery/test_ruedersdorf_r23.py /path/to/R22/local_reference.glb web/assets/scenery/local_reference.glb web/assets/scenery/local_reference.fpc web/assets/scenery/catalog.json tool/scenery/r23/refinement_R23_report.json
node --test test/js/*.test.cjs
python tool/check_docs.py
```

The reconstruction script regenerates the GLB and FPC; keep the packaged
`catalog.json` in sync with the resulting FPC SHA-256 (the supplied files already
match). Tests verify the two hatches are freely traversable with a 16 cm sphere,
while their adjacent decking remains solid. They also guard the prior dive
openings, existing georeference, predecessor mesh accessors, and visual/FPC
triangle equality.

## Known limitations

The new details are **not** registered against exact panoramic camera poses.
A Cesium browser visual inspection, drone-scale passage testing and mobile FPS
benchmark have not been performed here. Avoid claiming photo-realistic accuracy
or reliable real-world clearance. The RAWscan-derived asset remains subject to
original attribution and CC BY-NC conditions; review rights before distributing
GLB and FPC in a public/commercial package.
