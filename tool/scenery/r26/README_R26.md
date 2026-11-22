# R26 — Replace scanned southwest ruin annex instead of overlaying it

## Scope

Following R25's first true scan-shell replacement, R26 converts the **southwest
ruin annex** from source scan + R17/R19/R21/R23 overlapping details into a single
independently authored, accessible building shell. It uses the footprint and
roof height already adopted in those revisions, together with the user-provided
industrial ruins references, as **approximate constraints**.

The previous damaged-forebuilding photos depict architectural features that may
belong to another part of the courtyard; they are **not metrically matched** to
this annex. Accordingly, architectural details are indicative rather than a
claimed survey of this individual structure. Do not extrapolate their positions.

## Actual mesh substitution

Local scan cut: `x=2.365..4.305; y=-5.075..-4.455; z=-1.968..-1.220`

- **5,721** original textured scan triangles fully removed from this building
  volume; another **767** triangles touching its boundary were split and kept
  outside the cut with interpolated original position/normal/UV coordinates.
- **576** obsolete author-generated triangles from R17/R19/R21/R23 fully
  removed from the same area, plus any partially intersecting triangles cut.
- Scan-derived ground **beneath** the cut and neighboring scan objects are
  retained. The 15 original scan groups still exist but no longer contain the
  replacement-region triangles.
- New doors, windows and room voids are actual geometry holes, not image
  effects. The same final triangles form the render GLB and the `.fpc` collision
  model, including damaged roof gaps and partial upper floors.

## New approximate building

- Approximate footprint **26.1 × 6.0 m** (derived from previous local bounds).
- Exposed columns and beam capitals, open masonry door and window bays.
- Four incomplete elevated floor fragments, two separated roof openings,
  three surviving roof-panel groups, broken stairs and short rails.
- Small reproducibly generated debris fragments, no solid invisible walls or
  full-size fake roof replacing the existing damage.
- No geometry is declared survey-accurate, and no non-commercial original scan
  attribution has been stripped.

## Validation

From R25 source and the included scripts:

```sh
python tool/scenery/refine_ruedersdorf_r26.py \
  web/assets/scenery/local_reference.glb \
  /tmp/ruedersdorf_r26.glb \
  /tmp/ruedersdorf_r26.fpc \
  /tmp/ruedersdorf_r26_report.json
python tool/scenery/test_ruedersdorf_r26.py \
  /tmp/ruedersdorf_r26.glb \
  /tmp/ruedersdorf_r26.fpc \
  /tmp/ruedersdorf_r26_report.json
python tool/check_docs.py
node --test test/js/*.test.cjs
```

The script verifies the exact R25 input SHA-256 before doing the cut. Do not run
it against an R26 asset or an arbitrary older version. The included GLB/FPC are
already built and need no rebuild to install.

## Known limitations

- Only the designated southwest annex is replaced in R26; the rest of the site
  still contains photogrammetry and previous procedural additions.
- Exact room proportions, stair positions, wall damage and color variation
  remain unsurveyed photo-guided approximations.
- Visual agreement inside running Cesium, mobile rendering performance, and
  alternate approaches through nearby structures require actual in-app review.
- The restored R11 terrain collision file from R25 remains unchanged.

The model continues to carry original RAWscan metadata and the declared
**CC BY-NC 4.0** conditions. It is a visual/FPV simulation, not a verified
flight-safety or structural map.
