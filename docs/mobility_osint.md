# Navigation and supplementary information

Open **Navigation & OSINT** from navigation. Its tabs separate driving routes,
public transport, traffic, aircraft, environmental layers, nearby POIs, EV
charging and shared mobility. **Karte & Ansicht → OSINT** controls their map
layers and source details. These sources are independent; a successful map
request does not establish current completeness, access rights or flight permission.

## Driving, walking and cycling

For a driving route, choose a start and a saved place or **Freies Ziel**.
**Ziel suchen** submits a Swiss address/place query; typing stays local. Saved
parking coordinates take priority over an access point, then the place itself.
Consent is required before start/destination coordinates go to FOSSGIS/OSRM.
Select among the returned alternatives; the service may return only one.

**Bodenrouten** is separate walking/cycling planning. Explicitly select the mode
and consent before calculating. Geometry, mode, endpoints, source and calculation
time are stored locally and can be backed up or exchanged as GPX. Missing access,
surface or elevation information remains unknown. These routes do not use drone
AGL settings and do not provide walking/cycling turn-by-turn guidance.

[FOSSGIS usage rules](https://routing.openstreetmap.de/about.html) require
attribution and limited, non-heavy service use. Requests enter the provider's
logs. The client limits/coalesces requests; it is not a bulk routing service.

## Android road navigation

A calculated driving route offers **Navigation starten**. The start dialog
confirms foreground GPS and automatic rerouting, which can send current position
and destination to FOSSGIS after leaving the route. The app follows accepted GPS
fixes, speaks supported turns with an installed German offline voice and shows
remaining distance/time. It does not download a voice automatically.

Use **+ / −** for follow distance, the recenter control for free-map/follow mode
and the compass for north-facing/follow views. The displayed camera/marker blends
accepted fixes without predicting beyond the latest one. Guidance and speed use
the original fixes. Poor or stale GPS pauses guidance; **GPS erneut verbinden**
retries. Backgrounding pauses navigation; exit stops tracking.

Buildings and vegetation independently use **Wie Karte / Aus / Ein** under
**Einstellungen → Navigation** or the navigation layer menu. These are temporary
navigation overrides; normal map/flight settings and aviation obstacles remain
separate. Missing streaming models do not stop guidance.

## Public transport

The **Public transport** tab uses the official Open Journey Planner **OJP 2.0**
endpoint with the user's own registered product key. Search origin/destination,
choose travel time and request a journey explicitly. An OJP key is separate from
ASTRA traffic/counter keys; OJP 1.0 credentials are not a substitute.

Journey results show supplied stops, legs, times and source information. A saved
journey is a dated local snapshot, not a live departure guarantee. Browser CORS
restrictions can block direct Web access; no public credential proxy is provided.
Account plans and quotas are governed by the current
[OJP service documentation](https://opentransportdata.swiss/en/cookbook/open-journey-planner-ojp-landing-page/),
not by the project's source-code licence.

## Traffic situations, counters and route comparison

**Traffic** accepts a registered ASTRA **Road traffic - traffic situations** token
on Android, or a local DATEX II XML snapshot on either platform. Use the product
Token rather than Token Hash. Android stores it securely; keys are excluded from
renderer messages, datasets and backups. Direct Web traffic refresh is disabled
where browser preflight is unsupported; there is no public proxy.

Manual refresh keeps source/publication and retrieval times separate. Changed
situations and withdrawals replace the corresponding records; failed refreshes
retain the last valid session snapshot. During confirmed navigation, optional
60-second refresh pauses in the background. Authorization/rate errors disable
automatic refresh until explicitly enabled again.

**TMC-Ortsdaten** loads matching official table versions or imports a selected
LTEF ZIP. Supported versions are 7.3–7.5. Tables persist in the public-data cache;
local imports remain informational until replaced by a direct official download.
Unmatched codes, broken chains and version conflicts stay unresolved. A name or
straight anchor connection is not used to invent a road location.

**Live-Messwerte · Traffic Counters** uses its own registered token. Nearby
measurement sites retain source times, lane/vehicle groups and native units.
Unknown/error measurements remain unavailable; old markers are hidden. Point
measurements are not continuous congestion coverage or a traffic-adjusted ETA.

Optional traffic comparison ranks returned driving alternatives only when
supported source locations/directions can be matched to the route. Unresolved,
stale or unverified records do not influence ranking. Closures and supported
delay/speed values remain traceable in expanded details. Traffic refresh alone
does not switch the route; choose an alternative or explicitly recalculate.
OSRM arrival estimates exclude these delays, and a detour is not guaranteed optimal.

Provider access/conditions: [traffic situations](https://opentransportdata.swiss/en/cookbook/road-traffic-cookbook/traffic-situations/),
[traffic counters](https://opentransportdata.swiss/en/cookbook/road-traffic-cookbook/rt-road-traffic-counters/),
[TMC tables](https://data.opentransportdata.swiss/dataset/rds-tmc) and
[ASTRA terms](https://opentransportdata.swiss/de/tac-fedro/).

## Aircraft

**Aircraft** obtains an optional adsb.lol reception snapshot for a 25-nautical-mile
area. Android supports explicit direct refresh after area-sharing consent; Web
can import readsb JSON where direct CORS access is unavailable. No proxy or
background polling is added.

The map projects markers onto terrain; reported barometric/geometric altitude
and source timestamps stay in details rather than becoming assumed AGL. Markers
over 30 seconds old turn amber and those over five minutes old are hidden.
Missing aircraft never means empty airspace. Consult the
[provider documentation](https://api.adsb.lol/docs) and official aviation sources.

## Environment, outdoor and dated imagery

Independent hiking, cycling, MTB and winter networks, quiet zones and closures
have official legends and bounded source-detail queries. Overlapping restrictions,
seasons, publication and validity remain distinct. WMS layers require a connection;
feature excerpts do not provide a complete offline restriction database. Displayed
networks and empty query results do not confirm access. Closures do not silently
reroute a saved route.

Aerodromes/heliports, wildfire danger and cantonal forest-fire prevention measures
are separate layers. Source categories and regional/local restrictions should be
read from their own details. Aerodrome planning data does not replace the AIP;
regional wildfire maps do not replace local orders. **Quellen & Grenzen** opens
longer source explanations without hiding current failure indicators.

**Lawinenbulletin · SLF** loads the national bulletin only on request. Regions
retain published periods, elevation bands, aspects and source descriptions.
Licensed snapshots preserve publication, retrieval and validity separately;
expired areas are hidden and unconfirmed/old data are grey. Missing current data
is not an all-clear or an individual slope rating. See the
[SLF bulletin and service conditions](https://www.slf.ch/de/services-und-produkte/slf-datenservice/).

Dated imagery discovers published **swissEO Sentinel-2** or **Rapid Mapping**
acquisitions for the selected area. Acquisition date, publication date, cloud
coverage and event context remain separate. Supported WMS/COG assets can be
shown on the globe; unsupported assets remain external references. These are
historical/delayed images, never a live camera or current hazard assessment.

**BAKOM Mobilfunk-Basisstationen** queries official station points after explicit
area-sharing consent. It displays only supplied station type, power class and
technology. A station coordinate can describe its first mast; no mast height,
obstruction volume or FPV signal-coverage estimate is inferred. Source metadata,
local cache status and incomplete results remain visible.

## Nearby POIs, EV charging and shared mobility

**Nearby POIs** makes manual, bounded OpenStreetMap/Overpass requests for selected
categories within 2 km. Displayed cards/map points can be incomplete. Stale cached
results stay labelled; saving a POI creates a separate local place and does not
silently overwrite personal edits. OSM tags do not certify drinking water,
opening hours, legal access or a facility's existence today.

**EV Charging** sends the selected search area to the BFE/GeoAdmin Identify
service only after consent. Charger/connectivity/status values remain those
supplied by the source. Cached values are dated; availability is not a reservation
or guaranteed usable charger. The app uses its supported Identify adapter, not
an assumed future provider API.

**Shared Mobility** sends a selected centre/radius to the sharedmobility.ch REST
Identify service after consent. It does not bulk-download nationwide GBFS feeds
or poll in the background. Source/provider times, missing values and stale local
snapshots remain explicit. A displayed vehicle/station is not a booking.

## Storage and limits

Traffic and aircraft snapshots are session data; TMC references and supported
other public snapshots have separate bounded caches. Explicitly saved journeys,
ground routes and places are personal records. Source time, retrieval/import,
cache age and geographic completeness are never interchangeable. Excessive,
unsupported or malformed imports fail explicitly rather than being silently
truncated into a complete-looking result.

Network triggers and credential storage are summarized once in
[privacy and permissions](privacy_and_permissions.md). The map's **Quellen**
control and [sources guide](map_sources_and_attribution.md) retain attribution.
