# Globe bridge protocol v1

`GlobeBridge` in Dart and `web/globe_bridge.js` implement the same transport for
the Web iframe and native WebView. Only the commands in `web/globe.js` are
executable. No message is evaluated as JavaScript.

## Envelopes

Commands contain `version: 1`, `sessionId`, a unique decimal `requestId`, `type`
and typed command fields. Renderer events contain `source: fpvmanager-globe`,
`version: 1`, `sessionId`, a strictly increasing `eventSequence` and `type`.

`renderer-loading` invalidates outstanding work and clears confirmed renderer
state. `globe-ready` starts recovery once the new viewer exists. A session changes
on page reload; replies/events from an old session are rejected. Duplicate ready
messages in a running session do not start another recovery. App suspension
cancels pending work; resuming asks the page to announce its current session.

Every command finishes with `command-result`, including the original `requestId`
and `commandType`, `ok` and either a `result` object or an `error` string. Dart
waits for this result rather than considering a successful send an acknowledgement.
Terrain coordinates, height and sampling method are returned in `result` and
checked against the requested coordinates. Terrain results must also carry
`heightReference: "wgs84Ellipsoid"`; unknown or missing references are rejected.
An acknowledgement confirms processing,
not successful retrieval of every future imagery/terrain tile or camera animation
completion.

## Timeouts and bounds

Defaults are configurable through `GlobeBridgeOptions`:

| Operation | Default |
|---|---|
| Ordinary command | 15 seconds |
| Terrain sampling | 30 seconds |
| Dataset import, including transfer | 2 minutes |
| Individual transport send | 10 seconds |
| Frame | 128 Ki UTF-16 code units |
| Chunk | 32 Ki UTF-16 code units |
| Encoded command / total reserved JS transfer buffers | 64 Mi UTF-16 code units |
| Concurrent JS transfers | 2 |
| Pending commands | 32 |
| Incomplete JS transfer idle timeout | 30 seconds |

Large commands use `transfer-start` with command type and declared length,
consecutive `transfer-chunk` frames with zero-based indices, then
`transfer-complete`. The renderer checks lengths, ordering, IDs and total buffer
reservations before execution. Broken transfers are rejected and released.
Command timeout, connection disposal and `cancel-command` cancel pending work.
Async rendering paths check their abort signal before applying results; an older
UAS import cannot replace a newer one. Cancellation cannot interrupt work already
running inside a third-party promise, but its late result is discarded.

## Recovery

The controller retains the requested base style, UAS opacity/visibility and saved
spot markers. It reapplies nondefault settings and reimports requested UAS data
into a new renderer. Provider caching remains separate (#51). Point/spot/UAS
selection is cleared on reload; the camera returns to its initial Swiss view.

The public `reloadRenderer()` command requests a page reload after acknowledgement.
`retry-terrain` instead replaces only the terrain provider in the current viewer.
`terrain-status` events report `state` (`loading`, `ready`, `unavailable`, `offline`)
and a reason checked against that state. The current status follows each
`globe-ready` announcement; duplicate hello messages do not start a retry.
See [terrain failures and recovery](terrain_recovery.md) for the deadlines,
late-response rules and conservative flat fallback. Height-query command
results from a previous terrain generation are rejected independently of the
renderer session.
UAS dataset imports can include a plain-text `sourceAttribution`; the renderer
escapes it for its source credit. The controller keeps imported dataset metadata
separate from a newer downloaded snapshot until the import is acknowledged.
Web accepts events only from the bound iframe and matching origin. Native pages
are loaded from an app-owned loopback origin; navigation to other origins is
blocked. Disposed native views ignore subsequent JavaScript events.
Replacing a view's controller reloads its page, giving the new controller fresh
request and marker IDs in a new renderer session.

## Inspection and route commands

Ground inspection adds `enter-ground-view` / `exit-ground-view` commands and
`ground-view-state` events. Entry uses the bounded terrain-sampling deadline.
Route drafts use `set-route-editor` and `frame-route`; `route-map-action` events
carry editor identity, revision, action and the relevant draft waypoint key or
position. The Dart controller rejects stale/invalid edits and restores the
desired draft overlay after a renderer reload. Ground mode is deliberately not
restored across renderer sessions. See [ground view and local routes](ground_view_and_routes.md).

## Tests

`flutter test` covers correlated requests, timeouts, lifecycle cancellation,
recovery, invalid envelopes and Dart transfer framing. Run the actual JavaScript
receiver tests separately:

```sh
node --test test/js/globe_bridge.test.cjs
```

The real offline renderer/lifecycle test uses the Flutter integration test runner:

```sh
flutter test integration_test/globe_runtime_test.dart -d <android-device-id>
```

It uses an ellipsoid/grid and local GeoJSON fixtures, without opening the personal
database. It checks real JS acknowledgements, UAS import, reload restoration and
pause/resume, followed by replacement of the controller on the existing view.
Live swisstopo/FOCA availability and device performance remain
separate validation tasks.
