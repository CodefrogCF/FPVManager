# Privacy and permissions

The [privacy policy](../../PRIVACY.md) identifies Codefrog and the privacy contact.
FPVManager has no account, app-managed record sharing or analytics integration.
It stores personal records on the device. Online providers can receive network
metadata and the areas or query inputs required for their services.

## Personal records, files and credentials

Places, photos, notes, equipment, routes, checklists, telemetry, activity profiles
and preferences use local Drift/SQLite storage. There is no automatic sync.
**Offline & Daten** exports a portable personal backup, optionally password-
protected, and validates/restores it only after confirmation. API keys and public
map/OSINT caches are excluded. Unencrypted exports remain readable; an explicitly
chosen system file provider can store them in a cloud destination.

Photo import uses the file picker. Stored JPEGs/thumbnails omit source EXIF/GPS
metadata; the original file is not changed. A native picker may retain an original
in its own temporary cache. Route/profile/telemetry imports and exports occur
only through the selected file action. Android automatic cloud backup and device
transfer are disabled by the app's backup configuration. On iOS, personal
records in the app's documents directory can be included in device backups.
The separate iOS map and public-data cache directory is excluded from backups.

Registered service credentials are kept in the existing local credential vault,
not plain map preferences, rendered datasets or personal backups. ASTRA situations,
traffic counters and OJP 2.0 use different product keys. Web storage/access depends
on the supported provider and platform; no public credential proxy is supplied.
Submitted provider requests carry only the required credential to that provider.

## Foreground location and searches

A one-time **Use current location** action asks the OS/browser for a fix and, if
needed, permission. Android requests foreground coarse/fine location and supports
approximate fixes; background access is not requested. Manual entry remains
available, late results cannot replace newer edits, and Save is required.

**Mein Standort** on the globe separately enables foreground position updates.
They stop when disabled, backgrounded or disposed and are suspended during ground
inspection/simulation. The app keeps no GPS history. Centering and following
change the viewed map area, which online tile requests can reveal.
WGS84/LV95 coordinate parsing is local. Submitted
place/address searches go to swisstopo. Typing alone does not send a search.

Android road navigation starts a separate foreground GPS stream after its dialog.
Automatic rerouting may send current coordinates and destination to FOSSGIS.
Backgrounding pauses navigation and exit cancels the stream. Navigation positions
remain in memory; optional speech uses an installed offline voice.

## Network requests

Tile identifiers, bounding boxes and service queries can reveal viewed or planned
areas, including private locations. The main request boundaries are:

| Provider / destination | Trigger and transmitted information |
|---|---|
| `isk.geobasis-bb.de` | Online satellite, topographic and relief WMS imagery for Berlin/Brandenburg; viewport tile bounds and map style. No automatic offline capture or region-wide download; credits include LGB and Geoportal Berlin. |
| `wmts.geo.admin.ch`, `wms.geo.admin.ch` | Online imagery/overlay startup, restored enabled layers, map movement or retry; requested layers, tile coordinates or map envelope. |
| `3d.geo.admin.ch` | Terrain startup/sampling and enabled buildings, vegetation or structures; visible/sampled terrain and model tile identifiers. Lighting time is calculated locally. |
| `api3.geo.admin.ch` | Submitted place/address searches; enabled place/street labels; bounded bridge/outdoor/BAKOM/EV queries; opened legends. Requests carry the corresponding text or selected area, not personal record bodies. |
| `data.geo.admin.ch` | National UAS/obstacle and MeteoSwiss files, radar metadata/data, dated imagery and offline source discovery. Area-based STAC queries can include the selected bounds. The radar decoder is bundled locally. |
| `api.open-meteo.com` | Explicit forecasts/comparisons/overlays and selected wind region. Sends coordinates, parameters and forecast range. Active current wind can refresh every 15 minutes in the foreground. Free-API logs may contain coordinates and are deleted after 90 days according to [Open-Meteo](https://open-meteo.com/en/terms#privacy). |
| `data.bafu.admin.ch` | Hydrological station/observation queries; requested sites/criteria can reveal the selected area. |
| `aws.slf.ch` | Explicit national avalanche bulletin load/refresh; no point or route coordinates. There is no automatic per-viewport bulletin download. |
| `routing.openstreetmap.de` | Confirmed driving/walking/cycling route calculation sends start and destination coordinates. Road navigation can also send current position and bearing when rerouting. [FOSSGIS](https://routing.openstreetmap.de/about.html) logs route requests. |
| `api.opentransportdata.swiss` | Explicit ASTRA/counter or OJP requests with the appropriate own key. Counters send requested site IDs; OJP sends journey endpoints, time and criteria. Optional ASTRA navigation refresh is foreground-only. |
| `data.opentransportdata.swiss` and the official table-download host | Explicit TMC version downloads; requested table/version, without service keys or a user-position query. |
| `api.adsb.lol` | Explicit Android aircraft refresh after consent; rounded area centre and search radius. Web can import a local snapshot instead. |
| Overpass endpoints (`overpass-api.de`, `overpass.private.coffee`) | Manual nearby-POI searches, optional bridge fallback or tunnel fallback when the prepared index is missing; requested categories/area. Normal bundled-index tunnel loading is local. |
| `api.sharedmobility.ch` | Confirmed manual shared-mobility query; centre and radius. No background location monitoring or nationwide feed download. |
| `geodesy.geo.admin.ch` | Explicit Swiss-height conversion; selected position/height and the intermediate Swiss coordinates/Bessel height. |
| App origin / app-owned loopback origin | Flutter, Cesium, Worker/Wasm and local cached assets. Online Web installation can fetch application resources from its host. |

Map requests do not contain place notes/photos, equipment assignments or route
JSON. Some selected API actions send their own coordinates/criteria as described
above. External browsers opened for source pages operate under their own settings.

## Public-data caches and offline preparation

Public snapshots use a separate bounded cache and retain source/retrieval/validity
information. UAS cache retention is up to 30 days; **Karte & Ansicht → Luftraum →
Daten & Quellen** provides cache removal without deleting personal records.
Traffic/aircraft snapshots are session data; TMC tables and other supported public
sources have their own persistence policies. Explicitly saved OJP journeys remain
dated local records rather than live information.

The viewed base-map/terrain buffer is separate from prepared regions and can be
incomplete. Android uses the public-data cache database; Web uses origin-local
storage. **Use cached base map and terrain** prevents remote fallback for those
providers only and persists on the device across restarts. Portable backup
restore preserves the destination device's cache setting. Enabled live overlays
and explicit API actions retain their own
network behavior; this is not an application-wide network blocker.

Region preparation queries official STAC metadata for the chosen area and reads
allowlisted source assets/ranges. It derives local imagery/terrain rather than
systematically scraping rendering tiles. Source editions, preparation time,
checksums/ETags and gaps remain distinct. Failure keeps the previous active region;
package import makes no network request. Streaming 3D, WMS and live feeds are not
promised as complete offline layers.

A prepared Web application needs a completed installation before offline reopening.
Browsers can clear or evict local storage. Keep a portable personal backup
independently of any map cache. Terms and attribution are documented in
[sources and attribution](map_sources_and_attribution.md); controls are in the
[user guide](../user_guide.md) and [navigation guide](mobility_osint.md).
