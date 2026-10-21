# Privacy and permissions

FPVManager works without an account and has no analytics/tracker integration,
automatic sharing or server-side user profile.

## Local records and permissions

Spots, notes, photos, equipment, routes and map preferences are stored in local
Drift/SQLite storage. The app does not upload or publish these records. There
is no backup/export/sync interface; OS backups and file providers follow their
own settings.

Photos are imported only through the file picker. Persisted JPEGs/thumbnails
omit source EXIF/GPS metadata; originals remain unchanged. The native picker
may keep an original copy in its temporary cache.

Only **Use current location** requests a one-time position and, if needed,
permission. Android declares foreground coarse/fine location, supports approximate
location and requests no background access. There is no continuous position
stream. Lookup times out after 20 seconds once permission is resolved. Only
latitude/longitude enter the editable draft; Save is required. Manual edits
and closed editors are protected from late results. Web needs a secure context;
OS/browser location providers operate under their own settings.

## External requests

Opening/navigating the online map contacts providers. Requests expose connection
IP/request metadata and can reveal the viewed area through tile identifiers,
including when focusing a private spot or displaying a route.

| Destination | Trigger and data |
|---|---|
| `wmts.geo.admin.ch` | Map startup/navigation/style changes or imagery refresh after terrain retry; layer, zoom and tile coordinates. |
| `3d.geo.admin.ch` | Terrain startup/probe, navigation, height queries, ground view, route framing/previews and explicit retry; terrain tile identifiers revealing sampled areas. |
| `data.geo.admin.ch` | Enabling/refreshing UAS data, re-enabling expired data, restoring enabled preferences or explicitly checking a spot/route; public national dataset URL, without a user-position query. |
| `geodesy.geo.admin.ch` | Only explicit LN02 conversion; selected longitude/latitude/elevation, then LV95 coordinates/Bessel height, in GET query parameters. |
| App origin (Web) / app-owned loopback origin (Android) | Application, Cesium, Workers, Wasm and Flutter renderer resources. The documented Web build bundles renderer assets locally. |

Map requests contain no spot names, notes, photos, equipment assignments or
route JSON. Tile requests can still reveal planned/viewed locations. Local
coordinate conversion and AGL arithmetic require no external service. Disabling
UAS stores that choice for the next start; cache-age display makes no requests.

See [map sources and attribution](map_sources_and_attribution.md) for source
conditions and [the user guide](user_guide.md) for controls.
