# Globe bridge protocol v1

`GlobeBridge` and `web/globe_bridge.js` share a JSON transport for the Web iframe
and Android WebView. Only recognized commands in `web/globe.js` execute; messages
are never evaluated as JavaScript.

## Messages and lifecycle

Commands carry `version: 1`, `sessionId`, unique decimal `requestId`, `type` and
typed fields. Events carry `source: fpvmanager-globe`, `version: 1`, `sessionId`,
strictly increasing `eventSequence` and `type`. `command-result` correlates
`requestId`/`commandType` with `ok` and a `result` object or `error` string.
Acknowledgement confirms command processing, not completion of later tile loads.

`renderer-loading` cancels pending work and clears confirmed state. `globe-ready`
starts recovery. Old-session/out-of-order events are rejected; duplicate ready
messages do not restart recovery. Suspension cancels work; resume asks the page
to announce its session. Web checks the bound iframe and origin. Native navigation
is restricted to the app-owned origin, and disposed views ignore late events.

Reload restores requested map preferences, spots, visible routes and an open
route draft. Camera, selection and ground/flight mode reset. Replacing a view's controller
reloads the page to create a fresh session. `reloadRenderer()` reloads the page;
`retry-terrain` replaces terrain inside the current viewer.

## Bounds and cancellation

Defaults in `GlobeBridgeOptions`:

| Limit | Default |
|---|---|
| Ordinary command / terrain query / dataset import | 15 s / 30 s / 2 min |
| Individual transport send | 10 s |
| Frame / chunk | 128 Ki / 32 Ki UTF-16 code units |
| Encoded command / total reserved JS buffers | 64 Mi UTF-16 code units |
| Concurrent JS transfers / pending commands | 2 / 32 |
| Incomplete transfer idle timeout | 30 s |

Large commands use `transfer-start` (type/length), consecutive zero-based
`transfer-chunk` frames, then `transfer-complete`. Validate lengths, ordering,
IDs and aggregate reservations before execution. Invalid transfers release their
buffers. Timeout, disposal and `cancel-command` invalidate work. Async paths
check cancellation before committing; third-party promises may finish later,
but their obsolete results are ignored.

## Terrain, zones and routes

`terrain-status` reports `loading`, `ready`, `unavailable` or `offline` with a
compatible reason. Height results must match requested coordinates and contain
finite height, sampling method and `heightReference: "wgs84Ellipsoid"`. Terrain
generations reject stale results independently of renderer sessions.

UAS imports accept plain-text `sourceAttribution`. Dataset provenance/assessment
is committed only after import acknowledgement. `uas-zone-selected` carries
plain-text `attributes`, `omittedAttributeCount` and `truncatedAttributes`.
Limits are 128 attributes, 120-character keys, 8,000-character values and an
80 Ki-character escaped payload budget including limit metadata. Key restriction
and height fields take priority. Null/empty/zero/false remain text; oversized
keys are omitted and shortening/omission is reported. Source text is not HTML.

Ground inspection uses `enter-ground-view`, `exit-ground-view` and
`ground-view-state`. Entry uses bounded terrain sampling. Draft editing uses
`set-route-editor`, `frame-route` and `route-map-action`; editor identity,
revision and stable draft waypoint keys reject stale edits.

Free flight uses `enter-simulation` (optional paired latitude/longitude, `agl`,
`maxSpeed`, `climbSpeed`, `acceleration`, `deceleration`, `flightMode` = gps/angle/acro), `reset-simulation` and
`exit-simulation`. Missing coordinates select the camera target. `simulation-state`
reports active/pending/reason and `cameraTiltDegrees` (0–80° upward, also accepted
at entry; body-relative FPV view only).
`graphicsProfile` accepts `quality`, `balanced` (default) or `performance` at
entry and is reported in `simulation-state` after in-flight changes.
`navigation-focus` gates device input. Android sends
coalesced `navigation-input` frames (forward/right/yaw/pitch/vertical in −1…1,
reset/exit/connected booleans). Frames retain physical axes: forward/right are
left-stick up/right; yaw/pitch are right-stick right/down. Angle/Acro map these
to throttle/yaw and roll/pitch; GPS/ground map them to movement/look. The renderer requires neutral controller input
before activation and expires native frames after 250 ms. Flight state/telemetry
remain in the renderer; keyboard/touch and Web gamepads require no bridge stream.

