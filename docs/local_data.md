# Local data and repositories

Personal records use the existing Drift/SQLite database on the device or in the
browser. Repositories perform no HTTP requests, upload or account registration.
They accept an injected `FpvDatabase`; the caller owns its lifetime and closes it.
`FpvDatabase.open()` opens the persistent app database. Tests use independent
in-memory databases or a temporary SQLite file, never the personal app database.

## Typed records and contracts

The generated immutable Drift records are also the persisted domain records:
`Spot`, `SpotPhoto`, `Drone`, `Battery`, `RadioEquipmentData`, `FlightPlan`, `FlightWaypoint`
and `AppSetting`. A second copy of each database record is not maintained.
`FlightRoute`, `RouteWaypoint` and `UserPreferences` add typed views where the
table representation alone cannot express the application contract.

| Contract | Location | Operations |
|---|---|---|
| `SpotRepository` | `lib/features/spots/data/` | CRUD, watch, favorite toggle, photo drafts/previews |
| `DroneRepository` | `lib/core/database/repositories/` | CRUD/watch, complete profile snapshots and transactional provenance |
| `BatteryRepository` | `lib/core/database/repositories/` | Pack/type CRUD/watch, atomic condition/specification snapshots and drone/plan assignments |
| `RadioEquipmentRepository` | `lib/core/database/repositories/` | CRUD, watch |
| `FlightPlanRepository` | `lib/core/database/repositories/` | Metadata CRUD/watch, route snapshots, waypoint replacement |
| `UserPreferencesRepository` | `lib/core/database/repositories/` | Read/watch, save, reset |

Each is an interface with a default Drift factory, for example
`DroneRepository(database)`. Consumers can instead inject an implementation of
the interface. Existing `SpotRepository(database)` callers remain valid.

Lists use descending IDs (newest created first). Missing records return `null`,
updates return `false` and deletes return `0`. IDs must be positive. Names,
drone types, battery chemistry and radio categories are trimmed and contain
1–120 characters. Notes retain the supplied text. WGS84 coordinates must be
finite and within latitude ±90° / longitude ±180°. Physical weights, speeds,
frequencies, cell counts and capacities must be positive; battery cycle counts
and radio transmit power may be zero. Zero radio power supports receiver-only
equipment. These fields describe user equipment, not regulatory permission.

An `update…` operation replaces all editable fields; omitted nullable fields
are cleared and omitted fields with defaults take those defaults. It is not a
partial patch. Creation timestamps are preserved. `setFavorite` changes only
the favorite flag, and a full spot edit preserves that flag.

## Routes, heights and transactions

Creating a flight plan stores its metadata and waypoints in one transaction.
`replaceWaypoints` validates a copy of the entire input before replacing the
old points, then deletes and inserts in one transaction. A database failure
rolls back the entire operation. Replacement assigns new waypoint IDs and
contiguous zero-based sequence numbers; callers should use the returned route
snapshot rather than retain waypoint IDs across replacement.

`getRoute` and `watchRoute` read the parent and ordered children through one
left join. Empty plans remain visible, missing plans return `null`, and observers
receive committed snapshots when either metadata or waypoints change. Points
are ordered by sequence number, then ID. The snapshot list is unmodifiable.

`RouteWaypointInput.height` has three explicit representations:

- `null`: position only. No zero elevation or reference is inferred.
- `AbsoluteWaypointHeight`: `ReferencedElevation` with an explicit datum.
  Negative finite absolute elevations are allowed. Legacy `unverified` heights
  remain unverified; storing one does not make it suitable for calculations.
- `AglWaypointHeight`: a finite, nonnegative `AboveGroundHeight`. This is a
  terrain-relative offset. The stored reference remains `unverified`, because
  AGL is not a geodetic datum; the altitude mode identifies it as AGL.

Unknown height-reference/mode strings, inconsistent height metadata and invalid
stored coordinates raise `FormatException` when reading a route. They do not
silently acquire a default datum. See [coordinates and heights](coordinates_and_heights.md)
for the calculation rules.

Deleting a referenced drone or start spot sets the corresponding plan field to
`null`, preserving the plan and waypoints. Deleting a plan cascades to its points.
Invalid foreign keys fail the write; they are never stored as dangling links.

## Preferences

`UserPreferencesRepository` owns these five `app_settings` keys:

| Key | Stored value | Default when absent |
|---|---|---|
| `map.style` | `satellite`, `topographic` or `relief` | `satellite` |
| `map.uas.visible` | `true` or `false` | `false` |
| `map.uas.fillOpacity` | Finite number in [0, 1] | `0.20` |
| `map.spots.visible` | `true` or `false` | `true` |
| `map.overlayOrder` | JSON array with `uasZones` and `savedSpots`, each once, back to front | `["uasZones","savedSpots"]` |

Reading defaults does not write rows. Saving replaces all five owned values in
one transaction, with the same update timestamp. Malformed owned values raise
`FormatException`; a caller can offer an explicit reset. Reset deletes only
these keys and preserves unrelated settings.

The map controls restore these preferences at startup and save successful user
changes. See [map preferences](map_preferences.md) for failure handling, overlay
ordering and renderer recovery.

## Schema and scope

Schema version is **6**. The indexed `spot_photos` table adds normalized photos
and thumbnails with cascading spot ownership. Spot category/search columns and
the indexed `spot_tags` table support classification and filtering. Migration
tests validate v1/v2/v3/v4/v5 → v6 while preserving existing records. Drone fields
and `drone_parameter_sources` preserve per-value provenance. Repository tests cover CRUD,
validation, watchers, relationship deletion, rollback, height references and
preferences. A file-backed test closes and reopens SQLite and verifies records
from every domain.

Spots have editing/list screens, a photo gallery and opt-in device location;
see [photo and location contracts](spot_photos_and_location.md). Drone profiles
have list/editor/detail screens; see [drone profile contracts](drone_profiles.md).
Battery inventory has pack/type editors, optional manual condition records and
transactional drone/flight-plan links; see [battery inventory](battery_inventory.md).
Radio equipment profiles (#15) and route editing (#25) remain separate feature
work. A saved route is a local planning
record, not a completed route planner or flight-safety assessment.
See [spot search and classification](spot_search.md) for the spot list contract.
