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
| GeoTIFF.js 2.1.3 | [MIT licence](web/vendor/geotiff/LICENSE) and [notices for the browser bundle](web/vendor/geotiff/THIRD_PARTY_NOTICES.txt), including pako, Lerc and Zstandard. Both are in the app's licence page. |
| h5wasm 0.10.3 | Local MeteoSwiss radar decoder from the National Institute of Standards and Technology. Retain the [original licence](web/vendor/h5wasm/LICENSE.txt) and the [HDF5 and runtime notices](web/vendor/h5wasm/THIRD_PARTY_NOTICES.txt). |
| Windows WebView2 SDK, WIL and C++/WinRT | The Windows build copies the NuGet licences and any included notice files into `licenses/` next to the executable. Include that directory in the Windows ZIP. [WebView2 SDK](https://www.nuget.org/packages/Microsoft.Web.WebView2/1.0.3967.48) · [Windows Implementation Library](https://www.nuget.org/packages/Microsoft.Windows.ImplementationLibrary/1.0.260126.7) · [C++/WinRT](https://www.nuget.org/packages/Microsoft.Windows.CppWinRT/2.0.220418.1) |
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
| Bundled forest composition overview | BAFU / WSL · Waldmischungsgrad LFI 2023. [Metadata and Opendata BY terms](docs/user/map_sources_and_attribution.md). The bundled raster is a derived 320 m overview. |
| Native Ganter bridge regression subset | [swisstopo source, modifications and retrieval date](test/fixtures/bridges/README.md). The source geometry is not Apache-licensed by FPVManager. |
| Imagery, terrain, 3D models and aviation layers | [Map sources and attribution](docs/user/map_sources_and_attribution.md). |
| Weather, observations, mobility and other online data | [Weather](docs/user/weather.md), [mobility and OSINT](docs/user/mobility_osint.md) and the displayed source information. |

Apache-2.0 grants permissions for the project's original material. It does not
grant access to third-party services, waive attribution or download limits, or
create rights in other people's data. Preserve the relevant notices in source
and binary distributions, offline packages and exported datasets.

The FPVManager distribution is non-commercial. Open-Meteo's free API
is used under its non-commercial service terms. The [showcase credits](docs/showcase_credits.txt)
identify the published video's separately licensed material. Mixkit music is
used in the video under the Mixkit Stock Music Free License.
[Open-Meteo terms](https://open-meteo.com/en/terms) ·
[Mixkit music licence](https://mixkit.co/license/modal/musicFree/)
