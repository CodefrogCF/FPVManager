# Nearby OpenStreetMap POIs

## UI / behavior

`Mobility & OSINT → Nearby POIs` is entirely opt-in. The search center is a selected map coordinate, the actual position of a saved spot (not its parking coordinate), a manually entered WGS84 point, or the device location upon an explicit button press. Choose one or more of the six categories and 250, 500, 1,000 or 2,000 m. The request is made only when **Find nearby places** or **Refresh from Overpass** is pressed **with consent**. **Show saved search offline** reads only the local cache.

Search requests use the public `https://overpass-api.de/api/interpreter` with Overpass QL `nwr(around:radius,lat,lon)["key"="value"]`, `out center 301` and `[timeout:20][maxsize:33554432]`. No credentials, notes, spot names or user account IDs are sent; selected coordinates, radius, categories and ordinary provider request metadata can be logged by the operator. No OSM tiles are downloaded by this feature.

## Resource protection and coverage limits

- Radius 100–2,000 m (UI offers 250/500/1,000/2,000); 1–6 enum-controlled categories only. No arbitrary Overpass QL, no countrywide or bulk queries.
- In-flight requests are coalesced by center/radius/categories. At most 12 new requests/hour and at least 15 seconds between them **per running client** (not a global provider guarantee). Respect HTTP 429/503 and do not retry automatically. Public endpoints may be slower, stricter or unavailable. For production-scale usage use a dedicated provider or own service.
- Response limit 450 KB, up to 301 source elements, up to 300 deduplicated positions, 60 visible detail cards; map renderer yields after each 100 entities. Source tags: at most 64 bounded key/value pairs per object. Duplicate identity is `node|way|relation / ID`, never coordinate.
- OSM coverage is voluntary and incomplete; missing POIs, opening hours, wheelchair information, access or availability are **unknown**, not negative. `out center` for ways and relations is a representative point, not an exact accessible entrance. Do not infer potable water safety from an OSM drinking-water tag.
- Cache persists in the existing *OSINT cache database*, with SHA-256 integrity verification, up to 12 bounded snapshots, 14-day retention metadata and 24-hour freshness indicator. A stale snapshot is always visibly dated and flagged. Service/network failure may fall back to the cached snapshot with a warning. There is no automatic background polling.
- The Flutter Web browser's CORS policy and the public Overpass instance's headers must permit direct requests. Browser access **has not been verified live** here. If blocked, use a supported native client or configure a separately managed, trusted intermediary; none is shipped, required or silently contacted by this issue.

## Personal spots and exports

The **Save as personal spot** button creates a standard local spot with editable name, position, notes and category. Immutable import provenance (`node/way/relation`, original bounded tags, retrieval time and OSM URL) is stored in `app_settings` keys `spot.osm.source.<spotId>.v1` and indexed by `spot.osm.index.<type>.<id>.v1`. These keys are included in *personal backups* via an exact whitelist; source data is not a secret. The spot-detail view displays its OSM reference separately even when the user edits or replaces their notes. Re-saving the same OSM element returns the existing spot and does **not** overwrite personal edits. Deleting a spot deletes both source and index settings. Subsequent Overpass refreshes only update OSINT cache data; they never update existing spots.