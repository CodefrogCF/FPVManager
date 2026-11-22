# R27 — Courtyard forebuilding: actual geometry replacement

## Scope and source evidence

This revision continues R25–R26's **building-by-building replacement** of the
Rüdersdorf plant scan. It addresses the *courtyard forebuilding with the collapsed
outside staircase*, visible in the user's named photographic references:

- `beschädigtes_vorgebäude_große_halle_standort_innenhof_blickrichtun_süd_west.jpg`
- `südliches_gebäude_und_beschädigtes_vorgebäude_große_halle_standort_innenhof_blickrichtun_süd_west.jpg`
- `beschädigtes_vorgebäude_innen_blickrichtun_nord_ost_auf_nord_östliches_gebäude.jpg`
- `innenhof_blickrichtung_süd.png`

The model footprint is mapped approximately to the former **R6 west production
block**, in front of the neighbouring scanned pair of cylindrical silos. This
is a **hypothesis derived from relative placement**, not a surveyed photo-to-GLB
registration. The stair slope, dimensions and damage pattern approximate what
the photos show; the source images do not supply exact 3-D coordinates.

## Changes to geometry, collision and texture

- **Bounded actual cut** rather than overlay: original scan triangles inside
  `COURTYARD_MASK=(-4.340,-2.570,1.650,3.570,-2.010,-.660)` and the adjacent
  collapsed stair mask are removed; boundary-crossing triangles are clipped
  and their normals and UVs interpolated. Scanned ground below the masked height
  remains; silos and nearby R13 silo access stair remain intact.
- Cut the obsolete R6/R17/R19/R20/R21/R23/R24 generated production-building
  surfaces that previously formed a full-height envelope and false floor/decks.
  This is the dominant change at this location, because the original scan there
  contains relatively little standing building geometry.
- Create a **lower forebuilding** (approx. 24.5 × 23.7 m footprint, 10.5 m from
  modelled ground to roof), with asymmetric bricked-up wing, real front and rear
  door openings, open windows, concrete posts and an accessible undercroft.
- Add a surviving concrete roof slab, separate lower garage-style canopy,
  partial parapets, supports, and a **sloping damaged external stair/slab** built
  from individual inclined panels with missing segments, exposed steel and
  floor-level rubble. No invisible wall caps the spaces below the staircase.
- Embed **four new generated textures** (stained concrete, pale worn brick,
  moss-stained roof and oxidized steel) directly in the R27 GLB, rather than
  displaying the old blurred scanned image on the rebuilt surfaces. These
  textures are procedural and are not copies of reference photographs.
- Rebuild `local_reference.fpc` using the **same exact visual geometry**;
  recalculate all 16 collision certificate hashes in `catalog.json`.

### Actual replacement counts

See `refinement_R27_report.json` for complete counts. **131** raw scan triangles
and **4,206** old procedural triangles were fully removed from the two cut
regions; partly intersecting triangles were also clipped. The surrounding raw
scan and its textures are not globally deleted.

## Rebuild

Apply R27 *over the complete R26 project*. The included `.glb` and `.fpc` are
already built and the script is only necessary if rebuilding the geometry.
The exact R26 GLB SHA256 is checked before any changes are written.

```sh
python tool/scenery/refine_ruedersdorf_r27.py \
  path/to/R26/local_reference.glb \
  /tmp/ruedersdorf_r27.glb /tmp/ruedersdorf_r27.fpc /tmp/r27_report.json
python tool/scenery/test_ruedersdorf_r27.py \
  web/assets/scenery/local_reference.glb \
  web/assets/scenery/local_reference.fpc \
  tool/scenery/r27/refinement_R27_report.json
python tool/check_docs.py
node --test test/js/*.test.cjs
```

## Verified and not verified

- Tested: independent GLB/FPC triangle equality, **25** geometry ray cases,
  accessible door/window openings, solid masonry/roof, segmented ramp gaps,
  preserved R25/R26 entries and silo/landing passages. **914** JavaScript
  regression tests and **49** documentation-link checks passed locally.
- Historical R23 production-deck tests were updated because the R23 decks were
  deliberately removed in this replacement. The new tests explicitly check
  the replacement's accessible undercroft and roof, rather than expecting the
  superseded R23 hatches.
- **Not verified:** precise match to the photography from inside a running
  Cesium scene, exact dimensions of ramp and building, Android/Windows FPS and
  performance on devices. Model is an unsurveyed architectural approximation,
  not an authoritative engineering or flight-safety map.

All remaining photogrammetric content and its original attribution remain
subject to the original **CC BY-NC 4.0** terms.
