# Mobility & OSINT

Open **Mobility & OSINT** in the navigation menu, or **Driving route** in a
spot's details. Enter a start position (device location is optional), choose
**Freies Ziel** for Swiss address/place search or direct coordinates, or a
saved spot with optional parking/access coordinates. **Ziel suchen** sends only
the entered query to geo.admin.ch; typing alone stays local. Spot access notes stay in
the personal database and are deleted with the spot. Driving destination priority
is parking, access point, then the spot. Calculating requires consent to send the
two coordinates to FOSSGIS. Results show distance/time and can be drawn on the globe;
they do not establish parking/access rights. Up to three OSRM alternatives can be
selected; the service may return only one.

**Bodenrouten** provides separate walking and cycling planning through the documented
FOSSGIS foot/bike profiles. Select a mode and consent to send endpoints before
calculating. Geometry, mode, endpoints, source and calculation time are saved locally,
included in personal backups and exchanged through GPX. Missing surface/access or
elevation information remains unknown. These routes have no drone/AGL settings and
do not provide walking/cycling turn-by-turn guidance.

**Map Layers → OSINT** also offers independent official hiking, cycling, MTB and
winter networks, wildlife quiet zones and temporary closures/diversions. Official
legends and bounded detail queries explain supported classifications, seasons and
validity; overlapping records are retained. Source dates and incomplete coverage
remain explicit. WMS layers require a connection; this feature does not download
their tiles for offline use. Targeted feature excerpts stay in memory, since
cantonal redistribution terms differ. Neither an empty result nor a displayed
network confirms accessibility or permission. Closures do not automatically reroute.

Enable **Verkehr bei der Routenbewertung berücksichtigen** to compare existing
traffic snapshots locally. Current source points require an explicit matching
road number and supported travel direction. Resolved TMC sections require a verified
matching table and an ordered chain of anchors along one continuous OSRM road;
offsets are measured on that route, never on straight anchor connections. Closures sort behind
routes without matched closures; the largest published delay influences the
comparison without summing possibly overlapping reports. Current aggregate speed
measurements have a small influence only when comparable observations exist for
every alternative. Sources, exclusions and rules are expandable below the routes.
Select the desired route explicitly. Display references, approximate lines,
unresolved TMC references, stale/unverified imports and unknown directions are not weighted.
OSRM times remain baseline estimates, without traffic-adjusted arrival times.

**Map Layers → Map → Straßen und Wege** adds the transparent swissTLM3D road/path
network with persistent visibility and opacity. The Topo base map retains a finer
terrain/imagery level longer while zooming out; labels remain scale-dependent.
Flight graphics keep their own detail budget. Navigation inherits this map style
and road overlay; its layer menu can switch between Topo/Satellite and roads.
Buildings and vegetation each have independent **Wie Karte / Aus / Ein** choices
under **Einstellungen → Navigation**, also available in the navigation layer menu.
Navigation temporarily uses its own graphics/model budgets and restores map settings
on exit. Missing 3D data does not stop guidance; cached-only mode makes no model requests.

