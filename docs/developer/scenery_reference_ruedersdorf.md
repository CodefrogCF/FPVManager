# Rüdersdorf reference environment

Simulation-only reference based on a separately licensed photogrammetric scan with approximate repairs, indoor passages and independent physical geometry. See [asset attribution](../../web/assets/scenery/ATTRIBUTION.md). Do not infer surveyed building dimensions or real-world clearance.

The [fixture](../../tool/scenery/reference/ruedersdorf.json) pins the four model/collision assets, pose and validation routes. The main collision mesh has 975,919 triangles; terrain clipping is disabled by default. Only one detailed visual model is supplied, not a complete LOD set. Mixed materials use the `unknown` RF assumption.

## Source register and acquisition

Source review: 2026-11-26. Publication or delivery dates are not necessarily capture
dates. Retain the actual tile metadata, acquisition date, CRS, SHA-256 and
license with local inputs; mark missing values unknown.

| Source | Date / edition evidence | Use and limitation | Rights / status |
|---|---|---|---|
| [Andrea Spognetta RAWscan, Zenodo DOI 10.5281/zenodo.10288797](https://zenodo.org/records/10288797) and [original Sketchfab](https://sketchfab.com/3d-models/abandoned-chemical-plant-rudersdorf-rawscan-d2464ec36fb644f28e904e5517f1da64) | Record gives publication 2018-04-05; capture date unknown | Video photogrammetry (not a verified LiDAR acquisition); scan holes, noise, no survey certificate | Original metadata CC BY-NC 4.0; local derivative only for this workflow, commercial permission not established |
| [LGB LoD2](https://geobasis-bb.de/lgb/de/geodaten/3d-produkte/3d-gebaeudemodelle/) | Tile-specific edition and acquisition dates pending | External footprints, heights and roof shapes; not interiors or structural gaps | LGB Open Data, verify tile-specific terms; no new download in this validation |
| [LGB DGM](https://data.geobasis-bb.de/geobasis/daten/dgm/) and [product metadata](https://geobroker.geobasis-bb.de/gbss.php?MODE=GetProductInformation&PRODUCTID=a4133059-05f7-43ae-a701-d71489df42a1) | Published product coverage 2014–2021; exact local input acquisition not independently verified | Existing DGM1 underlay and reference height; DHHN2016, not ellipsoid heights | dl-de/by-2-0; existing local derivative only |
| [LGB airborne laser scans](https://data.geobasis-bb.de/geobasis/daten/als/laz/) | Index lists `als_33417-5815.zip` (108 MB, delivery listing 2022-12-23); actual acquisition pending | Anchor projects to E 417823.53 N 5815573.92 (ETRS89/UTM33); inspect tile and adjacent tiles for extent, classification and density; airborne points cannot establish indoor geometry | dl-de/by-2-0; candidate, not downloaded/processed |
| [LGB imagery and acquisition overview](https://geobroker.geobasis-bb.de/gbss.php?MODE=GetProductPreview&PRODUCTID=b4c381ab-7e34-4ede-8e4f-7df6a776e909) | DOP20rgbi product overview 2022–2024; local image date pending | Validate horizontal alignment and external footprint only | Verify selected product terms; no new image copied |
| [BKG GCG2016 PROJ grid](https://cdn.proj.org/de_bkg_gcg2016.tif) | GCG2016 reference model; local grid edition/checksum pending | Height conversion for the certified reference, no second runtime offset | Keep independent attribution |
| BKG beta regional LoD2/terrain | Live test service, unverified vertical datum | Local experimental RF with prepared grid; other regions unavailable | Test-only, no caching/export; existing guard remains active |
| User-supplied photographs and permitted panoramic visual references | User reports FPV photos from 2023; other exact acquisition dates not established | Visual comparison only; no new measurements in this validation | Keep permission records locally; no reference image embedded or redistributed |

See the [asset attribution](../../web/assets/scenery/ATTRIBUTION.md) and
[third-party notices](../../THIRD_PARTY_NOTICES.md). Public accessibility does
not by itself grant commercial, derivative or redistribution rights. The
Zenodo record calls the acquisition photogrammetry from video. Do not infer
LiDAR precision for the original scan.

## Reproduce and validate

Use a checkout containing the authorized reference assets. Missing originals or intermediate reconstructions cannot be reproduced by this validator. Run from the root:

```sh
node tool/scenery/reference/validate.cjs tool/scenery/reference/ruedersdorf.json --check
node --test test/js/scenery_reference_routes.test.cjs
```

After visual/physical/height readiness, read the effective ellipsoid model anchor from scenery status. Export with that height, for example the nominal fixture value for an unchanged matching pose:

```sh
node tool/scenery/reference/validate.cjs tool/scenery/reference/ruedersdorf.json --export 112.27976788595622 local-reference
```

The new directory contains `routes.geojson`, `spawn-candidates.json`, and `validation.json`. Import the routes normally. Nine routes cover approach, exterior, entrance, indoor passage, high-speed pass, silo/platform dives, RF shadow/recovery and streaming lifecycle. They are checked with a 0.25 m sphere against the main mesh only; terrain, dynamic flight and other geometry need separate review. Recalibrate after provider/pose changes. Playback is not physical flight and bypasses failsafe.

The [CPU report](../../tool/scenery/reference/ruedersdorf_validation.json) uses synthetic clear terrain and the actual collision mesh. A weak-link training profile demonstrates modeled loss/recovery; it is not measured reception. The BKG RF height guard remains active outside the locally prepared test area.

## Device acceptance and rights

Use [the device template](../../tool/scenery/reference/device_acceptance.json) and [performance procedure](performance.md). Check both physics modes, approach/exit, indoor openings, collisions, signal and Rescue, repeated unload/reload, restart, offline coverage and source credits. Compare independent LoD2/DGM/ALS controls before claiming accuracy; record acquisition dates, datum, rights and residuals. Airborne data cannot establish indoor geometry. Device and survey results remain separate from synthetic tests.

Do not redistribute additional full scan packages without appropriate rights; the current assets also exceed the 64 MiB package limit. The CC0 [conversion fixture](../../test/fixtures/scenery/conversion_open_wall.fpvscenery) demonstrates portable export/import without the scan. See [Conversion](scenery_conversion.md).
