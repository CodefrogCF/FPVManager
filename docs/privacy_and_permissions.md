# Privacy and permissions

FPVManager works without an account and has no analytics/tracker integration,
automatic sharing or server-side user profile.

## Local records and permissions

Spots, notes, photos, equipment, routes and map preferences are stored in local
Drift/SQLite storage. The app does not upload or publish these records. There
is no automatic synchronization. **Offline & personal data** creates portable
backups, optionally encrypted with a password, and previews restoration before
replacing personal records. Backups include images, planning preferences,
checklists and imported telemetry; API keys and public dataset/map caches are
excluded. Unprotected backups contain readable personal information. Restore
can re-enable backed-up map preferences and their documented network requests.
Route import/export is explicit: only the selected
route is written to the chosen Android document destination or Web download.
Android automatic cloud backup and device transfer are excluded in the app's
backup configuration. An explicitly selected file provider can still save an
export to a cloud destination according to that provider's settings.

Downloaded public UAS and obstacle datasets use a separate local cache. UAS cache
retention is 30 days; **Map layers → Clear UAS dataset cache** removes it without
deleting personal records. Supported viewed map/terrain tiles and region labels
use a separate map-cache section: up to 256 MiB of retained tile payloads, with
overlapping regions sharing tiles. Android stores them in the public-data cache
database; Web uses origin-local Cache Storage. Region removal prunes unneeded
tiles. Retrieval timestamps and incomplete coverage remain visible; they do not
establish official publication dates or live safety information.

Prepared Web builds cache verified application assets for reopening after installation,
subject to hosting cache headers and browser storage availability. Browser
storage may be cleared or evicted; a portable backup protects personal records
independently. A cached-map choice concerns base maps and terrain; enabled live
overlays and explicit weather/traffic/routing/API actions retain their documented
network behavior. It is not an application-wide network blocker.

Photos are imported only through the file picker. Persisted JPEGs/thumbnails
omit source EXIF/GPS metadata; originals remain unchanged. The native picker
may keep an original copy in its temporary cache.

**Use current location** / **Use device location** requests a one-time position and, if needed,
permission. Android declares foreground coarse/fine location, supports approximate
location and requests no background access. This lookup times out after 20 seconds once permission is resolved. Only
latitude/longitude enter the editable draft; Save is required. Manual edits
and closed editors are protected from late results. Web needs a secure context;
OS/browser location providers operate under their own settings.

Android **Navigation starten** separately enables a foreground position stream.
Starting confirms automatic rerouting: current coordinates and destination can
be sent to FOSSGIS when leaving the route. Backgrounding pauses navigation; exit
cancels location tracking. Positions stay in memory and are not recorded/exported.
Optional spoken instructions use an installed German offline voice.

## External requests

Opening/navigating the online map contacts providers. Requests expose connection
IP/request metadata and can reveal the viewed area through tile identifiers,
including when focusing a private spot or displaying a route.

