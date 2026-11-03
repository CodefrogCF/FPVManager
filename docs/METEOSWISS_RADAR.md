# Official MeteoSwiss precipitation radar (integration status)

## Data contract

- Official STAC collection: `https://data.geo.admin.ch/api/stac/v1/collections/ch.meteoschweiz.ogd-radar-precip`
- `RZC`: PRECIP radar estimate, instantaneous rain rate **mm/h**, 5-minute resolution.
- `CPC`: CombiPrecip, radar + rain gauge accumulation over 60 minutes, **mm**, generally 5-minute publication. CPC hourly reanalysis may change after ~8 days; the STAC `updated` field and source filename matter.
- **Not supported**: `TZC` side views, nowcasting, synthetic forecasts or unlisted radar products.
- The catalogue contains date items and HDF5 assets. An empty item or missing interval indicates **unknown/not published**, not zero precipitation.
- ODIM-HDF5 is supplied in **LV95 / EPSG:2056**, not WGS84 imagery. This integration rejects a raster with missing scaling, missing-values information, unexpected grid size or unverified projection.
- Attribution for any shown data: **Source: MeteoSwiss**. The STAC collection presently declares CC-BY.

## Architectural choice: processing on the map client

The implementation adds a distinct `MeteoRadarSection` to the weather view, and separate `FPVMeteoRadar` Cesium imagery state. Forecast overlays and the selected forecast timestamp are not changed by radar observations.

Android's native WebView and Flutter Web's iframe run the same JS/Canvas/Cesium decoder path. The ODIM HDF5 reader uses `h5wasm@0.10.3` (WebAssembly HDF5). No conversion proxy or server is required. **Current limitation:** this package is loaded from the pinned jsDelivr URL at runtime, *not bundled in this ZIP*. The app therefore requires network access to that CDN and to STAC asset hosts. Any CDN/CORS/WebView failure is reported rather than replaced with a simulated frame. For a distributable production app, vendor and license-review the library and its modules/assets and point the import to local resources. The package is an external runtime dependency, not an additional data-processing service.

The browser fetches the original HDF5 file on user selection only. It decodes ODIM `/dataset1/data1/data`, with metadata from `/where` and `/dataset1/data1/what` or `/dataset1/what`; a fixture is used to test this shape. The parser **rejects** unrecognized data layouts, projection, calibration or missing-value rules rather than interpreting binary values directly. The downloaded raster is reprojected into a bounded geographic RGBA image before being placed in Cesium; the approximated Swiss LV95 formulas are intended for visual planning and are not a surveying-grade georeferencing path. A real official HDF5 sample still needs verification to establish the exact supported ODIM schema and north-up pixel orientation.

## Resource and error behaviour

| Resource | Limit |
| --- | --- |
| STAC discovery | Manual only, at most 3 date items per request, cache 2 minutes / minimum 30 seconds between forced rechecks |
| Visible timeline | At most 12 actual published timestamps per product; no interpolated missing frames |
| HDF5 download | At most 3 MiB, streaming size checked, AbortController per replacement |
| Source grid | At most 1,500,000 pixels |
| Reprojected frame | 256×256 RGBA pixels |
| In-memory raster cache | At most 2 frames, keyed by source URL, publication update and product timestamp |
| Rendering | Exactly one MeteoSwiss imagery layer; old layer removed with destroy flag |

`nodata`, pixels outside the coverage extent and missing samples are grey and identified as unknown; an explicitly undetectable intensity is a valid zero and remains transparent. This distinguishes **no observed rain** from **no observation**. The chart shows product, units and UTC observation timestamp. The raw HDF5 bytes are released after decoding; files are unlinked from the virtual filesystem and closed. The source URL, original product timestamp and STAC update value are kept as metadata for retained session frames.

Replacing the frame aborts its download and ignores stale async work. A synchronous HDF5 decoder call cannot be interrupted mid-operation; the result is discarded if cancelled. Clearing the layer or leaving Weather releases imagery and the in-memory cache on disposal. No long-lived offline archive or automatic nationwide downloads are created.

Official reference: https://opendatadocs.meteoswiss.ch/d-radar-data/d1-precipitation-radar-products
