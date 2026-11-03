# Shared Mobility

## Source and mode

- **Primary integration:** Swiss Federal Office of Energy (SFOE/BFE),
  `https://api.sharedmobility.ch/v1/sharedmobility/identify` (REST v1).
- **Documentation:** https://github.com/SFOE/sharedmobility/blob/main/Access%20the%20data.md
- **REST parameters:** `Geometry=<longitude>,<latitude>`, `Tolerance` in metres,
  `offset=0`, `geometryFormat=esrijson`.
- REST spatial search was selected to avoid downloading all providers' nationwide
  GBFS feeds. The REST reference does not prescribe an API key or contact email.
  Therefore **no credential/contact is stored, exported or attached to REST requests**.
- GBFS 2.3 is a *separate* supported upstream interface. When using it, the
  official SFOE instructions require a valid email in the `Authorization` header.
  FPVManager does **not** invoke or persist contact information for GBFS in this issue.
  Parser tests normalize composed GBFS 2.0 and 2.3 feed fixtures for compatibility;
  the UI does not claim to be a live GBFS client.
- License/terms: open use with source attribution including author/title/link;
  both commercial and non-commercial use are indicated as permitted by the
  official access documentation. The app displays that attribution.

## Search and state semantics

- Manual search only; consent before sending coordinates, no background polling.
- Search radius constrained to 200, 500, 1000 or 2000 m in the UI, with
  server-side radius filtering and a second local Haversine bound.
- Cache: separate OSINT SQLite snapshot store, integrity checksum and maximum
  650 KiB record, up to 12 areas and one day retention. Not included in personal
  backup/profile exports. No migration is required.
- Size and load limits: maximum 1.1 MiB response, 200 normalized offers,
  120 map markers and 60 list entries. First page (`offset=0`) only. Even an
  empty result does not establish full provider coverage. Repeated IDs dedupe.
- Request throttling: at most 15 requests per hour and one per 10 seconds in
  the app process; identical concurrent requests share a Future; fresh cache
  prevents repeated GETs. These are local conservative limits, **not** claimed
  as provider-published rate limits. HTTP 429 is surfaced.
- Both station-based and free-floating entries retain their provider ID, source
  ID, types, coordinates and optional operator/app link. `availableCount` is
  not a reservation. Missing tags remain unknown. Provider links only accept
  HTTPS. No automatic reservation/purchase action exists.
- The REST sample exposes `available`, `vehicle_status_reserved`,
  `vehicle_status_disabled`, `station_status_installed`,
  `station_status_renting`, and `station_status_num_vehicle_available`.
  Reserved and disabled override an advertised `available=true`; empty or
  non-renting stations are reported unavailable.
- **Time semantics:** the documented REST response inspected did not contain
  a guaranteed feed publication timestamp or TTL. We therefore show the
  *reported* state but label the **current** availability as **unknown** instead
  of implying that the server retrieval time makes it live. If valid GBFS
  `last_updated` and `ttl` are present in a composed feed, both govern freshness.
  Missing, future, expired and failed-refresh statuses become unknown.
- A successful refresh replaces the previous list, so vehicles that disappeared
  do not linger. A failed request may display a dated saved location snapshot,
  but marks the refresh failure and all current statuses unknown.
- Dynamic availability is never guaranteed; nearby availability and operator
  coverage depend on what providers publish.

## Relevant source links

- https://github.com/SFOE/sharedmobility/blob/main/Access%20the%20data.md
- https://github.com/SFOE/sharedmobility/blob/main/Sharedmobility.ch-API.md
- https://opentransportdata.swiss/en/cookbook/road-traffic-cookbook/shared-mobility/
- https://www.sharedmobility.ch/info
