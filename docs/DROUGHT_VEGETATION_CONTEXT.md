# Issue #95 · Drought and vegetation-condition context

## Verified official sources (checked 2026-11-03)

| Toggle | Layer | Interface | Data semantics | Time semantics |
|---|---|---|---|---|
| **Amtliche Trockenheitswarnkarte** | `ch.bafu.trockenheitswarnkarte` | GeoAdmin WMTS, current layer | Published drought-warning classifications | **No authoritative source timestamp is inferred** from tile URL or fetch time |
| **Kombinierter Trockenheitsindex (CDI)** | `ch.bafu.trockenheitsindex` | GeoAdmin WMS | Modelled, classified combined drought index | Official WMS `time` values: 0 previous week; 1 current week; 2 next week; 3 +2 weeks; 4 +3 weeks. Future states explicitly labelled *forecast* |
| **swissEO VHI (forest)** | `ch.swisstopo.swisseo_vhi_v100` | GeoAdmin WMS + STAC metadata | Forest-masked satellite vegetation index, **not** direct soil moisture measurement | STAC item `datetime` / interval / publication date, kept separate from fetch time; optical/thermal observations aggregated across up to seven days |
| **swissEO VHI (all vegetation)** | `ch.swisstopo.swisseo_vhi_v100_vegetation` | GeoAdmin WMS + same swissEO STAC collection | Vegetation-masked index, including managed farmland, which may reflect land-use change | Same STAC product timestamps; no independent new observation assumed |

Verified endpoints:

- Data access and license: https://www.trockenheit.admin.ch/de/weitere-informationen/daten-beziehen
- GeoAdmin supported layers: https://api3.geo.admin.ch/rest/services/api/MapServer/layersTable
- BAFU warning WMTS: `https://wmts.geo.admin.ch/1.0.0/ch.bafu.trockenheitswarnkarte/default/current/3857/{z}/{x}/{y}.png`
- CDI WMS: `https://wms.geo.admin.ch/`, `LAYERS=ch.bafu.trockenheitsindex`, `time=0..4`
- VHI WMS: `https://wms.geo.admin.ch/`, `LAYERS=ch.swisstopo.swisseo_vhi_v100`
- VHI STAC: `https://data.geo.admin.ch/api/stac/v1/collections/ch.swisstopo.swisseo_vhi_v100`
- VHI item-page sample: `.../items?limit=12&sortby=-datetime` (latest among the returned sample, not an exhaustive history)
- VHI details/terms: https://www.swisstopo.admin.ch/en/satelliteimage-swisseo-vhi

**Time notice (critical):** GeoAdmin release notes dated 2026-10-28 announce that the v100 VHI/S2-SR products will be retired by the end of 2026 and replaced by `ch.swisstopo.swisseo_vhi_v200` and corresponding v200 collections. The older v100 WMS remains the currently documented operational viewer layer. Confirm v200 WMS capabilities before switching IDs. Revisit this dependency before the 2026-12 shutdown:
https://docs.geo.admin.ch/page/end-of-life.html

## Rendering, safety, and bounds

- All four layers are **optional and independent** of the existing wildfire danger and cantonal prevention-measures overlays.
- Public, officially styled raster tiles are rendered directly by Cesium. The app does **not** download a nationwide raster, decode full GeoTIFFs, resample values into artificial classes, or turn no-data into index 0.
- WMTS is limited to z0..11; CDI WMS to z0..11 and VHI WMS to z0..12. GeoAdmin imagery is fetched only for the visible map tiles; the existing WMS handler bounds tile requests to 12 seconds with cancellation, retry limits and teardown. Only one timestamped CDI WMS provider exists at a time, and changes replace/dispose the previous provider.
- Cesium imagery success means a tile loaded, **not** that the published data are fresh or complete. Missing, blank, failed and out-of-coverage tiles do not imply no drought.
- CDI source uses relative **weekly indices**, not verified date-specific forecasts. No unsupported absolute start/end timestamps are inferred.
- VHI is a model/satellite comparison to 1991–2020 climatology. Land-cover masks, clouds and shadows can create gaps. The forest layer should not be interpreted as exact exposure or soil conditions at an FPV spot.
- Never infer fire bans, water-use restrictions or access permissions from warning classes or numerical indices. Check competent cantonal/municipal authorities and the existing prevention-measures layer instead.

## Metadata, caching and terms

- VHI STAC metadata are **fetched only on request**; no personal position is transmitted by this request. Response size limits: 100 KiB collection and 600 KiB item sample, max 12 items. A network check is limited to at most 8 checks/hour with a minimum 30-second gap; duplicates are coalesced.
- Store only a small (<12 KiB) provenance record in the existing separate OSINT SQLite cache; retain at most 30 days. A user profile/backup does **not** include this public cache. Full raster tiles are **not** persisted by FPVManager; ordinary browser image cache remains governed by the servers' HTTP response headers.
- `fetchedUtc` is an HTTP observation by FPVManager, **not** a source publication time. `observedUtc`, period and source publication fields are populated only from official STAC item properties. An undated item is **unknown**. A last successful cached observation is shown after failed refresh, with explicit failure status. VHI older than 10 days or local metadata older than 12 hours is stale under the app's conservative display policy (not a product-specified legal validity period).
- The metadata query selects **up to** 12 items (not a guarantee that all older items or latest snapshots are included); the user is told when a page may be incomplete.
- Attribution in application: BAFU · National Drought Platform, and swissEO: **© swisstopo, Contains modified Copernicus Sentinel data [Year]** (the product year must come from verified product metadata, not the current device date). See the official VHI page for the exact year, license and downstream attribution requirements.
- The federal drought-platform data are released for use with correct source attribution. swissEO data likewise require the swisstopo / modified Copernicus Sentinel notice; further terms: https://www.swisstopo.admin.ch/en/satelliteimage-swisseo-vhi