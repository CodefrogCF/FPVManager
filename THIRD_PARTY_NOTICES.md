# Third-party software and data

FPVManager's original code, project configuration and documentation are licensed
under [Apache-2.0](LICENSE). This does not relicense third-party software,
downloaded or bundled datasets, or user-created/imported content. Their own
copyright notices, licences and service terms continue to apply.

## Software distributed with the app

| Component | Notices and licence |
|---|---|
| Flutter and Dart packages | Retain the resolved packages' licence files. The app's **Einstellungen → Datenquellen → Open-Source-Lizenzen** page includes Flutter's collected package notices and the project licence. |
| CesiumJS | [Apache-2.0 notice](web/cesium/LICENSE.md); additional bundled components and their notices are recorded in [ThirdParty.json](web/cesium/ThirdParty.json). Do not replace these with the project's licence. |
| GeoTIFF.js | [MIT licence](web/vendor/geotiff/LICENSE); retain the notice with the bundled code. |
| Components bundled by `image` and `archive` | Their additional upstream notices are retained in [assets/licenses](assets/licenses/README.md) and included in the app's licence page. |

The resolved desktop package graph also includes [MPL-2.0](https://www.mozilla.org/en-US/MPL/2.0/FAQ/) components (`dbus`,
`geoclue` and `gsettings`). Their file-level licence and source-availability
obligations remain applicable when those components are distributed; they do
not change the licence of FPVManager's original code. Package/platform inclusion
depends on the target build. Keep the notices and required source for the actual
components you redistribute. This page is an inventory guide, not a replacement
for the full notices in the resolved packages or native build artifacts.

## Data and external services

| Material | Separate terms and provenance |
|---|---|
| Bundled Swiss tunnel centreline index | [OpenStreetMap/Geofabrik ODbL notice](web/data/tunnels/ODBL_NOTICE.txt). This is a separately licensed derived database. |
| CHGeo2004 height-conversion grid | [CC0 notice and provenance](assets/geo/chgeo2004_ln02.NOTICE.txt). |
| Bundled forest composition overview | BAFU / WSL · Waldmischungsgrad LFI 2023. [Metadata and Opendata BY terms](docs/map_sources_and_attribution.md). The bundled raster is a derived 320 m overview. |
| Native Ganter bridge regression subset | [swisstopo source, modifications and retrieval date](test/fixtures/bridges/README.md). The source geometry is not Apache-licensed by FPVManager. |
| Imagery, terrain, 3D models and aviation layers | [Map sources and attribution](docs/map_sources_and_attribution.md). |
| Weather, observations, mobility and other online data | [Weather](docs/weather.md), [mobility and OSINT](docs/mobility_osint.md) and the displayed source information. |

Apache-2.0 grants permissions for the project's original material. It does not
grant access to third-party services, waive attribution or download limits, or
create rights in other people's data. Preserve the relevant notices in source
and binary distributions, offline packages and exported datasets.