**Map Layers → OSINT** controls the independent aerodrome/heliport and wildfire
layers, opacity, retry and official legends. Other loaded snapshots can be removed
there. Map style changes and renderer reloads retain requested layers during the
session. These layers are supplementary; consult official publications and local
orders. **Lawinenbulletin · SLF** loads the official national GeoJSON on request,
with regional danger levels, published daily periods, opacity and selectable
descriptions including elevation bands and aspects. Visibility and opacity persist.
Licensed local snapshots retain publication, retrieval and validity times; expired
areas are hidden and unconfirmed/old data appear gray. No active bulletin means
missing current information, never an all-clear. Consult the linked official
bulletin and local conditions; regional colors are not individual slope ratings.
Source: [WSL Institute for Snow and Avalanche Research SLF](https://www.slf.ch),
[CC BY 4.0 and data-service conditions](https://www.slf.ch/de/services-und-produkte/slf-datenservice/).

On Android, a calculated driving route offers **Navigation starten**. Navigation
uses foreground GPS, OSRM turn instructions, remaining distance/time and a camera
that follows the position. **+ / −** adjusts the follow distance (60–1,800 m),
retained during the session. The compass aligns the map north; tapping again
returns to the tilted follow view. The recenter control also switches to free map movement.
GPS course/accuracy and movement between reliable fixes guide route matching and
rerouting, including sustained opposite travel and passing the destination.
Arrival requires repeated nearby fixes at low speed; moving away resumes guidance.
The start dialog explains location use and automatic rerouting through FOSSGIS.
Inaccurate/stale GPS pauses guidance; **GPS erneut verbinden** retries location.
Navigation pauses in the background and stops tracking on exit. Optional speech
uses an installed German offline voice; no speech data is downloaded automatically.

Enable ASTRA in the start dialog after saving your traffic token. Available data
loads on entry; **Verkehr aktualisieren** refreshes it manually. The start dialog
and traffic panel offer updates every 60 seconds while navigation is active.
Backgrounding or ending navigation stops automatic requests; HTTP 401/403/429
disables them until explicitly enabled again.
The panel and map show up to 50 nearby messages within 300 m of the remaining
route, with source/retrieval times and unavailable/stale states. Proximity does
not establish the same road or travel direction. Unresolved TMC records remain unlocated.
**Verkehr bei Neuberechnung berücksichtigen** uses the same optional comparison
when rerouting. **Routenalternativen neu berechnen** requests new candidates;
reroutes remain limited to once per 30 seconds. Traffic updates alone do not switch
the active route. This compares returned alternatives; it does not update OSRM's
road graph or guarantee an optimal detour. OSRM arrival estimates exclude delays.

**Traffic** supports an own registered ASTRA API key on Android and local DATEX II
XML snapshots on both platforms. Use the **Token** for **Road traffic - traffic
situations**, not its Token Hash or an OJP key. Android stores keys in secure storage.
The source rejects browser preflight requests, so direct Web refresh is disabled;
import a snapshot downloaded with your own access instead. No public proxy is used.
Keys never enter renderer messages, datasets or exports. Requests go only to the
official endpoint; redirects are refused. Only public descriptions are displayed.
The first request loads a full snapshot. Subsequent requests within four minutes
merge changes using `If-Modified-Since` with a 30-second overlap, including whole
situation replacements and withdrawals. Longer gaps or a day require a full reload.
Manual requests are limited to once per fifteen seconds. Search includes grouped
German public descriptions and unlocated events; filters separate current/planned
events and types. Map limits apply after selecting nearby events, not during ingestion.
**Traffic → TMC-Ortsdaten** detects required Swiss table versions. Load a version
or all missing supported versions explicitly; LTEF ZIP downloads support 7.3–7.5
from [ASTRA’s public TMC dataset](https://data.opentransportdata.swiss/dataset/rds-tmc).
Each version persists independently in the public OSINT cache and can be deleted.
The downloaded reference table can be reopened offline; it does not refresh live
traffic timestamps. Source dates and local retrieval times remain separate.
In Web, download the official ZIP externally, choose its version and use
**TMC-ZIP importieren**. Imported tables remain informational until replaced by a
direct official download. GeoPackage is explicitly unsupported in this importer.
Resolved anchors and names improve map display and search. Anchor connections are
approximate; nonzero offsets show a reference point until assigned to a route.
Missing codes, broken chains and version conflicts retain the original messages.
Downloads are bounded to 8 MiB; ZIP expansion to 32 MiB; graphs to 50,000 points.
No road position is guessed from a name or an unmatched location code.

**Aircraft** uses optional adsb.lol reception snapshots in a 25-nautical-mile area.
Android supports manual direct refresh after area-sharing consent. The provider's
current CORS policy prevents direct Web requests; import its readsb JSON snapshot
instead. There is no third-party proxy or automatic polling. Markers are projected
onto terrain; reported barometric/geometric altitudes and position timestamps stay
in details. No altitude is silently treated as terrain AGL. Markers older than 30 s
are amber; those older than 5 min are hidden. Missing aircraft never means empty
airspace. Use visual observation and official aviation information.

Source publication, retrieval/import time, cache state and incomplete/unlocated
records are separate. Imports remain unverified; a failed refresh retains the last
valid session snapshot. Traffic/aircraft snapshots are not written to persistent
OSINT storage or exported. ASTRA situation downloads and file imports stream up to 32 MiB and 20,000
records, retaining one XML record at a time (maximum 256 Ki characters/10,000 events;
nesting depth 64; at most 256 parts per named situation). Aircraft responses and
imports stay limited to 4 MiB. Maps show up to 1,000 features; route geometry is limited to 20,000 vertices. Unsupported
formats or excessive datasets fail explicitly. DATEX external entities are rejected.

**Live-Messwerte · Traffic Counters** uses a separate registered token, stored with
the same local credential protection. It loads the official measurement-site table
and requests up to 100 nearby detectors within 30 km of the displayed area centre.
Measurements are joined by table/site versions and measurement definitions, with
vehicle groups, lane metadata, source time, km/h and vehicles/hour kept separate.
Missing/error values remain unavailable. Refresh is limited to once per minute;
navigation can refresh both sources together. Old or unknown measurement times are
labelled; markers older than three minutes disappear. Data remains in session memory.
These are point measurements, not continuous congestion coverage or traffic-aware ETA.

## Provider review (2026-10-24)

| Source | Access and use |
| --- | --- |
| [FOSSGIS / OSRM](https://routing.openstreetmap.de/about.html) | OSM-based routes; attribution, max 1 request/s, no heavy usage. Coordinates enter provider logs. The client coalesces duplicate requests and rate limits requests. |
| [ASTRA DATEX II](https://opentransportdata.swiss/en/cookbook/road-traffic-cookbook/traffic-situations/) | Own registered API access; SOAP/Authorization header; Swiss coverage; TMC topology is separate. |
| [ASTRA Traffic Counters](https://opentransportdata.swiss/en/cookbook/road-traffic-cookbook/rt-road-traffic-counters/) | Separate own token; metadata and filtered measurements via the official SOAP endpoint. Browser preflight returned HTTP 401 without CORS headers (2026-10-25); authenticated Android refresh requires manual verification. |
| [ASTRA terms](https://opentransportdata.swiss/de/tac-fedro/) / [traffic API plan](https://api-manager.opentransportdata.swiss/portal/catalogue-products/tedp_road_traffic_traffic_situations_policy-1) | Current portal plan: 5 requests/min/key, quota 260,000; standard access limited to six months. No redistribution of raw data via an API. User accepts the provider's terms independently. |
| [adsb.lol](https://api.adsb.lol/docs) | Free community API, ODbL; contact provider before production deployment. Incomplete reception and no direct Web CORS access in the live probe. |
| [OpenSky](https://opensky-network.org/about/terms-of-use) | Written agreement required for operational REST integration; not enabled. |
| [BAZL aerodromes/heliports](https://www.bazl.admin.ch/de/zivile-und-militaerische-flugplaetze) | Published planning data, not the operational AIP. WMS `ch.bazl.flugplaetze-heliports`. |
| [BAFU wildfire legend/source](https://api3.geo.admin.ch/rest/services/api/MapServer/ch.bafu.gefahren-waldbrand_warnung/legend) | WMS `ch.bafu.gefahren-waldbrand_warnung`; source date/validity unknown unless published separately. Successful tile loading is not proof of current hazard information. |

WMS 1.3.0 capabilities verified EPSG:3857 and PNG visualization for both new
layers. Both reuse the bounded, recoverable obstacle WMS transport. New overlays
have independent source credits, bounded batches, cancellation, viewport/age
filtering and cleanup. No confidential emergency information or live responder
locations are added. Tests use synthetic data; real API credentials, coverage
and device gestures require separate manual verification.

## Navigation rendering checks (#72 / #73)

Camera/marker interpolation runs locally before Cesium updates the scene; GPS speed,
course validation, route matching and announcements keep their original fixes.
Interpolation stops at the last fix. Jumps over 250 m start a conservative overview;
missing fixes hide the marker. Free-camera mode stops follow updates; returning to
follow blends the actual camera pose over 650 ms. Pausing/exiting releases the loop
and restores graphics/camera state. Terrain samples are limited to 5 Hz with at most
256 cached cells; unavailable terrain cannot supply ellipsoid fallback heights.

Navigation uses at most 0.9 resolution scale, 2× MSAA and a 256-tile terrain/imagery
cache target. Building/vegetation cache targets are 24/12 MiB with 2 MiB overflow each,
screen-space error 32/56, no model shadows or hidden/sibling preloading. These are
Cesium cache targets, not a hard limit on total application memory.
See [scene update events](https://cesium.com/learn/cesiumjs/ref-doc/Scene.html#preUpdate)
and [3D Tiles cache semantics](https://cesium.com/learn/cesiumjs/ref-doc/Cesium3DTileset.html#cacheBytes).

Reproduce with `python tool/serve_globe_smoke.py --port 8780`, then open
`http://127.0.0.1:8780/navigation-smoke`. For the comparison, first export
`git show 9b013db:web/road_navigation.js` as UTF-8 to
`.dart_tool/road_navigation_baseline.js`, then open `/navigation-smoke?baseline=1`.
Use the same viewport and no parallel test processes. `/navigation-smoke?live3d=1`
checks official Swiss model loading, reuse and restoration separately.

2026-10-30, one sequential Chrome headless/SwiftShader run per variant, 800×420 CSS
map viewport, synthetic flat terrain/grid imagery, eight nominal 1 Hz fixes:

| Measurement | Baseline | Updated |
| --- | ---: | ---: |
| Drawing buffer | 800×420 | 720×378 |
| Frame samples | 30 | 27 |
| Median / p95 frame interval | 294.16 / 355.55 ms | 301.68 / 354.50 ms |
| Frames over 100 ms | 28 | 27 |
| Median / p95 scene update/render CPU interval | 10.68 / 19.46 ms | 8.08 / 15.12 ms |
| Largest displayed position step | 13.70 m | 6.18 m |
| Largest heading step | 12.00° | 5.41° |
| GPS bridge packets | 8 | 8 |
| Total terrain height calls, including Cesium | 30 | 70 |

The updated renderer made 15 of those terrain queries; smoother camera motion also
causes more Cesium-internal queries. The run demonstrates intermediate poses and
lower measured scene CPU intervals, **not a higher device frame rate**. Software
rendering still stalls; official model streaming also produced long pauses in this
environment. Reference Android and hardware-accelerated Web measurements remain open:
record device, viewport/resolution, layers, cold/warm loading, median/p95 frame time
and stalls while following, panning, turning, backgrounding and resuming. No physical
Android navigation or app build was performed here.