| Destination | Trigger and data |
|---|---|
| `wmts.geo.admin.ch` | Map startup/navigation/style changes or imagery refresh after terrain retry; layer, zoom and tile coordinates. |
| `wms.geo.admin.ch` | Enabling/restoring obstacle, aerodrome/heliport or wildfire imagery and navigating while enabled; viewed area, projection and image dimensions. |
| `api3.geo.admin.ch` | Opening official obstacle, aerodrome/heliport or wildfire legends; public legend URL. |
| `aws.slf.ch` | Enabling or manually refreshing the avalanche bulletin downloads one national GeoJSON, without sending coordinates or saved records. A licensed local snapshot can be restored without a network request. There is no automatic polling or per-viewport download. |
| `3d.geo.admin.ch` | Terrain startup/probe, navigation, height queries, ground/flight view, route framing/previews and explicit retry; terrain tile identifiers revealing sampled areas. Optional buildings/vegetation additionally request visible 3D tiles while enabled. These caches stay in renderer memory and are outside offline regions. Sun/moon calculations use the device clock or selected UTC time locally, without an additional location API. |
| `data.geo.admin.ch` | UAS checks/refresh and obstacle STAC metadata/full KMZ download; public national dataset URLs, without a user-position query. Restoring obstacle vectors reads a local snapshot first. |
| `data.geo.admin.ch` (weather) | Selecting MeteoSwiss or refreshing/comparing forecasts; public point metadata and national forecast CSV files. Coordinates are matched locally and are not part of these requests. |
| `api.open-meteo.com` | Open-Meteo forecasts, spot comparisons and weather overlays; selected coordinates, requested parameters and forecast range. Optional 3D/flight wind explicitly requests nine positions around the selected point/view (current simulated position when flying). Active current wind refreshes the same region every 15 minutes in the foreground; forecasts refresh manually. Wind snapshots stay in session memory. |
| `routing.openstreetmap.de` | Explicit driving-route calculation, plus automatic rerouting during confirmed foreground navigation; start/current and destination coordinates, without spot names or access notes. |
| `api.opentransportdata.swiss` | ASTRA traffic situations and optional Traffic Counters on Android, using separate own tokens in authorization headers. Situation requests are national; counter requests contain selected detector IDs, which reveal the requested area. Opted-in navigation can refresh every minute, pausing in the background. Datasets stay in session memory. Web uses local situation XML imports; no public proxy. |
| `data.opentransportdata.swiss`, official `eu.r2.cloudflarestorage.com` download host | Explicit public TMC table downloads on Android; only the requested table version, without API tokens or user coordinates. Bounded redirects are restricted to the known official hosts. Reference tables persist in the public OSINT cache independently of live traffic; Web supports local ZIP import. |
| `api.adsb.lol` | Explicit Android aircraft refresh after consent; rounded area centre and a 25 NM radius. Web supports local snapshot import because the source blocks direct CORS requests. |
| `geodesy.geo.admin.ch` | Only explicit LN02 conversion; selected longitude/latitude/elevation, then LV95 coordinates/Bessel height, in GET query parameters. |
| App origin (Web) / app-owned loopback origin (Android) | Application, Cesium, Workers, Wasm and Flutter renderer resources. The documented Web build bundles renderer assets locally. |

Configured topographic/relief and terrain requests pass through the app's local
tile cache. Only fixed official swisstopo endpoints are eligible; source requests
carry no API credentials or personal record bodies. Cached-only requests never
fall back to a remote tile. Supported caching follows [swisstopo OGD terms](https://www.swisstopo.admin.ch/en/terms-of-use-free-geodata-and-geoservices)
and [FSDI operating conditions](https://www.geo.admin.ch/en/general-terms-of-use-fsdi);
viewed-tile caching does not systematically prefetch those rendering services.
On-device preparation queries official STAC metadata using the selected bounding
box and reads allowlisted GeoTIFF byte ranges from `data.geo.admin.ch`, including
SWISSIMAGE download assets. No tile-rendering service is systematically scraped.
The source index preserves expected whole-file checksums; partial downloads do
not verify those whole-file checksums. Exposed ETags pin range reads to one edition.
Derived tiles remain local; failed preparation retains the previous region.
The optional laptop workflow verifies full source-file checksums. Package import
makes no external requests. Source editions and preparation time remain separate.
Mixed third-party online imagery and live WMS overlays are not included.

Map requests contain no spot names, notes, photos, equipment assignments or
route JSON. Tile requests can still reveal planned/viewed locations. Local
coordinate conversion and AGL arithmetic require no external service. Disabling
UAS stores that choice for the next start; cache-age display makes no requests.

See [map sources and attribution](map_sources_and_attribution.md) for source
conditions and [the user guide](user_guide.md) for controls.
See [Mobility & OSINT](mobility_osint.md) for source terms, session-only snapshots
and secure storage of user-provided credentials.

Swiss destination search sends the entered address/place query to geo.admin.ch
only when **Ziel suchen** is pressed. Results are not saved as spots automatically.
Automatic rerouting also sends a reliable travel bearing to FOSSGIS when available.