Acro optionally accepts `acroThrustToWeight`, `acroThrustCurve`,
`acroMotorTimeConstant` (s) and `acroTerminalVelocity` (m/s, default 22.5).
`acroRollRate`, `acroPitchRate` and `acroYawRate` are full-stick body rates in °/s
(10–1,500, default 180); `acroRateExpo` (0–1, default 0) uses the symmetric curve
`maximum * stick * ((1 - expo) + expo * stick²)`. These settings affect Acro only
and persist across renderer-side resets. Its translation uses
body-directed thrust, gravity, motor lag and quadratic drag; assisted speed/climb
and response fields do not clamp Acro. The thrust curve interpolates linear and
quadratic motor command, following the model described in the
[PX4 thrust-curve guide](https://docs.px4.io/main/en/config_mc/pid_tuning_guide_multicopter#thrust-curve).

`set-visible-routes` carries a revision and up to 20 routes with ID/name and up
to 1,000 waypoint IDs/positions each. `frame-visible-routes` takes a positive
route ID. Visibility preserves the walking camera; framing exits ground view.
Waypoints optionally carry `height: {meters, reference}`. AGL and WGS84 ellipsoid
heights drive geometry; missing/incompatible references use marked 30 m previews.
The draft's `critical` flag highlights the outgoing segment. `query-route-terrain`
accepts up to 256 positions and returns finite ellipsoid `heights` in input order
and a `samplingMethod` (`most-detailed` or `level-12`). Failed or changed terrain
invalidates the batch; partial profiles are not used as complete clearance data.
Cancellation/revision checks prevent obsolete geometry from reappearing;
`route-preview-error` reports asynchronous rebuild failures for explicit retry.

`set-situational-overlay` controls independent road/traffic/aircraft snapshots
and heliport/wildfire imagery. `situational-status` reports imagery loading or
failure; `situational-selected` carries bounded plain-text details. See
[Mobility & OSINT](mobility_osint.md) for sources and limits.

`set-road-navigation` carries `active`, `follow`, `cameraDistanceMeters`
(60–1,800 m, default 550 m) and an optional WGS84
`position: {latitude, longitude, heading}`. A null position hides an unreliable
fix; ending restores camera inputs. Requested navigation replays after reload.
The renderer compass emits `road-navigation-follow` when switching between
north alignment and following; the controller retains that state for reloads.
`set-rendering-paused` pauses the hidden home map during Android road navigation.

`set-scene-environment` carries boolean `buildings`, `vegetation`, `lighting`
and an optional layer name in `retry`. `scene-layer-status` reports loading,
ready, partial or failed without failing globe initialization. `set-scene-time`
uses `scope: route|flight`, `enabled` and nullable UTC `timeUtc`; flight overrides
route, then map lighting. Route-editor and simulation-entry commands also carry
this object as `sceneTime`. A fixed time freezes the celestial clock.

`set-wind-field` carries independent `visible`/`affectFlight` flags and a nullable
nine-node snapshot (UTC validity/retrieval/expiry, four supported AGL levels,
SI speed and meteorological direction). `query-wind-center` returns the active
drone position or camera target. `wind-layer-status`, `wind-flags-changed` and
`wind-settings-request` report renderer state and HUD actions. Snapshots replay
after reload without a download; animation uses elapsed time, expiry wall time.

See [architecture](architecture.md) for provider/terrain recovery,
[Contributing](../CONTRIBUTING.md) for tests, and the [user guide](user_guide.md)
for controls and display limitations.
