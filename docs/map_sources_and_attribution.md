# Map sources and attribution

Weather providers, attribution and the sampled overlay's resolution limits are
documented in the [weather guide](weather.md).

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

Retain the full satellite notices in the reachable sources dialog whenever
Satellite is selected; the app does not classify individual tile footprints. Topographic and Relief use their own
credits. Relief is hillshade, not a separate height model. The local diagnostic
grid/ellipsoid is not swisstopo imagery or measured terrain.

## Use and distribution

Optional text labels query the official [Identify API](https://docs.geo.admin.ch/access-data/identify-features.html)
for `ch.swisstopo.swissnames3d` settlement names and
`ch.swisstopo.amtliches-strassenverzeichnis` (© swisstopo), independently of roads.
Requests are viewport-limited and capped; dense areas can be incomplete. Area/line
extents use a representative display anchor, not a surveyed label position.
The [street directory](https://www.swisstopo.admin.ch/de/amtliches-verzeichnis-der-strassen)
primarily covers named streets with building addresses, not every path or motorway.
Normalized names stay in a bounded session cache; no bulk download or persistent
offline-label package is provided. Cached-only/offline mode makes no remote
label fallback. Source attribution remains visible with the layer.

Optional 3D buildings and vegetation use the official GeoAdmin 3D Tiles services:
`https://3d.geo.admin.ch/ch.swisstopo.swissbuildings3d.3d/v1/tileset.json` and
`https://3d.geo.admin.ch/ch.swisstopo.vegetation.3d/v1/tileset.json` (© swisstopo).
Tiles keep their georeferenced source placement without assumed height offsets.
Vegetation is a source model, not a current survey of every tree. Streaming is
limited to the visible level of detail and renderer memory cache; no bulk/offline download.

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

The [official UAS STAC collection](https://data.geo.admin.ch/api/stac/v1/collections/ch.bazl.einschraenkungen-drohnen)
links `rel=license` to [Open use. Must provide the source](https://opendata.swiss/en/terms-of-use/#terms_by).
The adapter retains FOCA attribution and permits local caching under those terms;
this is not a Creative Commons declaration. The older CKAN entry has no licence.
Download time, `current` service paths and HTTP modification dates do not prove
official validity or geographic completeness. Check current provider terms
before distributing data or adding services.

## Credits and packaged notices

`web/map_providers.js` supplies imagery/terrain credits through Cesium's native
**Quellen** control. The [swisstopo attribution FAQ](https://www.swisstopo.admin.ch/en/faq-free-geodata)
expressly accepts a linked central sources list in a dynamic map. Complete
SWISSIMAGE/CNES/Spot/NPOC/Planet wording is retained in that dialog. Cache-help
text is kept in Offline settings rather than repeated in the copyright line.
Shared static credits retain all active layer owners until the last owner
releases them. Unknown providers' mandatory screen credits are not collapsed.
Linked **© OpenStreetMap** stays visible whenever OSM tunnel or support geometry
is displayed, following the [OSMF attribution guidelines](https://osmfoundation.org/wiki/Licence/Attribution_Guidelines).
Open-Meteo stays linked on screen; its CC-BY link and processing notice are in
the dialog. Keep the sources control and remaining notices readable in all
styles, including narrow layouts and fallback states. Published
map screenshots must retain the applicable credits or show them beside the image.
UAS attribution comes from the displayed dataset's source descriptor.

Preserve bundled `web/cesium/LICENSE.md`, `web/cesium/ThirdParty.json` and embedded
notices. CesiumJS uses Apache-2.0; its dependencies retain their own terms. The
current app uses direct provider URLs rather than ion assets. Only the optional
default renderer logo is removed via `CreditDisplay.cesiumCredit`; CesiumJS and
Apache-2.0 remain acknowledged in the sources dialog. Actual ion credits keep
Cesium's native handling; `usesIon:true` preserves the default logo at startup.
See [Cesium's usage guide](https://cesium.com/learn/ion/content-usage-and-attribution-guide/)
and [official clarification for direct provider use](https://community.cesium.com/t/i-am-not-sure-if-i-am-using-cesium-ion/38283).
Open-source package notices are available from Einstellungen → Datenquellen →
Open-Source-Lizenzen. See [renderer assets](cesium_assets.md) for bundle updates.

Source references: [layer configuration](https://api3.geo.admin.ch/rest/services/api/MapServer/layersConfig?lang=en),
[WMTS capabilities](https://wmts.geo.admin.ch/EPSG/3857/1.0.0/WMTSCapabilities.xml?lang=en),
[SWISSIMAGE product](https://www.swisstopo.admin.ch/en/orthoimage-swissimage-10),
[terrain service](https://docs.geo.admin.ch/visualize-data/terrain-service.html),
and [swisstopo attribution FAQ](https://www.swisstopo.admin.ch/en/faq-free-geodata).
