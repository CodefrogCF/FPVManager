# Mobility & OSINT

Open **Mobility & OSINT** in the navigation menu, or **Driving route** in a
spot's details. Enter a start position (device location is optional), choose a
saved spot and optionally save parking/access coordinates. These notes stay in
the personal database and are deleted with the spot. Driving destination priority
is parking, access point, then the spot. Calculating requires consent to send the
two coordinates to FOSSGIS. Results show distance/time and can be drawn on the globe;
they do not establish parking/access rights or account for live traffic.

**Map Layers → OSINT** controls the independent aerodrome/heliport and wildfire
layers, opacity, retry and official legends. Other loaded snapshots can be removed
there. Map style changes and renderer reloads retain requested layers during the
session. These layers are supplementary; consult official publications and local
orders. The SLF avalanche bulletin is linked rather than scraped or reinterpreted.

**Traffic** supports an own registered ASTRA API key and local DATEX II XML
snapshots. Android stores keys in secure storage; Web retains them only in memory.
Keys never enter renderer messages, datasets or exports. Requests go only to the
official endpoint; redirects are refused. Only public descriptions are displayed.
Refresh is manual and requests a full snapshot, at most once per five seconds;
there is no background polling or delta subscription.
Explicit WGS84 positions are drawn; TMC-only messages remain inspectable as text
and count as unlocated. The matching official TMC topology is not bundled; request
it from ASTRA if needed. No road position is guessed from a road name or location code.

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
OSINT storage or exported. Network responses/imports are bounded at 4 MiB, with
up to 1,000 map features; route geometry is limited to 20,000 vertices. Unsupported
formats or excessive datasets fail explicitly. DATEX external entities are rejected.

## Provider review (2026-10-24)

| Source | Access and use |
| --- | --- |
| [FOSSGIS / OSRM](https://routing.openstreetmap.de/about.html) | OSM-based routes; attribution, max 1 request/s, no heavy usage. Coordinates enter provider logs. The client coalesces duplicate requests and rate limits requests. |
| [ASTRA DATEX II](https://opentransportdata.swiss/en/cookbook/road-traffic-cookbook/traffic-situations/) | Own registered API access; SOAP/Authorization header; Swiss coverage; TMC topology is separate. |
| [ASTRA terms](https://opentransportdata.swiss/de/tac-fedro/) / [limits](https://opentransportdata.swiss/de/limits-and-costs/) | Free-tier 50 requests/min/key, standard access limited to six months. No redistribution of raw data via an API. User accepts the provider's terms independently. |
| [adsb.lol](https://api.adsb.lol/docs) | Free community API, ODbL; contact provider before production deployment. Incomplete reception and no direct Web CORS access in the live probe. |
| [OpenSky](https://opensky-network.org/about/terms-of-use) | Written agreement required for operational REST integration; not enabled. |
| [BAZL aerodromes/heliports](https://www.bazl.admin.ch/de/zivile-und-militaerische-flugplaetze) | Published planning data, not the operational AIP. WMS `ch.bazl.flugplaetze-heliports`. |
| [BAFU wildfire legend/source](https://api3.geo.admin.ch/rest/services/api/MapServer/ch.bafu.gefahren-waldbrand_warnung/legend) | WMS `ch.bafu.gefahren-waldbrand_warnung`; source date/validity unknown unless published separately. Successful tile loading is not proof of current hazard information. |

WMS 1.3.0 capabilities verified EPSG:3857 and PNG visualization for both new
layers. Both reuse the bounded, recoverable obstacle WMS transport. New overlays
have independent source credits, bounded batches, cancellation, viewport/age
filtering and cleanup. No confidential emergency information or live responder
locations are added. Tests use synthetic data; real API credentials, browser CORS,
coverage and device gestures require separate manual verification.
