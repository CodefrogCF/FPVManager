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
reports active/pending/reason; `navigation-focus` gates device input. Android sends
coalesced `navigation-input` frames (forward/right/yaw/pitch/vertical in −1…1,
reset/exit/connected booleans). Frames retain physical axes: forward/right are
left-stick up/right; yaw/pitch are right-stick right/down. Angle/Acro map these
to throttle/yaw and roll/pitch; GPS/ground map them to movement/look. The renderer requires neutral controller input
before activation and expires native frames after 250 ms. Flight state/telemetry
remain in the renderer; keyboard/touch and Web gamepads require no bridge stream.

Acro optionally accepts `acroThrustToWeight`, `acroThrustCurve`,
`acroMotorTimeConstant` (s) and `acroTerminalVelocity` (m/s). Its translation uses
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

See [architecture](architecture.md) for provider/terrain recovery,
[Contributing](../CONTRIBUTING.md) for tests, and the [user guide](user_guide.md)
for controls and display limitations.
