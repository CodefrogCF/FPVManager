# Issue #93 — Official BAKOM mobile-phone base stations

## Scope and source

The feature is accessible under **Mobility & OSINT → Environment → BAKOM Mobilfunk-Basisstationen**. It is independent of broadcast transmitters, obstacles, wildfire and radio-signal simulation.

Official resources:

- Collection: https://data.geo.admin.ch/api/stac/v1/collections/ch.bakom.standorte-mobilfunkanlagen
- Collection item/asset listings: `/items?limit=20`, `/assets` on the collection's STAC v1 endpoint.
- Bounded *station feature* query: `https://api3.geo.admin.ch/rest/services/ech/MapServer/identify`, `layers=all:ch.bakom.standorte-mobilfunkanlagen`, `geometryType=esriGeometryEnvelope`, `sr=2056`, `limit=200`, `geometryFormat=esrijson`, `tolerance=0`.
- Official explanation: https://www.bakom.admin.ch/de/erlaeuterungen-zur-ubersichtskarte
- GeoAdmin STAC documentation: https://docs.geo.admin.ch/download-data/stac-api/overview.html
- GeoAdmin Identify documentation: https://docs.geo.admin.ch/access-data/identify-features.html

**Important distinction:** STAC lists downloadable *assets*; STAC items are NOT station point features. This implementation discovers the collection, item and collection-wide asset listings, classifies advertised JSON/CSV vs unsupported formats (e.g. GeoPackage) and uses the official, **bounded** GeoAdmin Identify API for the operative point import. It does **not** claim to import unsupported STAC file formats or download an entire Swiss dataset. A future bulk-import issue would need a properly tested GeoPackage or other officially advertised asset decoder.

The BAKOM fields are retained as reported: `station`, `typ_de`, `techno_de`, `power_de`, `adaptiv_de`, `koord`, `featureId`. Coordinates in `koord` are Swiss LV95; rendering uses the existing swisstopo approximate LV95→WGS84 conversion. Exact LV95 easting and northing are retained. If no `koord` exists, the source feature geometry is used where possible. Unknown field values stay unknown; **no object/mast/antenna height is assumed**.

BAKOM explains that a shown station location is the first mast of a site; multiple antennas or masts may exist. The technology and power class do not establish obstruction dimensions, received signal strength, interference or guaranteed FPV/mobile coverage.

## Import, persistence and performance

- Explicit user consent for sending the selected area to geo.admin.ch; no automatic background polling.
- Search radius: 250 m to 5 km (UI choices: 500 m, 1 km, 2 km, 5 km).
- Maximum 200 stations and 1.8 MB JSON per official request; truncated or limit-reaching results are labelled incomplete.
- Maximum 12 queries/hour, minimum 15 seconds between network calculations, identical in-flight calls coalesced; local cache reused for up to 24 hours unless manually refreshed.
- Network requests use the shared cancellation-aware transport. JSON decode is performed via `compute` (Android isolate, bounded main-thread work in Flutter Web).
- The separate `fpvmanager_osint_cache` database migrates from schema v3 to **v4**, adding `mobile_site_regions` and `mobile_site_points`. Only 12 selected areas are retained. Indexed `(area_key,lat,lon)` and `(area_key,lon,lat)` numeric filters limit the result before transfer to Cesium; the bridge accepts up to **180 points** at once.
- Area replacement occurs in a SQLite transaction: a failed download, parse, duplicate primary key, or failed insertion leaves the previous published generation unchanged. Failed refresh is labelled and dated rather than represented as empty coverage.
- The map layer has an independent ID `mobile-sites`, attribution, safe detail text, and complete replacement/disposal via the shared Cesium situational renderer.
- Published STAC *metadata* timestamps and download timestamps are different; STAC `updated` MUST NOT be interpreted as an observation time or an assurance of individual station freshness.