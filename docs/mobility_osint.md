# Mobility & OSINT

Open **Mobility & OSINT** in the navigation menu, or **Driving route** in a
spot's details. Enter a start position (device location is optional), choose
**Freies Ziel** for Swiss address/place search or direct coordinates, or a
saved spot with optional parking/access coordinates. **Ziel suchen** sends only
the entered query to geo.admin.ch; typing alone stays local. Spot access notes stay in
the personal database and are deleted with the spot. Driving destination priority
is parking, access point, then the spot. Calculating requires consent to send the
two coordinates to FOSSGIS. Results show distance/time and can be drawn on the globe;
they do not establish parking/access rights or account for live traffic.

**Map Layers → Map → Straßen und Wege** adds the transparent swissTLM3D road/path
network with persistent visibility and opacity. The Topo base map retains a finer
terrain/imagery level longer while zooming out; labels remain scale-dependent.
Flight graphics keep their own detail budget. Navigation inherits this map style
and road overlay; its layer menu can switch between Topo/Satellite and roads.

**Map Layers → OSINT** controls the independent aerodrome/heliport and wildfire
layers, opacity, retry and official legends. Other loaded snapshots can be removed
there. Map style changes and renderer reloads retain requested layers during the
session. These layers are supplementary; consult official publications and local
orders. The SLF avalanche bulletin is linked rather than scraped or reinterpreted.

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
not establish the same road or travel direction. TMC-only records remain unlocated.
OSRM arrival estimates exclude traffic delays; ASTRA messages do not automatically
change road weights or generate traffic-dependent detours.

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
Explicit WGS84 positions are drawn; TMC-only messages remain inspectable as text
and count as unlocated. The matching official TMC topology is not bundled; obtain
the matching version from [ASTRA’s public TMC dataset](https://data.opentransportdata.swiss/dataset/rds-tmc). No road position is guessed from a road name or location code.

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
