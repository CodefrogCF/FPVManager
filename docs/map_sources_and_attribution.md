# Map sources and attribution

## Sources

Imagery uses EPSG:3857 raster WMTS tiles:

```text
https://wmts.geo.admin.ch/1.0.0/{layer}/default/current/3857/{z}/{x}/{y}.{extension}
```

| Purpose | Layer / endpoint | Notice |
|---|---|---|
| Satellite | `ch.swisstopo.swissimage`, JPEG | © swisstopo · © CNES, Spot Image, NPOC; Planet notice below |
| Topographic | `ch.swisstopo.pixelkarte-farbe`, JPEG | © swisstopo |
| Relief | `ch.swisstopo.swissalti3d-reliefschattierung`, PNG | © swisstopo |
| Terrain and height sampling | `https://3d.geo.admin.ch/ch.swisstopo.terrain.3d/v1/` | © swisstopo |
| Swiss UAS zones | [FOCA GeoJSON](https://data.geo.admin.ch/ch.bazl.einschraenkungen-drohnen/einschraenkungen-drohnen/einschraenkungen-drohnen_4326.geojson) | FOCA/BAZL source attribution and provenance supplied by the adapter |
| Published aviation obstacle imagery | `wms.geo.admin.ch`, `ch.bazl.luftfahrthindernis` | BAZL / FOCA · geo.admin.ch; WMS 1.3.0, EPSG:3857, transparent PNG, default style; [official legend](https://api3.geo.admin.ch/static/images/legends/ch.bazl.luftfahrthindernis_de.png) |
| Selectable aviation obstacles | [Official STAC collection](https://data.geo.admin.ch/api/stac/v1/collections/ch.bazl.luftfahrthindernis) | BAZL / FOCA · Skyguide; full WGS84 KMZ; published coverage only |
| Optional height conversion | `geodesy.geo.admin.ch` REFRAME | [Service documentation](https://www.swisstopo.admin.ch/en/rest-api-geoservices-reframe-web) |

Satellite is the SWISSIMAGE Background composite, including aerial imagery and
SPOT imagery in neighbouring countries. Its product documentation also requires:

> Includes material © (2016-2018) Planet. All rights reserved

Retain the full satellite notices whenever Satellite is selected; the app does
not classify individual tile footprints. Topographic and Relief use their own
credits. Relief is hillshade, not a separate height model. The local diagnostic
grid/ellipsoid is not swisstopo imagery or measured terrain.

## Use and distribution

The [Swiss obstacle data specification](https://www.bazl.admin.ch/dam/en/sd-web/CpfHnV604RSJ/dps_obstacle_datenset_aixm.pdf)
defines absolute KML elevations as LN02 despite the usual KML convention. The
bundled CHGeo2004/HTRANS grid converts those values to ETRS89 ellipsoid heights,
used as a WGS84 visualization approximation. The grid originates from swisstopo
via [PROJ-data](https://cdn.proj.org/ch_swisstopo_README.txt), under CC0;
provenance and rebuild instructions are in `assets/geo/chgeo2004_ln02.NOTICE.txt`
and `tool/build_swiss_height_grid.py`. Obstacle records retain their source
usage restriction; this grid licence does not apply to the obstacle dataset.

[swisstopo OGD terms](https://www.swisstopo.admin.ch/en/terms-of-use-free-geodata-and-geoservices)
apply to covered swisstopo products and require source attribution. They are
swisstopo's own terms, not a Creative Commons licence. Keep product-specific
third-party notices. Source-code licensing does not replace data rights.

The [FSDI operating terms](https://www.geo.admin.ch/de/allgemeine-nutzungsbedingungen-bgdi/)
also apply. Observe fair use; use official download services for bulk data rather
than high-rate tile scraping. Offline downloads or additional products require
review of their own download, redistribution and attribution conditions.

Do not infer a FOCA licence from swisstopo's terms or public accessibility. The
adapter records the licence as unknown and links to the
[official catalogue](https://opendata.swiss/en/dataset/geografische-uas-gebiete-der-schweiz).
Download time, `current` service paths and HTTP modification dates do not prove
official validity or geographic completeness. Check current provider terms
before distributing data or adding services.

## Credits and packaged notices

`web/map_providers.js` supplies on-screen imagery/terrain credits. Keep them
readable in all styles, including narrow layouts and fallback states. Published
map screenshots must retain the applicable credits or show them beside the image.
UAS attribution comes from the displayed dataset's source descriptor.

Preserve bundled `web/cesium/LICENSE.md`, `web/cesium/ThirdParty.json`, embedded
notices and the upstream logo. CesiumJS uses Apache-2.0; its dependencies retain
their own terms. See [renderer assets](cesium_assets.md) for update instructions.

Source references: [layer configuration](https://api3.geo.admin.ch/rest/services/api/MapServer/layersConfig?lang=en),
[WMTS capabilities](https://wmts.geo.admin.ch/EPSG/3857/1.0.0/WMTSCapabilities.xml?lang=en),
[SWISSIMAGE product](https://www.swisstopo.admin.ch/en/orthoimage-swissimage-10),
[terrain service](https://docs.geo.admin.ch/visualize-data/terrain-service.html),
and [swisstopo attribution FAQ](https://www.swisstopo.admin.ch/en/faq-free-geodata).
