# Privacy-first architecture and permission policy

This policy describes the current Android/Web prototype and its application
code. Personal data works without an account. The app has no analytics/tracker
integration, server-side user profile, automatic sharing or publication feature.
Adding accounts, sharing, telemetry or another external data service requires an
explicit review of this contract.

## Personal records

Spots, coordinates, notes, normalized photos, equipment, flight plans/waypoints
and map preferences are stored in local Drift/SQLite storage. The application
does not upload these records or publish a private location/route when it is
created, edited, selected or deleted. Spot names/notes/photos and route snapshots
are not included in map-service requests.

Local storage is device/browser storage, not a guarantee about operating-system
backup behavior or a user-selected file provider. Those are controlled by the
platform and its settings. The app currently has no backup/export/sync UI.

Photos are imported only after a file-selection action. Persisted JPEGs and
thumbnails omit source EXIF/GPS metadata; original files remain unchanged, and
the system picker may keep its own temporary cache. See
[photo processing and storage](spot_photos_and_location.md).

## Device location

Opening the app or spot editor does not request location. Only **Use current
location** starts a one-time lookup and, when needed, a system/browser permission
request. Android declares foreground coarse/fine location, with approximate
location supported; it declares no background-location permission and the app
does not subscribe to a continuous position stream.

Only latitude/longitude enter the editable draft; Save is still required to
persist it. A late result cannot overwrite a newer manual coordinate edit or
update a closed editor. Denied/blocked permission, disabled services and lookup
errors leave manual coordinates available. OS/browser location providers may
use GPS or other mechanisms under their own settings. Details, timeouts and
tests are documented in [location behavior](spot_photos_and_location.md).

## External requests

The online globe requests map resources when opened. Viewing an area can reveal
that area to the corresponding provider through tile identifiers, even when no
personal record is uploaded. As with normal HTTP requests, the remote endpoint
receives the connection IP address and request metadata. The current flows are:

| Resource | Destination | Trigger and application data sent |
|---|---|---|
| Satellite, topographic and relief imagery | `wmts.geo.admin.ch` | Map startup/navigation/style changes and refresh of the selected style after an explicit terrain retry; layer, tile coordinates/zoom and format. These identify the viewed map area. |
| Terrain | `3d.geo.admin.ch` | Map startup (including a bounded level-zero tile probe), navigation, height sampling and explicit **Retry terrain**; terrain layer and tile identifiers. A terrain query samples the renderer's provider, without uploading a spot record. Offline/online events do not start an automatic reconnection loop. |
| Official Swiss UAS GeoJSON | `data.geo.admin.ch` | Enabling/refreshing UAS zones, re-enabling expired data or restoring a previously enabled preference; the public national dataset URL, without personal spot/route fields or a user-position query. Cache-age display checks do not fetch data. |
| Optional Swiss height conversion | `geodesy.geo.admin.ch` | Only the explicit LN02 conversion action in the terrain dialog; selected longitude/latitude and elevation, followed by the corresponding LV95 easting/northing and Bessel elevation. Position/elevation values appear in GET query parameters. |
| Application, Cesium, workers, Wasm and Flutter renderer assets | App origin on Web; app-owned loopback origin on Android | Local/package asset loads. The documented Web release uses `--no-web-resources-cdn`; Cesium is vendored and pinned. |

Selecting a private spot and focusing the map can therefore reveal its viewed
area through imagery/terrain requests. This is distinct from uploading its name,
notes, photo or complete route. Optional REFRAME conversion does transmit the
selected position/elevation as described above; local coordinate conversions and
the AGL calculator do not require that service.

UAS enablement is a saved user preference. Disabling it prevents an automatic UAS
dataset load at the next start; a retained in-memory dataset can be reused during
the session. Download time is not official validity, and persistent cache/offline
downloads remain separate work. Maps use a flat fallback if detailed terrain
cannot initialize; runtime tile interruption handling remains #7.

## Acceptance evidence for #5

- No required account/tracker/analytics integration: current app composition and
  locked dependencies, local repositories and bundled renderer setup.
- Explicit, necessary location access: `DeviceSpotLocationService`, the editor's
  location button, foreground Android manifest and injected location/editor tests.
- External request/privacy documentation: the inventory above,
  [architecture](architecture.md), and [coordinates and heights](coordinates_and_heights.md).
- No automatic personal-data publishing: local repository writes and marker/route
  contracts; external request construction contains no automatic personal-record
  upload. Future sharing must retain an explicit user action.

The current imagery/terrain source and service terms are recorded separately in
[map sources and attribution](map_sources_and_attribution.md) (#8).
The complete source/dependency release inventory remains #44. This privacy
policy does not substitute for those dataset and dependency conditions.
