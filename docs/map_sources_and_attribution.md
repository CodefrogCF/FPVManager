# Map sources and attribution

Checked **2026-10-20** for the renderer endpoints currently used by FPVManager
(issue #8). This records the source evidence and the implemented notices; it is
not an inventory of every application dependency or a completed #44 release audit.

## Exact services in use

The renderer requests EPSG:3857 raster tiles through this WMTS template:

```text
https://wmts.geo.admin.ch/1.0.0/{layer}/default/current/3857/{z}/{x}/{y}.{extension}
```

| App style / purpose | Exact layer / endpoint | Source notice |
|---|---|---|
| Satellite | `ch.swisstopo.swissimage`, JPEG | © swisstopo · © CNES, Spot Image, NPOC; additionally the Planet notice below |
| Topographic | `ch.swisstopo.pixelkarte-farbe`, JPEG | © swisstopo |
| Relief | `ch.swisstopo.swissalti3d-reliefschattierung`, PNG | © swisstopo |
| 3D terrain and terrain sampling | `https://3d.geo.admin.ch/ch.swisstopo.terrain.3d/v1/` | © swisstopo, explicitly supplied by the application |
| Offline diagnostic grid / ellipsoid fallback | Locally generated Cesium geometry | No claim that this is swisstopo imagery or detailed terrain |

The **Satellite** label selects SWISSIMAGE **Background**, a composite layer,
rather than an independent world satellite product or the vector Imagery Base
Map. Its official WMTS description identifies Swiss aerial imagery and SPOT 5
imagery in neighbouring countries. Its API attribution includes CNES, Spot Image,
swisstopo and NPOC. The topographic and relief API entries identify swisstopo.
The relief is a hillshade derived from swissALTI3D, not a separate height model.

SWISSIMAGE's product documentation additionally identifies RapidEye/Planet
material in the centres of the 20 largest Swiss lakes and specifies this notice:

> Includes material © (2016-2018) Planet. All rights reserved

FPVManager retains that notice whenever Satellite is selected, since it does not
classify individual tiles by source footprint. Credits follow the active imagery
provider, so switching to Topographic or Relief removes the satellite notices.

Evidence inspected:

- [Live layer configuration and attribution fields](https://api3.geo.admin.ch/rest/services/api/MapServer/layersConfig?lang=en).
- [EPSG:3857 WMTS capabilities, exact layer descriptions](https://wmts.geo.admin.ch/EPSG/3857/1.0.0/WMTSCapabilities.xml?lang=en).
- [SWISSIMAGE product details, including the Planet notice](https://www.swisstopo.admin.ch/en/orthoimage-swissimage-10).
- [Terrain service and metadata contract](https://docs.geo.admin.ch/visualize-data/terrain-service.html).
- [Live terrain metadata](https://3d.geo.admin.ch/ch.swisstopo.terrain.3d/v1/layer.json):
  `version: "1.43646.0"`, `attribution: ""`, `description: ""` on the check date.
  The empty attribution field does not waive the source requirement.

The legacy `chargeable` flags in the layer configuration are not a licence or a
fee determination. The published terms below govern use. The service's `current`
path and a successful retrieval do not prove a particular acquisition date or
official validity. Terrain metadata's global bounds also do not establish
uniform resolution or the component datasets in every country. Dataset-level
provenance/freshness follows the [provider contracts](osint_providers.md) (#4).
Tile services retain unknown dataset-wide validity and have no fabricated
whole-dataset retrieval time.

## Usage conditions for this integration

[swisstopo OGD terms](https://www.swisstopo.admin.ch/en/terms-of-use-free-geodata-and-geoservices)
(version 1 March 2021) permit use, modification, redistribution and commercial
use of the covered free swisstopo data/services, with a mandatory source notice.
They are swisstopo's own statutory terms, **not a Creative Commons licence**.
Keep the product-specific third-party notices above; the app's source-code
licence does not replace data rights or grant rights to separate raw products.
Special source requirements for swissALTIRegio and swissEO must be reviewed if
those products are independently added; neither is configured as an imagery
layer in this renderer.

The [swisstopo FAQ](https://www.swisstopo.admin.ch/en/faq-free-geodata) describes
source attribution beside a dynamic map as the preferred presentation. The app
therefore requests **on-screen** Cesium credits rather than relying only on its
Data attribution popover. Published map screenshots must retain the credits or
place the applicable source notice beside the image.

The [FSDI general terms and operating rules](https://www.geo.admin.ch/de/allgemeine-nutzungsbedingungen-bgdi/)
(version 1 January 2025 at the check date) also apply. Use each dataset according
to its own conditions, observe fair use, and do not scrape tile services at high
request rates. Bulk/offline datasets should come through the official download
services. Excessive use can be restricted, and service availability is subject to
the published operating conditions. FPVManager currently loads the viewed map
through Cesium's request scheduling; it has no bulk tile-download or downloaded
region feature. Future offline regions (#40/#51) need a separate review of
download, redistribution, updates and attribution.

FPVManager uses its **own Cesium iframe**, not an embedded map.geo.admin.ch map
viewer. The FSDI rules specific to changing an embedded official map viewer are
therefore not the mechanism used here. No vector Base Map, OpenMapTiles, Cesium
ion/world imagery or alternative external basemap is configured.

## Display and packaged notices

`web/map_providers.js` supplies the imagery factory used by `web/globe.js` for
startup and subsequent style changes, plus the terrain factory.
Each online provider has a complete `Cesium.Credit(..., true)`. The terrain
provider receives its own explicit on-screen source credit, including when an
imagery provider is replaced. Cesium can consolidate identical credits.
The offline grid has no external map credit. If online terrain initialization
fails, imagery still retains its own attribution on the ellipsoid fallback.

`web/globe.html` gives the credit area a readable background and allows wrapping
on narrow viewports. The native selected-coordinate footer is outside the
WebView, so it cannot cover credits at the bottom of the map.

CesiumJS **1.145.0** and its runtime dependencies are bundled locally. Preserve
`web/cesium/LICENSE.md`, `web/cesium/ThirdParty.json` and embedded notices in every
distributed runtime. Cesium's upstream notices and logo are retained. See
[bundled Cesium assets](cesium_assets.md) for integrity and packaging checks.
No vendored file is modified for this attribution change.

## Verification and remaining scope

- `node --test test/js/globe_bridge.test.cjs test/js/map_attribution.test.cjs`
  checks startup/style attribution, explicit terrain attribution without a
  metadata credit, flat fallback and offline diagnostics without external data.
- Run `python tool/serve_globe_smoke.py` and open `/smoke` for the local offline
  renderer check. Open `/smoke?online=1` for a deliberate **live provider** check:
  it requires loaded terrain and asserts the visible credits for all styles,
  including after an actual iframe reload. Add `&narrow=1` to check wrapping
  inside a 320-pixel map viewport. This is not a CI test or a
  guarantee that the upstream service is always available.
- Web and APK asset checks must confirm that the current renderer and original
  upstream licence/notices are present in both distributions.
- Check an Android device in portrait/landscape with a selected point, verify
  all three styles and the visible credits. Build checks cannot establish
  physical-device readability or WebView behaviour.

Recorded checks on 2026-10-20: locked dependency resolution, format check (73
hand-written Dart files), analysis, 173 Flutter tests, 11 JavaScript tests,
4 Python tests and the original Cesium asset/hash check passed. The actual
Cesium/WebGL smoke passed offline and against the live providers. The live
check also passed in a 320-pixel map viewport, including a minimum computed
credit font size of 12 pixels, no horizontal overflow, all three styles and
the same checks after a real iframe reload. This is browser evidence, not an
Android physical-device test.

The Web release build with `--no-web-resources-cdn` passed. Its Cesium runtime
files matched the vendor manifest hashes, its current renderer/bridge files
matched the sources, and local CanvasKit was present. The built Flutter app
was also opened in the browser: Satellite displayed the full notices, and
changing to Topographic and Relief through Map Layers displayed the swisstopo
credit without the satellite-specific notices.

The Android debug build (`flutter build apk --debug --no-pub`) also passed.
The APK passed ZIP integrity and bundled Cesium hash checks; its current
`globe.html`, `globe.js` and `globe_bridge.js` matched the source files. The
SQLite libraries for ARMv7, ARM64 and x86_64 were present with the expected
ELF machine types. Android installation, gestures, selected-point footer
readability and orientation changes on a physical device remain unverified.

This addresses #8's current imagery/terrain attribution scope. #44 still covers
the complete external-source/dependency inventory (including FOCA UAS and
REFRAME conditions), user guidance, legal notices, calculation limitations and
release notes. See the separate [privacy and permission policy](privacy_and_permissions.md)
for network triggers and disclosed data. Runtime terrain failures and recovery
remain #7; richer source/licence/validity contracts remain #4. Recheck this
inventory when endpoints, products, styles, vendor versions or distribution
features change.
